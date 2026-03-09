-- RPC to fetch all admin dashboard metrics in a single call
CREATE OR REPLACE FUNCTION get_admin_metrics()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
    user_count int;
    tournament_count int;
    deposit_count int;
    withdraw_count int;
    ticket_count int;
BEGIN
    SELECT count(*) INTO user_count FROM users;
    SELECT count(*) INTO tournament_count FROM tournaments WHERE status IN ('upcoming', 'ongoing');
    SELECT count(*) INTO deposit_count FROM deposit_requests WHERE status = 'pending';
    SELECT count(*) INTO withdraw_count FROM withdraw_requests WHERE status = 'pending';
    SELECT count(*) INTO ticket_count FROM support_tickets WHERE status = 'open';

    result := json_build_object(
        'total_users', user_count,
        'active_tournaments', tournament_count,
        'pending_deposits', deposit_count,
        'pending_withdraws', withdraw_count,
        'open_tickets', ticket_count
    );

    RETURN result;
END;
$$;
