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
            console.error('Auth Error:', authError?.message || 'User not found');
            return new Response(JSON.stringify({
                error: 'User not authenticated',
                details: authError?.message || 'User not found.'
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const { referral_code, new_user_id } = await req.json()

        // Authorization: Either caller is the new user, or caller is an admin
        if (user.id !== new_user_id) {
            const { data: callerProfile } = await supabaseAdmin
                .from('users')
                .select('role')
                .eq('id', user.id)
                .single()

            if (!callerProfile || (callerProfile.role !== 'admin' && callerProfile.role !== 'super_admin')) {
                return new Response(JSON.stringify({ error: 'Access denied' }), {
                    status: 403,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                })
            }
        }

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

        // Log Activity for Receiver
        await supabaseAdmin.from('user_activity_logs').insert({
            user_id: new_user_id,
            activity_type: 'referral_received',
            description: `Referral bonus received using code: ${referral_code}`,
            metadata: { referral_code, bonus: receiverBonus }
        })

        // Log Activity for Referrer (Sender)
        await supabaseAdmin.from('user_activity_logs').insert({
            user_id: referrer.id,
            activity_type: 'referral_given',
            description: `Referral bonus given for referring user: ${new_user_id}`,
            metadata: { referred_user_id: new_user_id, bonus: senderBonus }
        })

        return new Response(JSON.stringify({ success: true, bonus: receiverBonus }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    } catch (err: any) {
        return new Response(JSON.stringify({ error: err.message }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
