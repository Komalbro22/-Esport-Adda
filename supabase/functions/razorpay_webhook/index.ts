import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Utility to verify webhook signature
async function verifyWebhookSignature(body: string, signature: string, secret: string): Promise<boolean> {
    const encoder = new TextEncoder();
    const keyData = encoder.encode(secret);

    const cryptoKey = await crypto.subtle.importKey(
        "raw",
        keyData,
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
        encoder.encode(body)
    );

    return isValid;
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const bodyText = await req.text();
        const signature = req.headers.get('x-razorpay-signature');

        if (!signature) {
            console.error('Missing Razorpay signature');
            return new Response('Unauthorized', { status: 401 });
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY') ?? '';
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

        const { data: settings } = await supabaseAdmin
            .from('payment_settings')
            .select('*')
            .limit(1)
            .single();

        if (!settings || !settings.razorpay_webhook_secret) {
            console.error('Webhook secret not configured');
            return new Response('Webhook secret missing', { status: 500 });
        }

        const isValid = await verifyWebhookSignature(bodyText, signature, settings.razorpay_webhook_secret);

        if (!isValid) {
            console.error('Invalid signature');
            return new Response('Invalid signature', { status: 400 });
        }

        const payload = JSON.parse(bodyText);

        if (payload.event === 'payment.captured') {
            const paymentObj = payload.payload.payment.entity;
            const paymentId = paymentObj.id;
            const orderId = paymentObj.order_id;
            const amountInPaise = paymentObj.amount;
            const amount = amountInPaise / 100;
            const userId = paymentObj.notes?.user_id;

            if (!userId) {
                console.error('No user_id found in notes');
                return new Response('OK', { status: 200 });
            }

            // Check if transaction is already processed to prevent duplicate processing
            const { data: existingTx } = await supabaseAdmin
                .from('razorpay_transactions')
                .select('*')
                .eq('order_id', orderId)
                .single();

            if (existingTx && existingTx.status === 'captured') {
                console.log('Payment already captured', orderId);
                return new Response('OK', { status: 200 });
            }

            // Update razorpay transaction
            await supabaseAdmin.from('razorpay_transactions')
                .update({ status: 'captured', payment_id: paymentId })
                .eq('order_id', orderId);

            // Fetch current empty or actual wallet
            const { data: wallet } = await supabaseAdmin
                .from('user_wallets')
                .select('deposit_wallet')
                .eq('user_id', userId)
                .single();

            const currentDeposit = wallet?.deposit_wallet || 0;

            // Credit the user's wallet (Platform absorbs the fees according to rules)
            await supabaseAdmin.from('user_wallets')
                .update({ deposit_wallet: currentDeposit + amount })
                .eq('user_id', userId);

            // Record into wallet_transactions
            await supabaseAdmin.from('wallet_transactions').insert({
                user_id: userId,
                amount: amount,
                type: 'deposit',
                wallet_type: 'deposit',
                status: 'completed',
                reference_id: paymentId
            });

            // Send notification
            await supabaseAdmin.functions.invoke('send_notification', {
                body: {
                    user_id: userId,
                    title: `Deposit Successful`,
                    body: `Your deposit of ₹${amount} via Razorpay was successful.`,
                    type: 'deposit_status'
                }
            });
        }

        return new Response(JSON.stringify({ status: 'ok' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

    } catch (e) {
        console.error('Unexpected Webhook Error:', e.message);
        return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
});
