import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

    try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        const authHeader = req.headers.get('Authorization') || req.headers.get('authorization')
        if (!authHeader) throw new Error('Missing Authorization header')

        const token = authHeader.replace(/^[Bb]earer /, '').trim()
        if (!token) throw new Error('Empty token')

        const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token)
        if (authError || !user) {
            console.error('Auth Error:', authError)
            throw new Error('Unauthorized: Invalid JWT')
        }

        const requestBody = await req.json()
        const { action, challenge_id, game_id, entry_fee, mode, rules, settings, min_fair_score } = requestBody

        // Helper: Check if blocked
        async function isBlocked(uid: string, targetId: string) {
            const { data } = await supabaseAdmin
                .from('blocked_users')
                .select('*')
                .or(`and(user_id.eq.${uid},blocked_user_id.eq.${targetId}),and(user_id.eq.${targetId},blocked_user_id.eq.${uid})`)
                .maybeSingle()
            return !!data
        }

        // Helper: Wallet Deduction
        async function deductFromWallet(userId: string, amount: number, refId: string, type: string) {
            const { data: wallet } = await supabaseAdmin.from('user_wallets').select('*').eq('user_id', userId).single()
            if (!wallet || (Number(wallet.deposit_wallet) + Number(wallet.winning_wallet)) < amount) throw new Error('Insufficient balance')

            let remaining = amount
            let dep = Number(wallet.deposit_wallet)
            let win = Number(wallet.winning_wallet)
            let depDed = 0, winDed = 0

            if (dep >= remaining) { depDed = remaining; dep -= remaining; remaining = 0; }
            else { depDed = dep; remaining -= dep; dep = 0; winDed = remaining; win -= remaining; }

            const { error: updErr } = await supabaseAdmin.from('user_wallets').update({ deposit_wallet: dep, winning_wallet: win }).eq('user_id', userId)
            if (updErr) throw new Error('Wallet update failed')

            if (depDed > 0) await supabaseAdmin.from('wallet_transactions').insert({ user_id: userId, amount: depDed, type, wallet_type: 'deposit', status: 'completed', reference_id: refId })
            if (winDed > 0) await supabaseAdmin.from('wallet_transactions').insert({ user_id: userId, amount: winDed, type, wallet_type: 'winning', status: 'completed', reference_id: refId })
        }

        switch (action) {
            case 'create_challenge': {
                const { data: userProfile } = await supabaseAdmin.from('users').select('fair_score').eq('id', user.id).single()
                if (userProfile.fair_score < 30) throw new Error('Challenge access restricted due to low fair score')

                const { data: game } = await supabaseAdmin.from('games').select('*').eq('id', game_id).single()
                if (!game || !game.challenge_enabled) throw new Error('Challenges not enabled for this game')
                if (entry_fee < game.challenge_min_entry_fee) throw new Error(`Minimum entry fee is ${game.challenge_min_entry_fee}`)

                await deductFromWallet(user.id, entry_fee, 'pending_challenge', 'challenge_entry')

                const { data: challenge, error: createErr } = await supabaseAdmin.from('challenges').insert({
                    game_id, creator_id: user.id, entry_fee, mode, rules, settings, min_fair_score,
                    commission_percent: game.challenge_commission_percent, status: 'open'
                }).select().single()
                if (createErr) throw createErr

                return new Response(JSON.stringify({ success: true, challenge }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
            }

            case 'accept_challenge': {
                const { data: challenge } = await supabaseAdmin.from('challenges').select('*').eq('id', challenge_id).single()
                if (!challenge || challenge.status !== 'open') throw new Error('Challenge not available')
                if (challenge.creator_id === user.id) throw new Error('Cannot accept your own challenge')

                const { data: userProfile } = await supabaseAdmin.from('users').select('fair_score').eq('id', user.id).single()
                if (userProfile.fair_score < challenge.min_fair_score) throw new Error('Your fair score is too low for this challenge')
                if (userProfile.fair_score < 30) throw new Error('Challenge access restricted')

                if (await isBlocked(user.id, challenge.creator_id)) throw new Error('Interaction blocked by user')

                // Anti-abuse: Max 10 matches/day same players
                const { count } = await supabaseAdmin.from('challenges')
                    .select('*', { count: 'exact', head: true })
                    .or(`and(creator_id.eq.${user.id},opponent_id.eq.${challenge.creator_id}),and(creator_id.eq.${challenge.creator_id},opponent_id.eq.${user.id})`)
                    .filter('created_at', 'gte', new Date(new Date().setHours(0, 0, 0, 0)).toISOString())
                if (count && count >= 10) throw new Error('Daily match limit with this opponent reached')

                await deductFromWallet(user.id, challenge.entry_fee, challenge_id, 'challenge_entry')

                // Update challenge status
                const { error: acceptErr } = await supabaseAdmin.from('challenges').update({
                    status: 'accepted',
                    opponent_id: user.id,
                    accepted_at: new Date().toISOString()
                }).eq('id', challenge_id)

                if (acceptErr) throw acceptErr

                // Notify challenge creator
                await supabaseAdmin.functions.invoke('send_notification', {
                    body: {
                        user_id: challenge.creator_id,
                        title: 'Challenge Accepted!',
                        body: 'Your challenge has been accepted. Confirm ready to start.',
                        type: 'challenge',
                        related_id: challenge_id
                    }
                })

                return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
            }

            case 'confirm_ready': {
                const { data: challenge } = await supabaseAdmin.from('challenges').select('*').eq('id', challenge_id).single()
                if (challenge.status !== 'accepted' && challenge.status !== 'ready') throw new Error('Invalid status for confirmation')

                const isCreator = challenge.creator_id === user.id
                const isOpponent = challenge.opponent_id === user.id
                if (!isCreator && !isOpponent) throw new Error('Not a participant')

                const updateData: any = isCreator ? { creator_ready: true } : { opponent_ready: true }

                // If both are ready, move to 'ready' status
                if ((isCreator && challenge.opponent_ready) || (isOpponent && challenge.creator_ready)) {
                    updateData.status = 'ready'
                }

                const { error: updErr } = await supabaseAdmin.from('challenges').update(updateData).eq('id', challenge_id)
                if (updErr) throw updErr
                return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
            }

            case 'enter_room_details': {
                const { room_id, room_password } = requestBody
                const { data: challenge } = await supabaseAdmin.from('challenges').select('*').eq('id', challenge_id).single()

                if (challenge.creator_id !== user.id) throw new Error('Only creator can enter room details')
                if (challenge.status !== 'ready') throw new Error(`Challenge not ready (current status: ${challenge.status})`)

                const { error: roomErr } = await supabaseAdmin.from('challenges').update({
                    room_id,
                    room_password,
                    status: 'ongoing',
                    room_ready_at: new Date().toISOString()
                }).eq('id', challenge_id)

                if (roomErr) throw roomErr

                // Notify opponent
                await supabaseAdmin.functions.invoke('send_notification', {
                    body: {
                        user_id: challenge.opponent_id,
                        title: 'Room Ready!',
                        body: 'The room details are available. Join the match now.',
                        type: 'challenge',
                        related_id: challenge_id
                    }
                })

                return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
            }

            case 'submit_result': {
                const { result, screenshot_url, video_url, screenshot_hash } = requestBody
                const { data: challenge } = await supabaseAdmin.from('challenges').select('*').eq('id', challenge_id).single()
                if (challenge.status !== 'ongoing') throw new Error('Match not ongoing')

                // Screenshot Hash Check
                const { data: duplicateHash } = await supabaseAdmin.from('challenge_results').select('id').eq('screenshot_hash', screenshot_hash).maybeSingle()
                if (duplicateHash) throw new Error('Identical screenshot already used in another match')

                const { error: resErr } = await supabaseAdmin.from('challenge_results').insert({
                    challenge_id, user_id: user.id, result, screenshot_url, video_url, screenshot_hash
                })
                if (resErr) throw new Error('Result already submitted')

                const { data: allResults } = await supabaseAdmin.from('challenge_results').select('*').eq('challenge_id', challenge_id)
                if (allResults.length === 2) {
                    const res1 = allResults[0], res2 = allResults[1]
                    if (res1.result !== res2.result) {
                        const winnerId = res1.result === 'win' ? res1.user_id : res2.user_id
                        const totalPool = challenge.entry_fee * 2
                        const commission = totalPool * (challenge.commission_percent / 100)
                        const prize = totalPool - commission

                        const { error: prizeErr } = await supabaseAdmin.rpc('adjust_wallet_balance', {
                            p_user_id: winnerId,
                            p_amount: prize,
                            p_type: 'challenge_prize',
                            p_ref_id: challenge_id
                        })
                        if (prizeErr) {
                            console.error('Prize Distribution Error:', prizeErr)
                            throw new Error(`Failed to credit winner wallet: ${prizeErr.message}`)
                        }

                        const { error: completeErr } = await supabaseAdmin.from('challenges').update({ status: 'completed', winner_id: winnerId }).eq('id', challenge_id)
                        if (completeErr) throw completeErr

                        // Fair Play Rewards
                        await supabaseAdmin.functions.invoke('manage_fair_play', {
                            body: {
                                user_id: res1.user_id,
                                amount: 2,
                                reason: 'Fair match completed',
                                actor_id: res2.user_id
                            }
                        })
                        await supabaseAdmin.functions.invoke('manage_fair_play', {
                            body: {
                                user_id: res2.user_id,
                                amount: 2,
                                reason: 'Fair match completed',
                                actor_id: res1.user_id
                            }
                        })

                    } else {
                        await supabaseAdmin.from('challenges').update({ status: 'dispute' }).eq('id', challenge_id)

                        // Notify admin about dispute
                        await supabaseAdmin.functions.invoke('send_notification', {
                            body: {
                                is_broadcast: false,
                                title: 'New Dispute!',
                                body: `Conflict detected in match ${challenge_id}. Review required.`,
                                type: 'admin',
                                related_id: challenge_id
                            }
                        })
                    }
                }
                return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
            }

            case 'handle_timeouts': {
                const fiveMinsAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString()
                const { data: readyTimeouts } = await supabaseAdmin.from('challenges')
                    .select('*').eq('status', 'accepted').lt('accepted_at', fiveMinsAgo)

                for (const c of (readyTimeouts || [])) {
                    await deductFromWallet(c.creator_id, -c.entry_fee, c.id, 'challenge_refund')
                    await deductFromWallet(c.opponent_id, -c.entry_fee, c.id, 'challenge_refund')
                    await supabaseAdmin.from('challenges').update({ status: 'cancelled' }).eq('id', c.id)
                }

                const tenMinsAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString()
                const { data: roomTimeouts } = await supabaseAdmin.from('challenges')
                    .select('*').eq('status', 'ready').lt('accepted_at', tenMinsAgo)

                for (const c of (roomTimeouts || [])) {
                    await deductFromWallet(c.creator_id, -c.entry_fee, c.id, 'challenge_refund')
                    await deductFromWallet(c.opponent_id, -c.entry_fee, c.id, 'challenge_refund')
                    await supabaseAdmin.from('challenges').update({ status: 'cancelled' }).eq('id', c.id)
                }

                return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
            }

            case 'cancel_challenge': {
                const { data: challenge } = await supabaseAdmin.from('challenges').select('*').eq('id', challenge_id).single()
                if (challenge.status === 'open') {
                    if (challenge.creator_id !== user.id) throw new Error('Unauthorized')
                    await supabaseAdmin.from('challenges').update({ status: 'cancelled' }).eq('id', challenge_id)
                    await deductFromWallet(user.id, -challenge.entry_fee, challenge_id, 'challenge_refund')
                } else {
                    throw new Error('Mutual cancellation required (Contact Admin)')
                }
                return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
            }

            case 'resolve_dispute': {
                const { winner_id, resolution } = requestBody
                const { data: challenge } = await supabaseAdmin.from('challenges').select('*').eq('id', challenge_id).single()

                if (challenge.status !== 'dispute') throw new Error('Only disputed matches can be resolved')

                if (resolution === 'award_winner') {
                    const totalPot = challenge.entry_fee * 2
                    const commissionAmount = (totalPot * challenge.commission_percent) / 100
                    const prizeAmount = totalPot - commissionAmount

                    await supabaseAdmin.from('challenges').update({
                        status: 'completed',
                        winner_id: winner_id,
                        result_locked: true
                    }).eq('id', challenge_id)

                    await supabaseAdmin.rpc('adjust_wallet_balance', {
                        p_user_id: winner_id,
                        p_amount: prizeAmount,
                        p_type: 'challenge_prize',
                        p_ref_id: challenge_id
                    })
                } else if (resolution === 'refund') {
                    await supabaseAdmin.from('challenges').update({ status: 'cancelled', result_locked: true }).eq('id', challenge_id)
                    await deductFromWallet(challenge.creator_id, -challenge.entry_fee, challenge_id, 'challenge_refund')
                    await deductFromWallet(challenge.opponent_id, -challenge.entry_fee, challenge_id, 'challenge_refund')
                }
                return new Response(JSON.stringify({ success: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
            }

            default: throw new Error('Action not found')
        }

    } catch (error: any) {
        return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
