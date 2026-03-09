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
        const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY') ?? ''

        // Create client with user's JWT
        const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: authHeader } }
        })

        // Create admin client
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // Authenticate user
        const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'User not authenticated' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
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

        // 3. Find all entry deductions specific to this tournament
        const { data: txs, error: txError } = await supabaseAdmin
            .from('wallet_transactions')
            .select('*')
            .eq('reference_id', tournament_id)
            .eq('type', 'tournament_entry')
            .eq('status', 'completed')

        if (txError) throw new Error('Could not fetch entry transactions')

        if (txs && txs.length > 0) {
            // Group by user
            const refundsByUser: Record<string, { deposit: number; winning: number }> = {}

            for (const tx of txs) {
                if (!refundsByUser[tx.user_id]) refundsByUser[tx.user_id] = { deposit: 0, winning: 0 }

                if (tx.wallet_type === 'deposit') refundsByUser[tx.user_id].deposit += tx.amount
                if (tx.wallet_type === 'winning') refundsByUser[tx.user_id].winning += tx.amount
            }

            // Process refunds
            const newTransactions = []

            for (const [userId, amounts] of Object.entries(refundsByUser)) {
                // Fetch user wallet
                const { data: wallet } = await supabaseAdmin.from('user_wallets').select('*').eq('user_id', userId).single()
                if (!wallet) continue;

                const newDeposit = wallet.deposit_wallet + amounts.deposit
                const newWinning = wallet.winning_wallet + amounts.winning

                // Update wallet
                await supabaseAdmin.from('user_wallets').update({
                    deposit_wallet: newDeposit,
                    winning_wallet: newWinning
                }).eq('id', wallet.id)

                // Prepare refund logs
                if (amounts.deposit > 0) {
                    newTransactions.push({
                        user_id: userId,
                        amount: amounts.deposit,
                        type: 'tournament_refund',
                        wallet_type: 'deposit',
                        status: 'completed',
                        reference_id: tournament_id,
                        message: `Refund for cancelled tournament: ${tournament.title}`
                    })
                }

                if (amounts.winning > 0) {
                    newTransactions.push({
                        user_id: userId,
                        amount: amounts.winning,
                        type: 'tournament_refund',
                        wallet_type: 'winning',
                        status: 'completed',
                        reference_id: tournament_id,
                        message: `Refund for cancelled tournament: ${tournament.title}`
                    })
                }
            }

            if (newTransactions.length > 0) {
                await supabaseAdmin.from('wallet_transactions').insert(newTransactions)
            }
        }

        // Log action
        await supabaseAdmin.from('admin_activity_logs').insert({
            admin_id: user.id,
            admin_name: adminCheck.name || user.email,
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
