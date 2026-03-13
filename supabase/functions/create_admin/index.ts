import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const validateEmail = (email: string) => {
    return String(email)
        .toLowerCase()
        .match(
            /^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
        );
};

serve(async (req) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

    try {
        const authHeader = req.headers.get('Authorization');
        if (!authHeader) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

        const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY')!;

        const adminClient = createClient(supabaseUrl, supabaseServiceKey);

        // Verify caller JWT
        const token = authHeader.replace('Bearer ', '');
        const { data: { user }, error: authErr } = await adminClient.auth.getUser(token);

        if (authErr || !user) {
            return new Response(JSON.stringify({ error: 'Unauthorized', message: authErr?.message || 'Invalid token' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        // Only super_admin can create admins
        const { data: callerRec } = await adminClient
            .from('users')
            .select('role')
            .eq('id', user.id)
            .single();

        if (callerRec?.role !== 'super_admin') {
            return new Response(JSON.stringify({ error: 'Access denied: super_admin only' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        const payload = await req.json();
        const { name, email, password, phone, permissions } = payload;

        console.log(`Attempting to create admin: ${email} (Name: ${name})`);

        if (!email || !password || !name) {
            return new Response(JSON.stringify({ error: 'name, email and password are required' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        if (!validateEmail(email)) {
            console.error('Email validation failed locally:', email);
            return new Response(JSON.stringify({ error: 'Invalid email format' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        // Create Supabase auth user
        const { data: newAuthUser, error: createErr } = await adminClient.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: { name, role: 'admin' },
        });

        if (createErr || !newAuthUser.user) {
            console.error('Supabase Auth User Creation Error:', createErr);
            return new Response(JSON.stringify({ error: createErr?.message ?? 'Failed to create user' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }

        const newUserId = newAuthUser.user.id;

        // Triggers handle the basic public.users insert, we update the role
        const { error: patchError } = await adminClient.from('users').update({
            role: 'admin',
            name,
            phone: phone ?? null,
        }).eq('id', newUserId);

        if (patchError) console.error('Error patching user role:', patchError);

        // Insert admin_permissions
        const { error: permError } = await adminClient.from('admin_permissions').upsert({
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

        if (permError) console.error('Error setting admin permissions:', permError);

        // Log the action
        await adminClient.from('admin_activity_logs').insert({
            admin_id: user.id,
            admin_name: 'Super Admin',
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
        console.error('Unexpected function error:', err);
        return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
});
