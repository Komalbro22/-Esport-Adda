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
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        const body = await req.json()
        const { action, user_id, amount, reason, actor_id } = body

        // 1. Fetch current score
        const { data: userProfile } = await supabaseAdmin.from('users').select('fair_score').eq('id', user_id).single()
        if (!userProfile) throw new Error('User not found')

        const currentScore = userProfile.fair_score
        let newScore = currentScore + amount

        // Constraints: Default max is usually 100, but user said "Allow scores above 100" (up to 200 for VIP)
        if (newScore < 0) newScore = 0
        if (newScore > 200) newScore = 200

        // Anti-Abuse Checks for Rewards (amount > 0)
        if (amount > 0) {
            const today = new Date(new Date().setHours(0, 0, 0, 0)).toISOString()

            // 1. Daily Total Limit (+5)
            const { data: todayLogs } = await supabaseAdmin.from('fair_score_logs')
                .select('new_score, previous_score')
                .eq('user_id', user_id)
                .gte('created_at', today)

            const dailyGain = todayLogs.reduce((acc: number, log: any) => acc + Math.max(0, log.new_score - log.previous_score), 0)
            if (dailyGain >= 5) {
                return new Response(JSON.stringify({ success: false, message: 'Daily fair score gain limit reached (+5)' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
            }

            // 2. Same Opponent Limit (+2)
            if (reason === 'Fair match completed' && actor_id && actor_id !== 'system') {
                const { data: opponentLogs } = await supabaseAdmin.from('fair_score_logs')
                    .select('id')
                    .eq('user_id', user_id)
                    .eq('actor_id', actor_id)
                    .eq('change_reason', 'Fair match completed')
                    .gte('created_at', today)

                if (opponentLogs && opponentLogs.length >= 2) {
                    return new Response(JSON.stringify({ success: false, message: 'Daily limit from this opponent reached (+2)' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
                }
            }
        }

        // Update Score
        const { error: updErr } = await supabaseAdmin.from('users').update({ fair_score: newScore }).eq('id', user_id)
        if (updErr) throw updErr

        // Log Change
        await supabaseAdmin.from('fair_score_logs').insert({
            user_id, previous_score: currentScore, new_score: newScore, change_reason: reason, actor_id
        })

        // Auto-Ban Rule: fair_score < 30
        if (newScore < 30) {
            // In a real app, you might set is_blocked = true or a specific flag.
            // For now, the manage_challenges function checks fair_score < 30.
        }

        return new Response(JSON.stringify({ success: true, new_score: newScore }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

    } catch (error: any) {
        return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
