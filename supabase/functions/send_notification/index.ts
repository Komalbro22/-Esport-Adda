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

        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

        const token = authHeader?.replace(/^[Bb]earer /, '').trim();
        let isAuthorized = false;

        if (token === supabaseServiceKey) {
            isAuthorized = true;
        } else if (token) {
            const { data: { user } } = await supabaseAdmin.auth.getUser(token);
            if (user) {
                const { data: profile } = await supabaseAdmin.from('users').select('role').eq('id', user.id).single();
                if (profile && (profile.role === 'admin' || profile.role === 'super_admin')) {
                    isAuthorized = true;
                }
            }
        }

        if (!isAuthorized) {
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
            const { data: users } = await supabaseAdmin.from('users').select('id');
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
            const { data: user } = await supabaseAdmin.from('users').select('onesignal_player_id').eq('id', user_id).single()
            if (user?.onesignal_player_id) targetPlayerIds = [user.onesignal_player_id];
            targetUserIds = [user_id];
        }

        // DB Log
        // Your DB schema has existed in 2 shapes:
        // 1) title + message + type + reference_id
        // 2) title + body (legacy)
        // To make notifications reliable, try the modern schema first, then fallback to legacy.
        if (targetUserIds.length > 0) {
            const messageText = body;
            const referenceId = related_id || tournament_id;

            try {
                await supabaseAdmin.from('notifications').insert(
                    targetUserIds.map((uid) => ({
                        user_id: uid,
                        title,
                        message: messageText,
                        type: type || 'admin_push',
                        reference_id: referenceId
                    }))
                );
            } catch (e) {
                // Fallback insert for legacy schema (no message/type/reference_id)
                try {
                    await supabaseAdmin.from('notifications').insert(
                        targetUserIds.map((uid) => ({
                            user_id: uid,
                            title,
                            body: messageText
                        }))
                    );
                } catch (e2) {
                    return new Response(
                        JSON.stringify({
                            success: false,
                            error: 'Failed to save notifications to DB',
                            insert_error_modern: e,
                            insert_error_legacy: e2
                        }),
                        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                    );
                }
            }
        }

        // ONE SIGNAL SEND
        const osPayload: any = {
            app_id: ONESIGNAL_APP_ID,
            headings: { en: title },
            contents: { en: body },
            data: { type, related_id, tournament_id }
        };

        if (is_broadcast) {
            osPayload.included_segments = ["All"];
        } else if (targetPlayerIds.length > 0) {
            osPayload.include_subscription_ids = targetPlayerIds;
        } else {
            return new Response(JSON.stringify({ success: true, message: 'Saved to history, but no active devices' }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        // Try 'Basic' first, then 'Key' if it fails
        let response = await fetch('https://onesignal.com/api/v1/notifications', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}` },
            body: JSON.stringify(osPayload)
        });

        let data = await response.json();

        if (!response.ok && data.errors?.includes("Access denied")) {
             // Fallback to 'Key'
             response = await fetch('https://onesignal.com/api/v1/notifications', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Key ${ONESIGNAL_REST_API_KEY}` },
                body: JSON.stringify(osPayload)
            });
            data = await response.json();
        }

        if (!response.ok) {
            return new Response(JSON.stringify({ success: false, error: data }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        return new Response(JSON.stringify({ success: true, data }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

    } catch (error: any) {
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }
})
