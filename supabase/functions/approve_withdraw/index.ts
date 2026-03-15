import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, Authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            console.error('Missing Authorization header')
            return new Response(JSON.stringify({ error: 'Unauthorized: Missing token' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY') ?? ''

        if (!supabaseServiceKey) {
            console.error('CRITICAL: SERVICE_ROLE_KEY is missing in environment variables')
        }

        // 1. Create a client using the user's token for verification
        const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
            global: {
                headers: { Authorization: authHeader }
            }
        })

        // Verify user JWT explicitly
        const token = authHeader.replace(/^[Bb]earer /, '').trim();
        const { data: { user }, error: verifyError } = await supabaseClient.auth.getUser(token)

        if (verifyError || !user) {
            // Check for service key internal call
            if (token === supabaseServiceKey) {
                console.log('Internal system call with Service Key');
            } else {
                console.error('JWT Verification Failed:', verifyError?.message || 'No user returned', verifyError)
                return new Response(JSON.stringify({
                    error: 'Unauthorized',
                    message: verifyError?.message || 'Invalid or expired token'
                }), {
                    status: 401,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                })
            }
        }

        // 2. Create admin client with service role for DB operations
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // Check admin role
        const { data: adminCheck, error: roleError } = await supabaseAdmin
            .from('users')
            .select('role, name')
            .eq('id', user.id)
            .single()

        if (roleError || !adminCheck || !['admin', 'super_admin'].includes(adminCheck.role)) {
            console.error('Role Check Error:', roleError?.message || 'Not an admin')
            return new Response(JSON.stringify({ error: 'Forbidden', message: 'Admin access required' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        const { request_id, approved } = await req.json()

        const { data: request, error: reqError } = await supabaseAdmin
            .from('withdraw_requests')
            .select('*')
            .eq('id', request_id)
            .single()

        if (reqError || !request) return new Response(JSON.stringify({ error: 'Request not found' }), { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        if (request.status !== 'pending') return new Response(JSON.stringify({ error: 'Request already processed' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

        const newStatus = approved ? 'approved' : 'rejected'

        if (approved) {
            // Money was already deducted when the user created the request.
            // We just need to mark it as approved.
            console.log(`Withdrawal ${request_id} approved. No further deduction needed.`);
        } else {
            // Rejection: Refund the money back to the winning wallet
            const { data: wallet } = await supabaseAdmin
                .from('user_wallets')
                .select('winning_wallet')
                .eq('user_id', request.user_id)
                .single()

            const currentWinning = wallet?.winning_wallet || 0
            await supabaseAdmin.from('user_wallets')
                .update({ winning_wallet: currentWinning + request.amount })
                .eq('user_id', request.user_id)
            
            console.log(`Withdrawal ${request_id} rejected. Refunded ₹${request.amount} to user ${request.user_id}`);
        }

        // Update request
        await supabaseAdmin.from('withdraw_requests').update({
            status: newStatus,
            processed_at: new Date().toISOString()
        }).eq('id', request_id)

        // Update the pending wallet transaction
        const txStatus = approved ? 'completed' : 'rejected'
        await supabaseAdmin.from('wallet_transactions')
            .update({ status: txStatus })
            .eq('reference_id', request_id)

        // Log action
        await supabaseAdmin.from('admin_activity_logs').insert({
            admin_id: user.id,
            admin_name: adminCheck.name || user.email,
            action: approved ? 'approve_withdraw' : 'reject_withdraw',
            target_type: 'withdraw_request',
            target_id: request_id,
            details: { amount: request.amount, user_id: request.user_id }
        })

        // Notify user via push notification Edge Function
        try {
            await supabaseAdmin.functions.invoke('send_notification', {
                body: {
                    user_id: request.user_id,
                    title: `Withdrawal ${approved ? 'Approved' : 'Rejected'}`,
                    body: `Your withdrawal request of ₹${request.amount} has been ${newStatus}.`,
                    type: 'withdraw_status',
                    related_id: request_id
                }
            })
        } catch (e) {
            console.error('Notification failed:', e.message)
        }

        return new Response(JSON.stringify({ success: true, status: newStatus }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    } catch (e) {
        return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
