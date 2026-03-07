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

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SERVICE_ROLE_KEY') ?? ''
        )

        // Verify the user exists via Admin (bypasses the JWT issue during signup)
        const { data: newUser, error: userError } = await supabaseAdmin
            .from('users')
            .select('id, referred_by')
            .eq('id', new_user_id)
            .single()

        if (userError || !newUser) {
            return new Response(JSON.stringify({ error: 'User not found' }), {
                status: 404,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

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

        // Fetch bonus amounts from app_settings (assuming one row)
        const { data: settings, error: settingsError } = await supabaseAdmin
            .from('app_settings')
            .select('referral_bonus_sender, referral_bonus_receiver')
            .limit(1)
            .maybeSingle()

        if (settingsError) return new Response(JSON.stringify({ error: 'Failed to fetch settings' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

        const senderBonus = settings?.referral_bonus_sender ?? 10
        const receiverBonus = settings?.referral_bonus_receiver ?? 10

        // Give new user bonus
        await supabaseAdmin.rpc('increment_deposit_wallet', { u_id: new_user_id, amt: receiverBonus })
        await supabaseAdmin.from('wallet_transactions').insert({
            user_id: new_user_id,
            amount: receiverBonus,
            type: 'referral_bonus',
            wallet_type: 'deposit',
            status: 'completed',
            reference_id: `Referral Joiner Bonus (Code: ${referral_code})`
        })

        // Give referrer bonus
        await supabaseAdmin.rpc('increment_deposit_wallet', { u_id: referrer.id, amt: senderBonus })
        await supabaseAdmin.from('wallet_transactions').insert({
            user_id: referrer.id,
            amount: senderBonus,
            type: 'referral_bonus',
            wallet_type: 'deposit',
            status: 'completed',
            reference_id: `Referral Reward (User: ${new_user_id})`
        })

        // Update referred_by
        await supabaseAdmin.from('users').update({ referred_by: referral_code }).eq('id', new_user_id)

        return new Response(JSON.stringify({ success: true, bonus: receiverBonus }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    } catch (err: any) {
        return new Response(JSON.stringify({ error: err.message }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
