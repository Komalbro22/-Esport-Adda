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
        const { referral_code, new_user_id } = await req.json()

        const authHeader = req.headers.get('Authorization')!
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: authHeader } } }
        )

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SERVICE_ROLE_KEY') ?? ''
        )

        const { data: { user } } = await supabaseClient.auth.getUser()
        if (!user || user.id !== new_user_id) return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
            status: 401, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        })

        // Find referrer
        const { data: referrer, error: refError } = await supabaseAdmin
            .from('users')
            .select('id')
            .eq('referral_code', referral_code)
            .single()

        if (refError || !referrer) return new Response(JSON.stringify({ error: 'Invalid referral code' }), { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        })
        if (referrer.id === new_user_id) return new Response(JSON.stringify({ error: 'Cannot refer yourself' }), { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        })

        // Ensure hasn't been applied (e.g., check if referred_by is already set)
        const { data: currentUser } = await supabaseAdmin
            .from('users')
            .select('referred_by')
            .eq('id', new_user_id)
            .single()

        if (currentUser?.referred_by) return new Response(JSON.stringify({ error: 'Referral already applied' }), { 
            status: 400, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        })

        const bonusAmount = 10 // e.g. 10 deposit currency

        // Give new user bonus
        await supabaseAdmin.rpc('increment_deposit_wallet', { u_id: new_user_id, amt: bonusAmount })
        await supabaseAdmin.from('wallet_transactions').insert({
            user_id: new_user_id,
            amount: bonusAmount,
            type: 'referral_bonus',
            wallet_type: 'deposit',
            status: 'completed'
        })

        // Give referrer bonus
        await supabaseAdmin.rpc('increment_deposit_wallet', { u_id: referrer.id, amt: bonusAmount })
        await supabaseAdmin.from('wallet_transactions').insert({
            user_id: referrer.id,
            amount: bonusAmount,
            type: 'referral_bonus',
            wallet_type: 'deposit',
            status: 'completed'
        })

        // Update referred_by
        await supabaseAdmin.from('users').update({ referred_by: referral_code }).eq('id', new_user_id)

        return new Response(JSON.stringify({ success: true, bonus: bonusAmount }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    } catch (err: any) {
        return new Response(JSON.stringify({ error: err.message }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
