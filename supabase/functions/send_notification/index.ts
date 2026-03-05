import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Requires Firebase Service Account imported or using FCM HTTP v1 API
const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY') // For legacy protocol, or access token for v1

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
    const { title, body, target_user_id, is_broadcast } = await req.json()

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

    // Requires admin authorization
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
        status: 401, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    })

    const { data: adminCheck } = await supabaseAdmin.from('users').select('role').eq('id', user.id).single()
    if (adminCheck?.role !== 'admin') return new Response(JSON.stringify({ error: 'Forbidden' }), { 
        status: 403, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    })

    let targetTokens: string[] = []

    if (is_broadcast) {
        const { data: users } = await supabaseAdmin.from('users').select('fcm_token').not('fcm_token', 'is', null)
        if (users) targetTokens = users.map(u => u.fcm_token)
    } else if (target_user_id) {
        const { data: userRecord } = await supabaseAdmin.from('users').select('fcm_token').eq('id', target_user_id).single()
        if (userRecord?.fcm_token) targetTokens.push(userRecord.fcm_token)
    }

    // Fallback: Just insert into DB if no tokens
    if (is_broadcast) {
        await supabaseAdmin.from('notifications').insert({ title, body, user_id: null })
    } else if (target_user_id) {
        await supabaseAdmin.from('notifications').insert({ title, body, user_id: target_user_id })
    }

    if (targetTokens.length > 0 && FCM_SERVER_KEY) {
        // Send via FCM API
        for (const token of targetTokens) {
            await fetch('https://fcm.googleapis.com/fcm/send', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `key=${FCM_SERVER_KEY}`
                },
                body: JSON.stringify({
                    to: token,
                    notification: { title, body }
                })
            })
        }
    }

    return new Response(JSON.stringify({ success: true, sent_to: targetTokens.length }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    } catch (e) {
        return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
