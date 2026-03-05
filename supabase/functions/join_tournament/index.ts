import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // Extract JWT token from header
  const token = authHeader.replace('Bearer ', '')

  // Create client with the anon key
  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? ''
  )

  const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token)

  if (authError || !user) {
    console.error('Auth Error:', authError?.message || 'User not found');
    return new Response(JSON.stringify({
      error: 'User not authenticated',
      details: authError?.message || 'User not found. Please log out and log in again.'
    }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  const { tournament_id, team_data } = await req.json()

  // Service role client for bypassing RLS
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SERVICE_ROLE_KEY') ?? ''
  )

  // 1. Fetch tournament details
  const { data: tournament, error: tourneyError } = await supabaseAdmin
    .from('tournaments')
    .select('entry_fee, status, joined_slots, total_slots')
    .eq('id', tournament_id)
    .single()

  if (tourneyError || !tournament) return new Response(JSON.stringify({ error: 'Tournament not found' }), {
    status: 404,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
  if (tournament.status !== 'upcoming') return new Response(JSON.stringify({ error: 'Tournament is not upcoming' }), {
    status: 400,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
  if (tournament.joined_slots >= tournament.total_slots) return new Response(JSON.stringify({ error: 'Tournament is full' }), {
    status: 400,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })

  // 1.5 Check if already joined
  const { data: existingEntry } = await supabaseAdmin
    .from('joined_teams')
    .select('id')
    .eq('tournament_id', tournament_id)
    .eq('user_id', user.id)
    .maybeSingle()

  if (existingEntry) {
    return new Response(JSON.stringify({ error: 'Tournament already joined' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }

  // 2. Fetch user wallet
  const { data: wallet, error: walletError } = await supabaseAdmin
    .from('user_wallets')
    .select('*')
    .eq('user_id', user.id)
    .single()

  if (walletError || !wallet) return new Response(JSON.stringify({ error: 'Wallet not found' }), {
    status: 404,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })

  const totalBalance = wallet.deposit_wallet + wallet.winning_wallet
  if (totalBalance < tournament.entry_fee) return new Response(JSON.stringify({ error: 'Wallet balance insufficient' }), {
    status: 400,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })

  // 3. Deduct from wallet
  let newDeposit = wallet.deposit_wallet
  let newWinning = wallet.winning_wallet
  let remainingFee = tournament.entry_fee

  if (newDeposit >= remainingFee) {
    newDeposit -= remainingFee
    remainingFee = 0
  } else {
    remainingFee -= newDeposit
    newDeposit = 0
    newWinning -= remainingFee
  }

  // 4. Update wallet
  const { error: updateWalletError } = await supabaseAdmin
    .from('user_wallets')
    .update({ deposit_wallet: newDeposit, winning_wallet: newWinning })
    .eq('user_id', user.id)

  if (updateWalletError) return new Response(JSON.stringify({ error: 'Failed to update wallet' }), {
    status: 500,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })

  // 5. Log transaction
  await supabaseAdmin.from('wallet_transactions').insert({
    user_id: user.id,
    amount: tournament.entry_fee,
    type: 'tournament_entry',
    wallet_type: 'deposit',
    status: 'completed',
    reference_id: tournament_id
  })

  // 6. Join tournament
  const { error: joinError } = await supabaseAdmin.from('joined_teams').insert({
    tournament_id: tournament_id,
    user_id: user.id,
    team_data: team_data || []
  })

  if (joinError) return new Response(JSON.stringify({ error: 'Failed to record entry' }), {
    status: 500,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })

  // 7. Increment slots
  await supabaseAdmin.rpc('increment_joined_slots', { tourney_id: tournament_id })

  return new Response(JSON.stringify({ success: true }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  })
})
