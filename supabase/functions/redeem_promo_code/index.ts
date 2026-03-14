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
        const { promo_code } = await req.json()
        if (!promo_code) {
            return new Response(JSON.stringify({ error: 'Promo code is required' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY') ?? ''
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // 1. Get user from JWT
        const supabaseClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
            global: { headers: { Authorization: authHeader } }
        })
        const { data: { user }, error: authError } = await supabaseClient.auth.getUser()

        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 2. Fetch promo code details
        const { data: codeData, error: codeError } = await supabaseAdmin
            .from('promo_codes')
            .select('*')
            .eq('code', promo_code.toUpperCase())
            .eq('is_active', true)
            .single()

        if (codeError || !codeData) {
            return new Response(JSON.stringify({ error: 'Invalid or expired promo code' }), {
                status: 404,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 3. Check expiration
        if (codeData.expires_at && new Date(codeData.expires_at) < new Date()) {
            return new Response(JSON.stringify({ error: 'Promo code has expired' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 4. Check usage limit
        if (codeData.usage_type === 'limited' && codeData.times_used >= codeData.usage_limit) {
            return new Response(JSON.stringify({ error: 'Promo code usage limit reached' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 5. Check if user already redeemed this code
        const { data: existingRedemption } = await supabaseAdmin
            .from('promo_code_redemptions')
            .select('id')
            .eq('promo_code_id', codeData.id)
            .eq('user_id', user.id)
            .maybeSingle()

        if (existingRedemption) {
            return new Response(JSON.stringify({ error: 'You have already redeemed this promo code' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 6. Execute redemption (Atomic update)
        // We use a transaction-like approach by doing it in the correct order
        // and using RPC for balance increment to ensure atomicity at DB level.

        // a. Record redemption
        const { error: redemptionError } = await supabaseAdmin
            .from('promo_code_redemptions')
            .insert({
                promo_code_id: codeData.id,
                user_id: user.id
            })

        if (redemptionError) {
            return new Response(JSON.stringify({ error: 'Redemption failed', details: redemptionError.message }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // b. Update promo code usage count
        await supabaseAdmin.rpc('increment_promo_usage', { p_id: codeData.id })

        // c. Add money to user wallet
        const walletType = codeData.reward_type === 'winning' ? 'winning' : 'deposit'
        const rpcFunction = codeData.reward_type === 'winning' ? 'increment_winning_wallet' : 'increment_deposit_wallet'

        // Ensure increment_winning_wallet exists (we created increment_deposit_wallet earlier)
        // We might need to create it if not present.
        await supabaseAdmin.rpc(rpcFunction, { u_id: user.id, amt: codeData.reward_amount })

        // d. Record wallet transaction
        await supabaseAdmin.from('wallet_transactions').insert({
            user_id: user.id,
            amount: codeData.reward_amount,
            type: 'promo_code',
            wallet_type: walletType,
            status: 'completed',
            reference_id: `Promo Code: ${codeData.code}`
        })

        // e. Log activity
        await supabaseAdmin.from('user_activity_logs').insert({
            user_id: user.id,
            activity_type: 'promo_redeemed',
            description: `Redeemed promo code: ${codeData.code} for ₹${codeData.reward_amount}`,
            metadata: { code_id: codeData.id, amount: codeData.reward_amount, type: codeData.reward_type }
        })

        return new Response(JSON.stringify({
            success: true,
            message: `Success! ₹${codeData.reward_amount} added to your ${walletType} wallet.`,
            amount: codeData.reward_amount,
            type: codeData.reward_type
        }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

    } catch (err: any) {
        return new Response(JSON.stringify({ error: 'Internal server error', details: err.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
})
