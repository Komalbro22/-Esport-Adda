import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, Authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            console.error('Missing Authorization header')
            return new Response(JSON.stringify({ error: 'Unauthorized', message: 'Missing token' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY') ?? ''

        // 1. Create a client using the user's token for verification (pattern and settings from distribute_prizes)
        const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
            global: {
                headers: { Authorization: authHeader }
            }
        })

        // Extract token securely
        const token = authHeader.replace(/^[Bb]earer /, '').trim();

        // 2. Verify the user:
        const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token)

        if (authError || !user) {
            // Check if it's the Service Role Key being used as a token (internal call)
            if (token === supabaseServiceKey) {
                console.log('Internal system call with Service Key');
            } else {
                console.error('JWT Verification Failed:', authError?.message || 'No user', authError);
                return new Response(JSON.stringify({
                    error: 'Unauthorized',
                    message: authError?.message || 'Invalid JWT - Please log in again',
                }), {
                    status: 401,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                })
            }
        }

        // Initialize Admin Client for DB operations
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        if (user) console.log('User authenticated:', user.id)

        // Check if user is admin
        let isAdmin = false;
        let adminCheck: any = null;

        if (token === supabaseServiceKey) {
            isAdmin = true;
        } else if (user) {
            const { data, error: roleError } = await supabaseAdmin
                .from('users')
                .select('role, name')
                .eq('id', user.id)
                .single()

            adminCheck = data;
            if (!roleError && data && ['admin', 'super_admin'].includes(data.role)) {
                isAdmin = true;
            } else {
                console.error('Admin Check Failed for user:', user.id, 'Role:', data?.role);
            }
        }

        if (!isAdmin) {
            console.error('Forbidden: User is not an admin.');
            return new Response(JSON.stringify({
                error: 'Forbidden',
                message: 'Admin access required'
            }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const { request_id, approved = true } = await req.json()

        // Fetch request details
        const { data: request, error: reqError } = await supabaseAdmin
            .from('deposit_requests')
            .select('*')
            .eq('id', request_id)
            .single()

        if (reqError || !request) {
            return new Response(JSON.stringify({ error: 'Request not found' }), {
                status: 404,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        if (request.status !== 'pending') {
            return new Response(JSON.stringify({ error: 'Request already processed' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const newStatus = approved ? 'approved' : 'rejected'

        if (approved) {
            // Get current wallet balance securely
            const { data: wallet } = await supabaseAdmin
                .from('user_wallets')
                .select('deposit_wallet')
                .eq('user_id', request.user_id)
                .single()

            const currentDeposit = wallet?.deposit_wallet || 0

            // Update user wallet
            await supabaseAdmin.from('user_wallets')
                .update({ deposit_wallet: currentDeposit + request.amount })
                .eq('user_id', request.user_id)
        }

        // Update request status
        await supabaseAdmin.from('deposit_requests').update({ status: newStatus }).eq('id', request_id)

        // Update corresponding wallet transaction
        const txStatus = approved ? 'completed' : 'rejected'
        await supabaseAdmin.from('wallet_transactions')
            .update({ status: txStatus })
            .eq('reference_id', request_id)

        // Log admin activity
        await supabaseAdmin.from('admin_activity_logs').insert({
            admin_id: user?.id || 'system',
            admin_name: (user ? (adminCheck?.name || user.email) : 'System'),
            action: approved ? 'approve_deposit' : 'reject_deposit',
            target_type: 'deposit_request',
            target_id: request_id,
            details: { amount: request.amount, user_id: request.user_id }
        })

        // Notify user via notification function
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

        return new Response(JSON.stringify({ success: true, status: newStatus, deploy_v: 'v2.1' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    } catch (e) {
        console.error('Unexpected Error:', e.message)
        return new Response(JSON.stringify({ error: e.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
})
