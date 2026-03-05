import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'
import serviceAccount from './service_account.json' assert { type: 'json' }
import { JWT } from 'npm:google-auth-library@9.0.0'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        const payload = await req.json()
        const { user_id, title, body, type, related_id, tournament_id, is_broadcast } = payload

        let targetTokens: string[] = []
        let targetUserIds: string[] = []
        if (is_broadcast) {
            // Fetch all users with valid fcm_token
            const { data: users, error } = await supabaseClient
                .from('users')
                .select('id, fcm_token')
                .not('fcm_token', 'is', null)

            if (users && users.length > 0) {
                targetTokens = users.map(u => u.fcm_token).filter(t => t);
            }
        } else if (tournament_id) {
            // Fetch users who joined this tournament
            const { data: participants, error } = await supabaseClient
                .from('tournament_participants')
                .select('user_id, users(fcm_token)')
                .eq('tournament_id', tournament_id)

            if (participants && participants.length > 0) {
                targetTokens = participants.map((p: any) => p.users?.fcm_token).filter(t => t);
                targetUserIds = participants.map((p: any) => p.user_id);
            }
        } else if (user_id) {
            // Single user
            const { data: user, error } = await supabaseClient
                .from('users')
                .select('fcm_token')
                .eq('id', user_id)
                .single()

            if (user && user.fcm_token) {
                targetTokens = [user.fcm_token]
                targetUserIds = [user_id]
            }
        }

        // 1. Save Notification to DB
        const notificationsToInsert = []
        if (is_broadcast) {
            notificationsToInsert.push({ user_id: null, title, body, type: type || 'broadcast', related_id })
        } else if (targetUserIds.length > 0) {
            for (const uid of targetUserIds) {
                notificationsToInsert.push({ user_id: uid, title, body, type: type || 'personal', related_id })
            }
        } else if (user_id) {
            // Insert it even if token missing, they'll see it in app
            notificationsToInsert.push({ user_id, title, body, type: type || 'personal', related_id })
        }

        if (notificationsToInsert.length > 0) {
            const { error: dbError } = await supabaseClient.from('notifications').insert(notificationsToInsert)
            if (dbError) console.error("DB Insert Error: ", dbError)
        }

        // 2. Send via FCM
        if (targetTokens.length > 0) {
            const auth = new JWT({
                email: serviceAccount.client_email,
                key: serviceAccount.private_key,
                scopes: ['https://www.googleapis.com/auth/firebase.messaging']
            })
            const tokens = await auth.getAccessToken()

            const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`

            const sendPromises = targetTokens.map(async (token) => {
                const res = await fetch(fcmUrl, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        Authorization: `Bearer ${tokens.token}`
                    },
                    body: JSON.stringify({
                        message: {
                            token: token,
                            notification: { title, body },
                            data: { type: type || '', related_id: related_id || '' }
                        }
                    })
                })
                return res.json()
            })

            const results = await Promise.all(sendPromises)
            return new Response(JSON.stringify({ success: true, results, saved_count: notificationsToInsert.length }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
        }

        return new Response(JSON.stringify({ success: true, message: 'No devices to notify, but saved to DB.' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

    } catch (error: any) {
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
