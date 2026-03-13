import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID') || '';
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY') || '';

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const authHeader = req.headers.get('Authorization')
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY') ?? ''

        // Create admin client
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        // Auth check... (kept simplified for brevity here, mirroring original structure)
        const token = authHeader?.replace(/^[Bb]earer /, '').trim();
        let isSystemCall = token === supabaseServiceKey;

        if (!isSystemCall && !authHeader) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const payload = await req.json()
        const { user_id, title, body, type, related_id, tournament_id, is_broadcast } = payload

        let targetPlayerIds: string[] = []
        let targetUserIds: string[] = []

        if (is_broadcast) {
            // OneSignal can send to "All Users" directly via segments, 
            // but we'll still want to store in DB for history
            const { data: users } = await supabaseAdmin
                .from('users')
                .select('id')

            if (users) targetUserIds = users.map(u => u.id);
        } else if (tournament_id) {
            const { data: participants } = await supabaseAdmin
                .from('joined_teams')
                .select('user_id, users(onesignal_player_id)')
                .eq('tournament_id', tournament_id)

            if (participants) {
                targetPlayerIds = participants.map(p => p.users?.onesignal_player_id).filter(id => id);
                targetUserIds = participants.map(p => p.user_id);
            }
        } else if (user_id) {
            const { data: user } = await supabaseAdmin
                .from('users')
                .select('onesignal_player_id')
                .eq('id', user_id)
                .single()

            if (user?.onesignal_player_id) {
                targetPlayerIds = [user.onesignal_player_id];
                targetUserIds = [user_id];
            } else if (user_id) {
                targetUserIds = [user_id];
            }
        }

        // 1. Save Notification to DB (centralized history)
        if (targetUserIds.length > 0) {
            const notificationsToInsert = targetUserIds.map(uid => ({
                user_id: uid,
                title,
                message: body,
                type: type || 'system',
                reference_id: related_id || tournament_id
            }));

            const { error: dbError } = await supabaseAdmin.from('notifications').insert(notificationsToInsert)
            if (dbError) console.error("DB Insert Error: ", dbError)
        }

        // 2. Send via OneSignal
        const oneSignalPayload: any = {
            app_id: ONESIGNAL_APP_ID,
            headings: { en: title },
            contents: { en: body },
            data: { type, related_id, tournament_id }
        };

        if (is_broadcast) {
            oneSignalPayload.included_segments = ["Active Users", "Inactive Users"];
        } else if (targetPlayerIds.length > 0) {
            oneSignalPayload.include_subscription_ids = targetPlayerIds;
        } else {
            return new Response(JSON.stringify({ success: true, message: 'Saved to DB, but no active OneSignal players found.' }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const oneSignalRes = await fetch('https://onesignal.com/api/v1/notifications', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Key ${ONESIGNAL_REST_API_KEY}`
            },
            body: JSON.stringify(oneSignalPayload)
        });

        const oneSignalData = await oneSignalRes.json();

        return new Response(JSON.stringify({
            success: true,
            onesignal: oneSignalData,
            saved_count: targetUserIds.length
        }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

    } catch (error: any) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
})
