import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const authHeader = req.headers.get('Authorization')
        console.log('Authorization Header present:', !!authHeader)

        if (!authHeader) {
            console.error('Missing Authorization header')
            return new Response(JSON.stringify({ error: 'Unauthorized: Missing token' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY') ?? ''

        console.log('Project URL:', supabaseUrl);
        console.log('Anon Key length:', supabaseAnonKey.length);
        console.log('Service Key length:', supabaseServiceKey.length);

        if (!supabaseServiceKey) {
            console.error('CRITICAL: SERVICE_ROLE_KEY is missing in environment variables')
        }

        // Create admin client
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // Verify user JWT explicitly
        const token = authHeader.replace('Bearer ', '').trim();

        // Debug: Check token project ref (no signature verify)
        try {
            const parts = token.split('.');
            if (parts.length === 3) {
                const payload = JSON.parse(atob(parts[1]));
                console.log('Token Payload Project Ref:', payload.ref, 'Role:', payload.role);
            }
        } catch (e) {
            console.error('Failed to parse token payload:', e.message);
        }

        // Use the anon client to verify the token - this is often more reliable than the admin client for user tokens
        const authClient = createClient(supabaseUrl, supabaseAnonKey)
        const { data: { user }, error: verifyError } = await authClient.auth.getUser(token)

        if (verifyError || !user) {
            // Check if it's the Service Role Key being used as a token (internal call)
            if (token === supabaseServiceKey) {
                console.log('Internal system call with Service Key');
                // We'll proceed without a user object, but we need to handle this in role check
            } else {
                console.error('JWT Verification Failed:', verifyError?.message || 'No user returned', verifyError);
                return new Response(JSON.stringify({
                    error: 'Unauthorized',
                    message: verifyError?.message || 'Invalid or expired token',
                    details: verifyError
                }), {
                    status: 401,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                })
            }
        }

        console.log('User authenticated:', user.id)

        // Check admin role
        const { data: adminCheck, error: roleError } = await supabaseAdmin
            .from('users')
            .select('role, name')
            .eq('id', user.id)
            .single()

        if (roleError || !adminCheck || !['admin', 'super_admin'].includes(adminCheck.role)) {
            console.error('Role Check Error:', roleError?.message || 'Not an admin', 'Role:', adminCheck?.role)
            return new Response(JSON.stringify({
                error: 'Forbidden',
                message: 'Admin access required',
                role: adminCheck?.role
            }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const { request_id, approved = true } = await req.json()

        const { data: request, error: reqError } = await supabaseAdmin
            .from('deposit_requests')
            .select('*')
            .eq('id', request_id)
            .single()

        if (reqError || !request) return new Response(JSON.stringify({ error: 'Request not found' }), { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        if (request.status !== 'pending') return new Response(JSON.stringify({ error: 'Request already processed' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

        const newStatus = approved ? 'approved' : 'rejected'

        if (approved) {
            // Get current wallet securely
            const { data: wallet } = await supabaseAdmin
                .from('user_wallets')
                .select('deposit_wallet')
                .eq('user_id', request.user_id)
                .single()

            const currentDeposit = wallet?.deposit_wallet || 0

            // Add to deposit wallet directly
            await supabaseAdmin.from('user_wallets')
                .update({ deposit_wallet: currentDeposit + request.amount })
                .eq('user_id', request.user_id)
        }

        // Update request
        await supabaseAdmin.from('deposit_requests').update({ status: newStatus }).eq('id', request_id)

        // Update the pending wallet transaction
        const txStatus = approved ? 'completed' : 'rejected'
        await supabaseAdmin.from('wallet_transactions')
            .update({ status: txStatus })
            .eq('reference_id', request_id)

        // Log the action
        await supabaseAdmin.from('admin_activity_logs').insert({
            admin_id: user.id,
            admin_name: adminCheck.name || user.email,
            action: approved ? 'approve_deposit' : 'reject_deposit',
            target_type: 'deposit_request',
            target_id: request_id,
            details: { amount: request.amount, user_id: request.user_id }
        })

        // Notify user via push notification Edge Function
        try {
            await supabaseAdmin.functions.invoke('send_notification', {
                body: {
                    user_id: request.user_id,
                    title: `Deposit ${approved ? 'Approved' : 'Rejected'}`,
                    body: `Your deposit request of ₹${request.amount} has been ${newStatus}.`,
                    type: 'deposit_status',
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
