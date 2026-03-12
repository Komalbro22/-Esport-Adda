import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        console.log('Redeem voucher request received');
        const authHeader = req.headers.get('Authorization')
        const apiKeyHeader = req.headers.get('apikey')

        console.log('Auth Header present:', !!authHeader);
        console.log('API Key Header present:', !!apiKeyHeader);

        if (!authHeader) {
            console.error('Missing Authorization header');
            return new Response(JSON.stringify({ error: 'Unauthorized', message: 'Missing Authorization header' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        const token = authHeader.replace(/^[Bb]earer /, '').trim();

        if (!token) {
            console.error('Empty token provided');
            return new Response(JSON.stringify({ error: 'Unauthorized', message: 'Empty token' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL')
        const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SERVICE_ROLE_KEY')

        console.log('Supabase URL present:', !!supabaseUrl);
        console.log('Service Role Key present:', !!serviceRoleKey);

        if (!supabaseUrl || !serviceRoleKey) {
            console.error('Missing environment variables');
            return new Response(JSON.stringify({ error: 'Internal Server Error', message: 'Server configuration missing' }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // Initialize Supabase Admin Client
        const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)

        // Verify user is authenticated using the token explicitly
        console.log('Verifying token...');
        const { data: { user }, error: userError } = await supabaseAdmin.auth.getUser(token)

        if (userError || !user) {
            console.error('JWT Verification Failed:', userError?.message || 'No user found');
            return new Response(JSON.stringify({
                error: 'Unauthorized',
                message: `Auth Error: ${userError?.message || 'Invalid JWT'}`,
                debug_token_preview: token.substring(0, 10) + '...'
            }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        console.log('User verified:', user.id);

        const { category_id, amount } = await req.json()

        if (!category_id || !amount || amount <= 0) {
            return new Response(JSON.stringify({ error: 'Invalid input' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        // Call custom RPC function for atomic operations
        // We pass the user id, category id, and amount. The RPC should handle:
        // 1. Checking wallet balance
        // 2. Finding an available voucher
        // 3. Deducting balance and marking voucher used OR creating a request
        const { data: redeemResult, error: rpcError } = await supabaseAdmin.rpc('process_voucher_withdrawal', {
            p_user_id: user.id,
            p_category_id: category_id,
            p_amount: amount
        });

        if (rpcError) {
            return new Response(JSON.stringify({ error: rpcError.message }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            })
        }

        return new Response(JSON.stringify(redeemResult), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }
})
