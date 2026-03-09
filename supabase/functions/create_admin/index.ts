import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

    try {
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

        const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY')!;

        // Admin client with service role
        const adminClient = createClient(supabaseUrl, supabaseServiceKey);

        // Verify caller JWT explicitly
        const token = authHeader.replace('Bearer ', '');
        const { data: { user }, error: authErr } = await adminClient.auth.getUser(token);

        if (authErr || !user) {
            console.error('JWT Verification Failed:', authErr?.message || 'No user returned', authErr);
            return new Response(JSON.stringify({ error: 'Unauthorized', message: authErr?.message || 'Invalid token' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        const { data: callerRec, error: roleErr } = await adminClient
            .from('users')
            .select('role, name, is_blocked')
            .eq('id', user.id)
            .single();

        if (roleErr || callerRec?.role !== 'super_admin' || callerRec?.is_blocked) {
            console.error('Caller Role Error:', roleErr?.message || 'Not a super_admin', 'Role:', callerRec?.role);
            return new Response(JSON.stringify({ error: 'Access denied: super_admin only' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        const { name, email, password, phone, permissions } = await req.json();

        if (!email || !password || !name) {
            return new Response(JSON.stringify({ error: 'name, email and password are required' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        // Create Supabase auth user
        const { data: newAuthUser, error: createErr } = await adminClient.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: { name, role: 'admin' },
        });

        if (createErr || !newAuthUser.user) {
            return new Response(JSON.stringify({ error: createErr?.message ?? 'Failed to create user' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        const newUserId = newAuthUser.user.id;

        // Patch users table (trigger creates the row but with role=player by default)
        await adminClient.from('users').update({
            role: 'admin',
            name,
            phone: phone ?? null,
        }).eq('id', newUserId);

        // Insert admin_permissions
        await adminClient.from('admin_permissions').upsert({
            user_id: newUserId,
            can_manage_games: permissions?.can_manage_games ?? false,
            can_manage_tournaments: permissions?.can_manage_tournaments ?? false,
            can_manage_results: permissions?.can_manage_results ?? false,
            can_manage_deposits: permissions?.can_manage_deposits ?? false,
            can_manage_withdrawals: permissions?.can_manage_withdrawals ?? false,
            can_manage_users: permissions?.can_manage_users ?? false,
            can_send_notifications: permissions?.can_send_notifications ?? false,
            can_view_dashboard: permissions?.can_view_dashboard ?? true,
        });

        // Log the action
        await adminClient.from('admin_activity_logs').insert({
            admin_id: user.id,
            admin_name: callerRec.name,
            action: 'create_admin',
            target_type: 'user',
            target_id: newUserId,
            details: { new_admin_email: email, new_admin_name: name },
        });

        return new Response(JSON.stringify({ success: true, new_admin_id: newUserId }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });

    } catch (err) {
        return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
});
