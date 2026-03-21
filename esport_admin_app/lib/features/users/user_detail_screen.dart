import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'fair_play_score_logs_screen.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _referrer;
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _referredUsers = [];
  List<Map<String, dynamic>> _supportTickets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = await _supabase.from('users').select().eq('id', widget.userId).maybeSingle();
      final wallet = await _supabase.from('user_wallets').select().eq('user_id', widget.userId).maybeSingle();
      
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final matches = await _supabase
          .from('joined_teams')
          .select('*, tournaments(title, games(name))')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
          
      final transactions = await _supabase
          .from('wallet_transactions')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      // Fetch referral data
      Map<String, dynamic>? referredBy;
      if (user['referred_by'] != null) {
        try {
          referredBy = await _supabase.from('users').select('id, username').eq('referral_code', user['referred_by']).maybeSingle();
        } catch (e) {
          debugPrint('Failed to fetch referrer: $e');
        }
      }

      final referrals = await _supabase
          .from('users')
          .select('id, username, created_at')
          .eq('referred_by', user['referral_code'])
          .order('created_at', ascending: false);

      final supportTickets = await _supabase
          .from('support_tickets')
          .select()
          .eq('user_id', widget.userId)
          .order('updated_at', ascending: false);

      if (mounted) {
        setState(() {
          _user = user;
          _wallet = wallet;
          _referrer = referredBy;
          _matches = List<Map<String, dynamic>>.from(matches);
          _transactions = List<Map<String, dynamic>>.from(transactions);
          _referredUsers = List<Map<String, dynamic>>.from(referrals);
          _supportTickets = List<Map<String, dynamic>>.from(supportTickets);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(bool block) async {
    try {
      await _supabase.from('users').update({'is_blocked': block}).eq('id', widget.userId);
      StitchSnackbar.showSuccess(context, block ? 'User blocked' : 'User unblocked');
      _fetchData();
    } catch (e) {
      StitchSnackbar.showError(context, 'Failed to update status');
    }
  }

  void _showAdjustBalance(String walletType) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isAdd = true;

    StitchDialog.show(
      context: context,
      title: 'Adjust ${walletType.toUpperCase()} Wallet',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Add'),
                      selected: isAdd,
                      onSelected: (v) => setDialogState(() => isAdd = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Deduct'),
                      selected: !isAdd,
                      onSelected: (v) => setDialogState(() => isAdd = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StitchInput(label: 'Amount (₹)', controller: amountCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              StitchInput(label: 'Reason (Optional)', controller: reasonCtrl),
            ],
          );
        },
      ),
      primaryButtonText: 'Submit',
      onPrimaryPressed: () async {
        final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
        if (amount <= 0) return;

        try {
          final finalAmount = isAdd ? amount : -amount;
          
          // Create transaction
          await _supabase.from('wallet_transactions').insert({
            'user_id': widget.userId,
            'amount': amount,
            'type': isAdd ? 'deposit' : 'withdraw', // Using standard types allowed by constraint
            'wallet_type': walletType,
            'status': 'completed',
            'reference_id': 'Admin: ${reasonCtrl.text.trim()}',
          });

          // Update wallet
          final current = _wallet!['${walletType}_wallet'];
          await _supabase.from('user_wallets').update({
            '${walletType}_wallet': (current + finalAmount).toDouble(),
          }).eq('user_id', widget.userId);

          if (mounted) {
            context.pop();
            StitchSnackbar.showSuccess(context, 'Balance adjusted');
            _fetchData();
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Failed to adjust balance');
        }
      },
    );
  }
  Future<void> _initializeWallet() async {
    try {
      await _supabase.from('user_wallets').insert({'user_id': widget.userId});
      StitchSnackbar.showSuccess(context, 'Wallet initialized');
      _fetchData();
    } catch (e) {
      StitchSnackbar.showError(context, 'Failed to initialize wallet');
    }
  }
  void _showSendNotification() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    bool isSending = false;

    StitchDialog.show(
      context: context,
      title: 'Send Notification',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Send a targeted notification to @${_user!['username'] ?? 'User'}', 
                style: const TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              StitchInput(label: 'Title', controller: titleCtrl, hintText: 'e.g. Account Update'),
              const SizedBox(height: 12),
              StitchInput(label: 'Message', controller: bodyCtrl, hintText: 'e.g. Your balance has been adjusted...', maxLines: 3),
            ],
          );
        },
      ),
      primaryButtonText: 'Send now',
      onPrimaryPressed: () async {
        final title = titleCtrl.text.trim();
        final body = bodyCtrl.text.trim();
        if (title.isEmpty || body.isEmpty) return;

        try {
          final payload = {
            'user_id': widget.userId,
            'title': title,
            'body': body,
            'type': 'admin_push',
            'is_broadcast': false,
          };

          await _supabase.functions.invoke(
            'send_notification',
            body: payload,
            headers: {
              'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken ?? ''}',
              'apikey': SupabaseConfig.anonKey,
            },
          );
          
          if (mounted) {
            context.pop();
            StitchSnackbar.showSuccess(context, 'Notification sent to @${_user!['username']}');
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Failed to send notification');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: StitchLoading());
    if (_user == null) return const Scaffold(body: StitchError(message: 'User not found'));

    int matchesPlayed = _matches.length;
    int wins = 0;
    int totalKills = 0;

    for (var match in _matches) {
      if (match['rank'] == 1) wins++;
      totalKills += (match['kills'] as num?)?.toInt() ?? 0;
    }

    final winRate = matchesPlayed > 0 ? (wins / matchesPlayed * 100).toStringAsFixed(1) : '0';

    return Scaffold(
      appBar: AppBar(
        title: Text(_user!['username'] ?? 'User Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: _showSendNotification,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Profile Info & Actions
            _buildProfileCard(),
            
            // 2. Wallets
            _buildWalletCard(),
            
            // 3. Stats
            _buildStatsCard(matchesPlayed, wins, totalKills, winRate),
            
            // 4. History Tabs
            Container(
              color: StitchTheme.surface,
              child: TabBar(
                controller: _tabController,
                indicatorColor: StitchTheme.primary,
                tabs: const [
                  Tab(text: 'Tournaments'),
                  Tab(text: 'Transactions'),
                  Tab(text: 'Referrals'),
                  Tab(text: 'Support'),
                ],
              ),
            ),
            SizedBox(
              height: 400,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _TournamentHistoryList(matches: _matches),
                  _TransactionHistoryList(transactions: _transactions),
                  _ReferralHistoryList(referrals: _referredUsers, referrer: _referrer),
                  _SupportTicketHistoryList(tickets: _supportTickets),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final isBlocked = _user!['is_blocked'] ?? false;
    return StitchCard(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              StitchAvatar(
                radius: 40,
                name: _user!['name'] ?? _user!['username'] ?? 'User',
                avatarUrl: _user!['avatar_url'],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_user!['name'] ?? 'User Name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                    Text('@${_user!['username']}', style: const TextStyle(color: StitchTheme.primary)),
                    Text(_user!['email'] ?? '', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
                    if (_user!['phone'] != null && _user!['phone'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(_user!['phone'], style: const TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
                      ),
                    const SizedBox(height: 8),
                    _buildFairScoreSection(),
                  ],
                ),
              ),
            ],
          ),
          if (_user!['bio'] != null && _user!['bio'].toString().isNotEmpty) ...[
            const Divider(height: 32, color: StitchTheme.surfaceHighlight),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BIO', style: TextStyle(fontSize: 10, color: StitchTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(_user!['bio'], style: const TextStyle(fontSize: 13, color: StitchTheme.textMain)),
                ],
              ),
            ),
          ],
          if (_user!['social_links'] != null && (_user!['social_links'] as Map).isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SOCIALS', style: TextStyle(fontSize: 10, color: StitchTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: [
                      if (_user!['social_links']['instagram']?.toString().isNotEmpty == true)
                        _buildSocialChip(Icons.camera_alt_outlined, 'Instagram', _user!['social_links']['instagram']),
                      if (_user!['social_links']['discord']?.toString().isNotEmpty == true)
                        _buildSocialChip(Icons.discord_outlined, 'Discord', _user!['social_links']['discord']),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 32, color: StitchTheme.surfaceHighlight),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: isBlocked ? Icons.lock_open : Icons.block,
                label: isBlocked ? 'Unblock' : 'Block',
                color: isBlocked ? Colors.green : Colors.red,
                onTap: () => _updateStatus(!isBlocked),
              ),
              _buildActionButton(
                icon: Icons.refresh,
                label: 'Reset Wallet',
                color: Colors.orange,
                onTap: () => _showResetConfirm(),
              ),
              _buildActionButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: Colors.red,
                onTap: () => StitchSnackbar.showInfo(context, 'Delete coming soon'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    if (_wallet == null) {
      return StitchCard(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet data missing', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('This user cannot join tournaments.', style: TextStyle(color: StitchTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _initializeWallet,
                child: const Text('INITIALIZE', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
    return StitchCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wallet Information', style: TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMuted)),
          const SizedBox(height: 16),
          _buildWalletRow('Deposit', _wallet?['deposit_wallet'] ?? 0, 'deposit'),
          const SizedBox(height: 12),
          _buildWalletRow('Winning', _wallet?['winning_wallet'] ?? 0, 'winning'),
        ],
      ),
    );
  }

  Widget _buildWalletRow(String label, num balance, String type) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
            Text('₹$balance', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: () => _showAdjustBalance(type),
          child: const Text('Adjust', style: TextStyle(color: StitchTheme.primary)),
        ),
      ],
    );
  }

  Widget _buildStatsCard(int played, int wins, int totalKills, String winRate) {
    return StitchCard(
      margin: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Matches', played.toString()),
          _buildStatItem('Wins', wins.toString()),
          _buildStatItem('Kills', totalKills.toString()),
          _buildStatItem('Win Rate', '$winRate%'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
        Text(label, style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSocialChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: StitchTheme.surfaceHighlight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: StitchTheme.primary),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFairScoreSection() {
    final int score = (_user!['fair_score'] as num?)?.toInt() ?? 100;
    Color scoreColor;
    String label;
    if (score >= 90) {
      scoreColor = Colors.greenAccent;
      label = 'TRUSTED';
    } else if (score >= 70) {
      scoreColor = Colors.orangeAccent;
      label = 'RISK';
    } else {
      scoreColor = Colors.redAccent;
      label = 'DANGEROUS';
    }

    return GestureDetector(
      onTap: () => context.push('/user_fair_play_logs/${widget.userId}?username=${_user!['username']}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scoreColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scoreColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: scoreColor, size: 14),
            const SizedBox(width: 6),
            Text(
              '$label: $score',
              style: TextStyle(color: scoreColor, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
            ),
            const SizedBox(width: 4),
            Icon(Icons.history_rounded, color: scoreColor.withOpacity(0.5), size: 12),
          ],
        ),
      ),
    );
  }

  void _showResetConfirm() {
    StitchDialog.show(
      context: context,
      title: 'Reset Wallet',
      content: const Text('Are you sure you want to reset both wallets to ₹0? This action cannot be undone.'),
      primaryButtonText: 'Reset',
      onPrimaryPressed: () async {
        try {
          await _supabase.from('user_wallets').update({'deposit_wallet': 0, 'winning_wallet': 0}).eq('user_id', widget.userId);
          if (mounted) {
            context.pop();
            StitchSnackbar.showSuccess(context, 'Wallet reset');
            _fetchData();
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Failed to reset');
        }
      },
    );
  }
}

class _TournamentHistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> matches;
  const _TournamentHistoryList({required this.matches});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const Center(child: Text('No tournaments joined', style: TextStyle(color: StitchTheme.textMuted)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final m = matches[index];
        final t = m['tournaments'];
        return StitchCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t['title'], style: const TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
              Text(t['games']['name'], style: const TextStyle(color: StitchTheme.primary, fontSize: 12)),
              const Divider(color: StitchTheme.surfaceHighlight),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _smallStat('Rank', m['rank']?.toString() ?? '-'),
                  _smallStat('Kills', m['kills']?.toString() ?? '0'),
                  _smallStat('Prize', '₹${m['total_prize'] ?? 0}'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _smallStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: StitchTheme.textMuted)),
      ],
    );
  }
}

