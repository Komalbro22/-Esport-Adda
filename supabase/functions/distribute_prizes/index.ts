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
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY') ?? ''

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

        // Use supabaseAdmin (Service Role) to verify the token explicitly - this is the most robust way in Edge Functions
        const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token)

        if (authError || !user) {
            if (token === supabaseServiceKey) {
                console.log('Internal system call with Service Key');
            } else {
                console.error('JWT Verification Failed:', authError?.message || 'No user returned', authError);
                return new Response(JSON.stringify({
                    error: 'Unauthorized',
                    message: authError?.message || 'Invalid or expired token. Please log out and in again.'
                }), {
                    status: 401,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                })
            }
        }

        if (user) console.log('User authenticated:', user.id)

        // Check role
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
                console.error('Role Check Error:', roleError?.message || 'Not an admin', 'Role:', data?.role)
            }
        }

        if (!isAdmin) {
            return new Response(JSON.stringify({
                error: 'Forbidden',
                message: 'Admin access required'
            }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const { tournament_id } = await req.json()

        const { data: tournament } = await supabaseAdmin
            .from('tournaments')
            .select('per_kill_reward, rank_prizes, status, title')
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

        // Fetch results from DB
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

            const rankKey = rank.toString();
            const rankPrize = (rankPrizes[rankKey] as number) || 0;
            const killPrize = kills * (tournament.per_kill_reward || 0);
            const totalPrize = rankPrize + killPrize;

            // 1. Update stats and add winnings
            if (totalPrize > 0) {
                // Get current wallet
                const { data: wallet } = await supabaseAdmin
                    .from('user_wallets')
                    .select('id, winning_wallet')
                    .eq('user_id', user_id)
                    .single()

                if (wallet) {
                    const currentWinning = wallet.winning_wallet || 0

                    // Update wallet
                    await supabaseAdmin.from('user_wallets')
                        .update({ winning_wallet: currentWinning + totalPrize })
                        .eq('id', wallet.id)

                    await supabaseAdmin.from('wallet_transactions').insert({
                        user_id: user_id,
                        amount: totalPrize,
                        type: 'tournament_win',
                        wallet_type: 'winning',
                        status: 'completed',
                        reference_id: tournament_id,
                        message: `Won ₹${totalPrize} from tournament: ${tournament.title}`
                    })

                    // Notify user
                    try {
                        await supabaseAdmin.functions.invoke('send_notification', {
                            body: {
                                user_id: user_id,
                                title: 'Tournament Winnings Credited',
                                body: `You won ₹${totalPrize} from Rank: ${rank}, Kills: ${kills} in ${tournament.title}.`,
                                type: 'tournament_win',
                                related_id: tournament_id
                            }
                        })
                    } catch (e) {
                        console.error('Notification failed:', e.message)
                    }
                }
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

        // Log action
        await supabaseAdmin.from('admin_activity_logs').insert({
            admin_id: user?.id || 'system',
            admin_name: (user ? (adminCheck?.name || user.email) : 'System'),
            action: 'distribute_prizes',
            target_type: 'tournament',
            target_id: tournament_id,
            details: { title: tournament.title }
        })

        return new Response(JSON.stringify({ success: true, deploy_v: 'v2.1' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    } catch (e) {
        return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
