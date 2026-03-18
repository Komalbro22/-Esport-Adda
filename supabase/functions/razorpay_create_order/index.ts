import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'Unauthorized', message: 'Missing token' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY') ?? '';

        const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: authHeader } }
        });

        const token = authHeader.replace(/^[Bb]earer /, '').trim();
        const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token);

        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'Unauthorized', message: 'Invalid JWT' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        const { amount } = await req.json();

        if (!amount || amount <= 0) {
            return new Response(JSON.stringify({ error: 'Invalid amount' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

        // Fetch payment settings securely using Admin Client
        const { data: settings, error: settingsError } = await supabaseAdmin
            .from('payment_settings')
            .select('*')
            .limit(1)
            .single();

        if (settingsError || !settings) {
            return new Response(JSON.stringify({ error: 'Payment settings not found' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        if (settings.active_method !== 'razorpay') {
            return new Response(JSON.stringify({ error: 'Razorpay is not the active payment method' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        // Call Razorpay API to create an order
        const basicAuth = btoa(`${settings.razorpay_key_id}:${settings.razorpay_secret_key}`);

        // Amount should be in paise (multiply by 100)
        const amountInPaise = Math.round(amount * 100);

        const orderResponse = await fetch('https://api.razorpay.com/v1/orders', {
            method: 'POST',
            headers: {
                'Authorization': `Basic ${basicAuth}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                amount: amountInPaise,
                currency: 'INR',
                receipt: `receipt_${user.id.substring(0, 8)}_${Date.now()}`,
                notes: {
                    user_id: user.id
                }
            })
        });

        const orderData = await orderResponse.json();

        if (!orderResponse.ok) {
            console.error('Razorpay Order Error:', orderData);
            return new Response(JSON.stringify({ error: 'Failed to create order', details: orderData }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        // Insert into razorpay_transactions to track it
        await supabaseAdmin.from('razorpay_transactions').insert({
            user_id: user.id,
            order_id: orderData.id,
            amount: amount,
            status: 'created'
        });

        return new Response(JSON.stringify({ success: true, order: orderData }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });

    } catch (e) {
        console.error('Unexpected Error:', e.message);
        return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
});
