import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, Authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 6. Inside the Edge Function read the Authorization header:
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "User not authenticated", details: "Missing Authorization header" }),
        { 
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const token = authHeader.replace('Bearer ', '')
    
    // 3. Inside the Edge Function initialize Supabase using the Authorization header:
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') || '',
      Deno.env.get('SUPABASE_ANON_KEY') || '',
      {
        global: {
          headers: {
            Authorization: authHeader
          }
        }
      }
    )

    // 7. Verify the user:
    // Passing the token directly to getUser is more robust in Edge Functions
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "User not authenticated", details: authError?.message || "Invalid or expired session" }),
        { 
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Initialize Admin Client for DB operations
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') || '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SERVICE_ROLE_KEY') || ''
    )

    // 5. After verifying the user, check the role in public.users table and allow only admin or super_admin.
    const { data: userProfile, error: profileError } = await supabaseAdmin
      .from('users')
      .select('role')
      .eq('id', user.id)
      .single()

    if (profileError || !userProfile || !['admin', 'super_admin'].includes(userProfile.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden', message: 'Admin access required' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 6. Do not modify the prize calculation logic — only fix authentication.
    const { tournament_id } = await req.json()
    console.log(`Starting prize distribution for tournament: ${tournament_id}`)

    const { data: tournament, error: tournamentError } = await supabaseAdmin
      .from('tournaments')
      .select('per_kill_reward, rank_prizes, status, title, prize_type, commission_percentage, rank_percentages, entry_fee, joined_slots')
      .eq('id', tournament_id)
      .single()

    if (tournamentError || !tournament) {
      console.error(`Tournament not found: ${tournament_id}`, tournamentError)
      return new Response(JSON.stringify({ error: 'Tournament not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }
    
    // Allow distribution even if completed to support RE-DISTRIBUTE PRIZES fixes
    if (tournament.status === 'completed') {
      console.log(`Tournament ${tournament_id} is completed. Processing distribution/payout check.`)
    }

    const prizeType = tournament.prize_type || 'fixed'
    const rankPrizes = tournament.rank_prizes || {}
    const rankPercentages = tournament.rank_percentages || {}
    const commission = tournament.commission_percentage || 10
    const entryFee = tournament.entry_fee || 0
    const totalJoined = tournament.joined_slots || 0

    console.log(`Tournament Info: Type=${prizeType}, Joined=${totalJoined}, Fee=${entryFee}`)

    let dynamicPool = 0
    if (prizeType === 'dynamic') {
      dynamicPool = totalJoined * entryFee * (1 - commission / 100)
      console.log(`Dynamic Pool Calculated: ${dynamicPool}`)
    }

    const { data: results, error: resultsError } = await supabaseAdmin
      .from('joined_teams')
      .select('id, user_id, rank, kills, is_prize_distributed, total_prize, users(name)')
      .eq('tournament_id', tournament_id)

    if (resultsError || !results || results.length === 0) {
      console.error(`No participants found for tournament ${tournament_id}`, resultsError)
      return new Response(JSON.stringify({ error: 'No participants found' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log(`Found ${results.length} participants to process.`)

    const winnersSummary = []

    for (const res of results) {
      const { id: team_id, user_id, rank, kills, is_prize_distributed: alreadyDistributed } = res

      if (rank === null || kills === null) {
        console.log(`Skipping team ${team_id} (User: ${user_id}) as rank/kills are not set.`)
        continue;
      }

      // 5. Use the prize already saved in the database (admin's manual/auto-filled result)
      // This ensures what the admin sees in the table is exactly what gets paid.
      // We also check team.total_prize (aliased from dbPrize)
      const totalPrize = Number(res.total_prize || 0);
      // alreadyDistributed is already defined above from res

      console.log(`Processing User ${user_id}: Rank=${rank}, Kills=${kills}, DB_Prize=₹${totalPrize}, AlreadyDistributed=${alreadyDistributed}`)

      if (totalPrize <= 0) {
        console.log(`User ${user_id} has ₹0 prize. Setting distributed flag and skipping payment.`)
        if (!alreadyDistributed) {
          await supabaseAdmin.from('joined_teams').update({ is_prize_distributed: true }).eq('id', team_id)
        }
        continue;
      }

      // PREVENTION: Check if we ALREADY paid this user for this tournament
      // This is a safety layer even if the distributed flag is somehow bypassed
      const { data: existingTx } = await supabaseAdmin
        .from('wallet_transactions')
        .select('id')
        .eq('user_id', user_id)
        .eq('reference_id', tournament_id)
        .eq('type', 'tournament_win')
        .maybeSingle()

      if (existingTx) {
          console.warn(`User ${user_id} already has a 'tournament_win' transaction for this tournament. Skipping to prevent double-payment.`)
          if (!alreadyDistributed) {
             await supabaseAdmin.from('joined_teams').update({ is_prize_distributed: true }).eq('id', team_id)
          }
          continue;
      }

      // Process the actual payout using atomic RPC
      const { error: rpcError } = await supabaseAdmin.rpc('process_tournament_payout', {
        p_user_id: user_id,
        p_tournament_id: tournament_id,
        p_amount: totalPrize,
        p_rank: rank,
        p_kills: kills,
        p_tournament_title: tournament.title
      })
      
      if (rpcError) {
        console.error(`CRITICAL: Failed atomic payout for user ${user_id}:`, rpcError)
        return new Response(JSON.stringify({ 
          error: 'Payout Failed', 
          message: `Could not process payout for user ${user_id}. Ensure SQL migration is run.`,
          details: rpcError.message 
        }), { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        })
      }

      // Success Path: Update the team record
      await supabaseAdmin.from('joined_teams').update({
        is_prize_distributed: true,
        total_prize: totalPrize
      }).eq('id', team_id)

      // Fetch updated wallet balance & stats for summary
      const { data: walletData } = await supabaseAdmin
        .from('user_wallets')
        .select('winning_wallet')
        .eq('user_id', user_id)
        .single()

      winnersSummary.push({
        user_id,
        name: (res.users as any)?.name || 'User',
        rank,
        kills,
        prize_amount: totalPrize,
        updated_balance: walletData?.winning_wallet || 0
      })

      // Notify user
      try {
        await supabaseAdmin.functions.invoke('send_notification', {
          body: {
            user_id: user_id,
            title: 'Tournament Winnings Credited!',
            body: `You won ₹${totalPrize} from Rank: ${rank} in "${tournament.title}". Check your wallet and stats!`,
            type: 'tournament_win',
            related_id: tournament_id
          }
        })
      } catch (e) {
        console.error(`Notification failed for user ${user_id}:`, e.message)
      }
    }

    // Mark tournament as completed
    await supabaseAdmin.from('tournaments')
      .update({ status: 'completed' })
      .eq('id', tournament_id)

    // Log action
    await supabaseAdmin.from('admin_activity_logs').insert({
      admin_id: user.id,
      admin_name: userProfile.name || user.email,
      action: 'distribute_prizes',
      target_type: 'tournament',
      target_id: tournament_id,
      details: { title: tournament.title, winners_count: winnersSummary.length }
    })

    return new Response(JSON.stringify({ 
      success: true, 
      message: 'Prizes distributed successfully',
      tournament_id,
      winners: winnersSummary 
    }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { 
      status: 500, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    })
  }
})
