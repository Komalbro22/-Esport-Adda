import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

async function verifyPaymentSignature(orderId: string, paymentId: string, signature: string, secret: string): Promise<boolean> {
    const encoder = new TextEncoder();
    const data = encoder.encode(`${orderId}|${paymentId}`);
    const key = encoder.encode(secret);

    const cryptoKey = await crypto.subtle.importKey(
        "raw",
        key,
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign", "verify"]
    );

    const signatureBytes = new Uint8Array(
        signature.match(/.{1,2}/g)?.map((byte) => parseInt(byte, 16)) || []
    );

    const isValid = await crypto.subtle.verify(
        "HMAC",
        cryptoKey,
        signatureBytes,
        data
    );

    return isValid;
}

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

        const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = await req.json();

        if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
            return new Response(JSON.stringify({ error: 'Missing parameters' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

        const { data: settings } = await supabaseAdmin
            .from('payment_settings')
            .select('*')
            .limit(1)
            .single();

        if (!settings || !settings.razorpay_secret_key) {
            return new Response(JSON.stringify({ error: 'Payment settings not found' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        const isValid = await verifyPaymentSignature(razorpay_order_id, razorpay_payment_id, razorpay_signature, settings.razorpay_secret_key);

        if (!isValid) {
            return new Response(JSON.stringify({ error: 'Invalid signature' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        // Signature is valid. Check if already processed
        const { data: existingTx } = await supabaseAdmin
            .from('razorpay_transactions')
            .select('*')
            .eq('order_id', razorpay_order_id)
            .single();

        if (existingTx && existingTx.status === 'captured') {
            return new Response(JSON.stringify({ success: true, message: 'Already processed' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        if (!existingTx) {
            return new Response(JSON.stringify({ error: 'Transaction not found for this order' }), { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        const amount = existingTx.amount;

        // Process payment
        await supabaseAdmin.from('razorpay_transactions')
            .update({ status: 'captured', payment_id: razorpay_payment_id, signature: razorpay_signature })
            .eq('order_id', razorpay_order_id);

        const { data: wallet } = await supabaseAdmin
            .from('user_wallets')
            .select('deposit_wallet')
            .eq('user_id', user.id)
            .single();

        const currentDeposit = wallet?.deposit_wallet || 0;

        await supabaseAdmin.from('user_wallets')
            .update({ deposit_wallet: currentDeposit + amount })
            .eq('user_id', user.id);

        await supabaseAdmin.from('wallet_transactions').insert({
            user_id: user.id,
            amount: amount,
            type: 'deposit',
            wallet_type: 'deposit',
            status: 'completed',
            reference_id: razorpay_payment_id
        });

        // Notifications or other integrations can go here

        return new Response(JSON.stringify({ success: true, amount }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });

    } catch (e) {
        console.error('Unexpected Error:', e.message);
        return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
});