class _TransactionHistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  const _TransactionHistoryList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const Center(child: Text('No transactions found', style: TextStyle(color: StitchTheme.textMuted)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isNegative = ['tournament_entry', 'withdraw', 'admin_penalty'].contains(tx['type']);
        return StitchCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: (isNegative ? Colors.red : Colors.green).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(isNegative ? Icons.remove : Icons.add, color: isNegative ? Colors.red : Colors.green, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx['type'].toString().replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    if (tx['reference_id'] != null) Text(tx['reference_id'], style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted), maxLines: 1),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${isNegative ? '-' : '+'}₹${tx['amount']}', style: TextStyle(color: isNegative ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                  Text(DateFormat('dd MMM, HH:mm').format(DateTime.parse(tx['created_at'])), style: const TextStyle(fontSize: 10, color: StitchTheme.textMuted)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReferralHistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> referrals;
  final Map<String, dynamic>? referrer;
  const _ReferralHistoryList({required this.referrals, this.referrer});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (referrer != null) ...[
            const Text('REFERRED BY', style: TextStyle(fontSize: 10, color: StitchTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => context.push('/user_detail/${referrer!['id']}'),
              child: StitchCard(
                child: Row(
                  children: [
                    const Icon(Icons.person_pin, color: StitchTheme.primary),
                    const SizedBox(width: 12),
                    Text(referrer!['username'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.primary)),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: StitchTheme.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          Text('REFERRALS (${referrals.length})', style: const TextStyle(fontSize: 10, color: StitchTheme.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (referrals.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('No referrals yet', style: TextStyle(color: StitchTheme.textMuted)),
            ))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: referrals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ref = referrals[index];
                return GestureDetector(
                  onTap: () => context.push('/user_detail/${ref['id']}'),
                  child: StitchCard(
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: StitchTheme.textMuted),
                        const SizedBox(width: 12),
                        Text(ref['username'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(
                          DateFormat('dd MMM yyyy').format(DateTime.parse(ref['created_at'])),
                          style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, size: 16, color: StitchTheme.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SupportTicketHistoryList extends StatelessWidget {
  final List<Map<String, dynamic>> tickets;
  const _SupportTicketHistoryList({required this.tickets});

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) return const Center(child: Text('No support tickets', style: TextStyle(color: StitchTheme.textMuted)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final t = tickets[index];
        final status = t['status'] ?? 'open';
        
        Color statusColor;
        switch (status) {
          case 'open': statusColor = StitchTheme.secondary; break;
          case 'in_progress': statusColor = StitchTheme.warning; break;
          case 'resolved': statusColor = StitchTheme.success; break;
          case 'closed': statusColor = StitchTheme.textMuted; break;
          default: statusColor = StitchTheme.primary;
        }

        return StitchCard(
          onTap: () => context.push('/admin_ticket/${t['id']}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(t['subject'] ?? 'No Subject', style: const TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMain))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Updated ${DateFormat('MMM dd, HH:mm').format(DateTime.parse(t['updated_at']).toLocal())}',
                style: const TextStyle(fontSize: 10, color: StitchTheme.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}
