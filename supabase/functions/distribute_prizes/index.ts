import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Calculate and distribute winnings to players
serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { tournament_id } = await req.json()

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
        if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), {
            status: 401,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

        const { data: adminCheck } = await supabaseAdmin.from('users').select('role').eq('id', user.id).single()
        if (adminCheck?.role !== 'admin') return new Response(JSON.stringify({ error: 'Forbidden' }), {
            status: 403,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

        const { data: tournament } = await supabaseAdmin
            .from('tournaments')
            .select('per_kill_reward, rank_prizes, status')
            .eq('id', tournament_id)
            .single()

        if (!tournament) return new Response(JSON.stringify({ error: 'Tournament not found' }), {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
        if (tournament.status === 'completed') return new Response(JSON.stringify({ error: 'Tournament already completed' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

        const rankPrizes = tournament.rank_prizes || {}

        // Fetch results from DB instead of client payload
        const { data: results } = await supabaseAdmin
            .from('joined_teams')
            .select('id, user_id, rank, kills, is_prize_distributed')
            .eq('tournament_id', tournament_id)

        if (!results || results.length === 0) {
            return new Response(JSON.stringify({ error: 'No participants found' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        for (const res of results) {
            const { id: team_id, user_id, rank, kills, is_prize_distributed } = res

            if (is_prize_distributed) continue;

            const rankPrize = rankPrizes[rank] || 0
            const killPrize = kills * tournament.per_kill_reward
            const totalPrize = rankPrize + killPrize

            // 1. Update stats and add winnings
            if (totalPrize > 0) {

                // Get current wallet
                const { data: wallet } = await supabaseAdmin
                    .from('user_wallets')
                    .select('winning_wallet')
                    .eq('user_id', user_id)
                    .single()

                const currentWinning = wallet?.winning_wallet || 0

                // Update wallet directly to avoid missing RPC errors
                await supabaseAdmin.from('user_wallets')
                    .update({ winning_wallet: currentWinning + totalPrize })
                    .eq('user_id', user_id)

                await supabaseAdmin.from('wallet_transactions').insert({
                    user_id: user_id,
                    amount: totalPrize,
                    type: 'tournament_win',
                    wallet_type: 'winning',
                    status: 'completed',
                    reference_id: tournament_id
                })
                await supabaseAdmin.from('notifications').insert({
                    user_id: user_id,
                    title: 'Tournament Winnings Credited',
                    body: `You won ₹${totalPrize} from Rank: ${rank}, Kills: ${kills}.`
                })
            }

            // Update joined_teams
            await supabaseAdmin.from('joined_teams').update({
                total_prize: totalPrize,
                is_prize_distributed: true
            }).eq('id', team_id)
        }

        // Mark tournament as completed
        await supabaseAdmin.from('tournaments')
            .update({ status: 'completed' })
            .eq('id', tournament_id)

        return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    } catch (e) {
        return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
