import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7"

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
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
        const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY') ?? ''

        // 1. Initialize Supabase Client using Authorization header (Requirement 3)
        const authHeader = req.headers.get('Authorization')
        const supabase = createClient(
            supabaseUrl,
            supabaseAnonKey,
            {
                global: {
                    headers: {
                        Authorization: authHeader ?? ''
                    }
                }
            }
        )

        // 2. Verify the user (Requirement 4)
        const { data: { user }, error: authError } = await supabase.auth.getUser()

        // 3. If user is null or error, return specific error (Requirement 5)
        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'User not authenticated' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 4. Extract Body
        const { promo_code } = await req.json()
        if (!promo_code) {
            return new Response(JSON.stringify({ error: 'Promo code is required' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 5. Promo Code Logic (Requirement 6: Keep unchanged)
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

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

        // Check expiration
        if (codeData.expires_at && new Date(codeData.expires_at) < new Date()) {
            return new Response(JSON.stringify({ error: 'Promo code has expired' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Check usage limit
        if (codeData.usage_type === 'limited' && codeData.times_used >= codeData.usage_limit) {
            return new Response(JSON.stringify({ error: 'Promo code usage limit reached' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Check if user already redeemed
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

        // Execute redemption
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

        await supabaseAdmin.rpc('increment_promo_usage', { p_id: codeData.id })

        const walletType = codeData.reward_type === 'winning' ? 'winning' : 'deposit'
        const rpcFunction = codeData.reward_type === 'winning' ? 'increment_winning_wallet' : 'increment_deposit_wallet'
        await supabaseAdmin.rpc(rpcFunction, { u_id: user.id, amt: codeData.reward_amount })

        await supabaseAdmin.from('wallet_transactions').insert({
            user_id: user.id,
            amount: codeData.reward_amount,
            type: 'promo_code',
            wallet_type: walletType,
            status: 'completed',
            reference_id: `Promo Code: ${codeData.code}`
        })

        await supabaseAdmin.from('user_activity_logs').insert({
            user_id: user.id,
            activity_type: 'promo_redeemed',
            description: `Redeemed promo code: ${codeData.code} for ₹${codeData.reward_amount}`,
            metadata: { code_id: codeData.id, amount: codeData.reward_amount, type: codeData.reward_type }
        })

        return new Response(JSON.stringify({
            success: true,
            message: `Success! ₹${codeData.reward_amount} added to your ${walletType} wallet.`,
        }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

    } catch (err: any) {
        console.error('Redemption Error:', err);
        return new Response(JSON.stringify({
            error: err.message || 'Internal server error',
            details: err.details || null
        }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
})
