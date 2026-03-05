import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { request_id, approved = true } = await req.json()

        // Kong Gateway JWT Duplicate Header bypass
        const authHeader = req.headers.get('Authorization')
        const token = authHeader ? authHeader.replace('Bearer ', '') : ''

        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? ''
        )

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SERVICE_ROLE_KEY') ?? ''
        )

        const { data: { user } } = await supabaseClient.auth.getUser(token)
        if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

        // Check admin role
        const { data: adminCheck } = await supabaseAdmin.from('users').select('role').eq('id', user.id).single()
        if (adminCheck?.role !== 'admin') return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

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

        // Notify user
        await supabaseAdmin.from('notifications').insert({
            user_id: request.user_id,
            title: `Deposit ${approved ? 'Approved' : 'Rejected'}`,
            body: `Your deposit request of ${request.amount} has been ${newStatus}.`
        })

        return new Response(JSON.stringify({ success: true, status: newStatus }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    } catch (e) {
        return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
