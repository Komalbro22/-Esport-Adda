import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY') ?? ''

        if (!supabaseServiceKey) {
            console.error('CRITICAL: SERVICE_ROLE_KEY is missing in environment variables')
        }

        // Create admin client
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // Verify user JWT explicitly using the admin client for better reliability
        const token = authHeader.replace(/^[Bb]earer /, '').trim();

        if (!token) {
            return new Response(JSON.stringify({ error: 'Unauthorized', message: 'Token is empty' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Use supabaseAdmin (Service Role) to verify the token
        const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token)

        if (authError || !user) {
            // Check if it's the Service Role Key being used as a token (for system/internal calls)
            if (token === supabaseServiceKey) {
                console.log('Internal system call with Service Key');
            } else {
                console.error('Auth Error:', authError?.message || 'User not found');
                return new Response(JSON.stringify({
                    error: 'Unauthorized',
                    message: authError?.message || 'User not authenticated'
                }), {
                    status: 401,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                })
            }
        }

        const { tournament_id } = await req.json()
        if (!tournament_id) {
            return new Response(JSON.stringify({ error: 'Missing tournament_id' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        // Check admin role
        const { data: adminCheck } = await supabaseAdmin.from('users').select('role, name').eq('id', user.id).single()
        if (!['admin', 'super_admin'].includes(adminCheck?.role)) {
            return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        // 1. Fetch tournament
        const { data: tournament, error: tourneyError } = await supabaseAdmin
            .from('tournaments')
            .select('id, status, title')
            .eq('id', tournament_id)
            .single()

        if (tourneyError || !tournament) throw new Error('Tournament not found')
        if (tournament.status === 'completed' || tournament.status === 'cancelled') {
            throw new Error(`Cannot cancel a ${tournament.status} tournament`)
        }

        // 2. Set status to cancelled
        const { error: updateError } = await supabaseAdmin.from('tournaments')
            .update({ status: 'cancelled' })
            .eq('id', tournament_id)

        if (updateError) {
            throw new Error(`DB Error setting status to cancelled: ${updateError.message}`)
        }

        // 3. Find all participants and their fee splits
        const { data: participants, error: partError } = await supabaseAdmin
            .from('joined_teams')
            .select('id, user_id, fee_deposit, fee_winning, is_refunded')
            .eq('tournament_id', tournament_id)

        if (partError) throw new Error('Could not fetch participants')

        if (participants && participants.length > 0) {
            const newTransactions = []

            for (const p of participants) {
                if (p.is_refunded) {
                    console.log(`User ${p.user_id} is already refunded. Skipping.`)
                    continue;
                }

                const dRefund = Number(p.fee_deposit || 0)
                const wRefund = Number(p.fee_winning || 0)

                if (dRefund <= 0 && wRefund <= 0) {
                    console.warn(`No refund data found for User ${p.user_id}. Check manually if logic before fee_split storage was used.`)
                    continue;
                }

                // Fetch user wallet
                const { data: wallet } = await supabaseAdmin.from('user_wallets').select('*').eq('user_id', p.user_id).single()
                if (!wallet) continue;

                // Update wallet
                await supabaseAdmin.from('user_wallets').update({
                    deposit_wallet: wallet.deposit_wallet + dRefund,
                    winning_wallet: wallet.winning_wallet + wRefund
                }).eq('user_id', p.user_id)

                // Mark participant as refunded
                await supabaseAdmin.from('joined_teams').update({ is_refunded: true }).eq('id', p.id)

                // Log transactions
                if (dRefund > 0) {
                    newTransactions.push({
                        user_id: p.user_id,
                        amount: dRefund,
                        type: 'tournament_refund',
                        wallet_type: 'deposit',
                        status: 'completed',
                        reference_id: tournament_id,
                        message: `Refund (Deposit) for cancelled tournament: ${tournament.title}`
                    })
                }

                if (wRefund > 0) {
                    newTransactions.push({
                        user_id: p.user_id,
                        amount: wRefund,
                        type: 'tournament_refund',
                        wallet_type: 'winning',
                        status: 'completed',
                        reference_id: tournament_id,
                        message: `Refund (Winning) for cancelled tournament: ${tournament.title}`
                    })
                }
            }

            if (newTransactions.length > 0) {
                await supabaseAdmin.from('wallet_transactions').insert(newTransactions)
            }
        }

        // Log action
        await supabaseAdmin.from('admin_activity_logs').insert({
            admin_id: user?.id || 'system',
            admin_name: (user ? (adminCheck?.name || user.email) : 'System'),
            action: 'cancel_tournament',
            target_type: 'tournament',
            target_id: tournament_id,
            details: { title: tournament.title }
        })

        return new Response(JSON.stringify({ success: true }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    } catch (error: any) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
})
