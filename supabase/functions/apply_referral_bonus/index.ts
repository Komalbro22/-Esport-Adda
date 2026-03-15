import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7"

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
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
        const supabaseServiceKey = Deno.env.get('SERVICE_ROLE_KEY') ?? ''

        const supabase = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: authHeader } }
        })

        const { data: { user }, error: authError } = await supabase.auth.getUser()
        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'User not authenticated' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const { referral_code, new_user_id } = await req.json()
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // 1. Authorization Check
        if (user.id !== new_user_id) {
            const { data: callerProfile } = await supabaseAdmin.from('users').select('role').eq('id', user.id).single()
            if (!callerProfile || (callerProfile.role !== 'admin' && callerProfile.role !== 'super_admin')) {
                return new Response(JSON.stringify({ error: 'Access denied' }), { status: 403, headers: corsHeaders })
            }
        }

        // 2. Fetch Referrer
        const { data: referrer, error: refError } = await supabaseAdmin.from('users').select('id').eq('referral_code', referral_code).single()
        if (refError || !referrer) return new Response(JSON.stringify({ error: 'Invalid referral code' }), { status: 400, headers: corsHeaders })
        if (referrer.id === new_user_id) return new Response(JSON.stringify({ error: 'Self-referral not allowed' }), { status: 400, headers: corsHeaders })

        // 3. ROBUST DOUBLE-REWARD CHECK: Check transactions and current referred_by status
        const { data: profile } = await supabaseAdmin.from('users').select('referred_by').eq('id', new_user_id).single()
        if (profile?.referred_by) return new Response(JSON.stringify({ error: 'Already referred' }), { status: 400, headers: corsHeaders })

        const { data: existingTx } = await supabaseAdmin.from('wallet_transactions')
            .select('id').eq('user_id', new_user_id).eq('type', 'referral_bonus').maybeSingle()
        if (existingTx) return new Response(JSON.stringify({ error: 'Reward already claimed' }), { status: 400, headers: corsHeaders })

        // 4. Fetch Config
        const { data: settings } = await supabaseAdmin.from('app_settings').select('referral_bonus_sender, referral_bonus_receiver').limit(1).maybeSingle()
        const senderAmt = settings?.referral_bonus_sender ?? 10
        const receiverAmt = settings?.referral_bonus_receiver ?? 10

        // 5. Execute Rewards via Atomic RPC
        // award receiver
        await supabaseAdmin.rpc('increment_wallet_v2', { 
            p_user_id: new_user_id, 
            p_amount: receiverAmt, 
            p_wallet_type: 'deposit',
            p_transaction_type: 'referral_bonus', 
            p_reference_id: referral_code,
            p_message: `Referral Joiner Reward (Code: ${referral_code})`
        })

        // award sender
        await supabaseAdmin.rpc('increment_wallet_v2', { 
            p_user_id: referrer.id, 
            p_amount: senderAmt, 
            p_wallet_type: 'deposit',
            p_transaction_type: 'referral_bonus', 
            p_reference_id: new_user_id,
            p_message: `Referral Sender Reward (User: ${new_user_id})`
        })

        // 6. Finalize link
        await supabaseAdmin.from('users').update({ referred_by: referral_code }).eq('id', new_user_id)

        return new Response(JSON.stringify({ success: true, message: 'Bonus applied!' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

    } catch (err: any) {
        console.error('Referral Error:', err);
        return new Response(JSON.stringify({ error: 'Server error' }), { status: 500, headers: corsHeaders })
    }
})
