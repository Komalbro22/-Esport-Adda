import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SupportHomeScreen extends StatefulWidget {
  const SupportHomeScreen({Key? key}) : super(key: key);

  @override
  State<SupportHomeScreen> createState() => _SupportHomeScreenState();
}

class _SupportHomeScreenState extends State<SupportHomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final data = await _supabase
          .from('support_tickets')
          .select()
          .eq('user_id', userId!)
          .order('updated_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: RefreshIndicator(
        onRefresh: _fetchTickets,
        color: StitchTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildActionCards(),
              const SizedBox(height: 32),
              const Text('MY TICKETS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _isLoading 
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: StitchLoading()))
                  : _tickets.isEmpty 
                      ? _buildEmptyState()
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _tickets.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildTicketCard(_tickets[index]),
                        ),
              const SizedBox(height: 32),
              const Text('FREQUENTLY ASKED QUESTIONS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _buildFAQSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [StitchTheme.primary.withOpacity(0.2), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StitchTheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.headset_mic_rounded, size: 48, color: StitchTheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Need Help?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                const SizedBox(height: 4),
                Text('Our support team is available 24/7 to assist you.', style: TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            title: 'Create Ticket',
            subtitle: 'Start a new request',
            icon: Icons.add_comment_rounded,
            color: StitchTheme.primary,
            onTap: () => context.push('/create_ticket').then((_) => _fetchTickets()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            title: 'Telegram Support',
            subtitle: 'Quick response',
            icon: Icons.send_rounded,
            color: const Color(0xFF0088cc),
            onTap: () {
              // TODO: Add Telegram Link
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StitchTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: StitchTheme.textMain)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final status = ticket['status'] ?? 'open';
    final priority = ticket['priority'] ?? 'normal';
    final date = DateTime.parse(ticket['updated_at']).toLocal();
    
    Color statusColor;
    switch (status) {
      case 'open': statusColor = StitchTheme.secondary; break;
      case 'in_progress': statusColor = StitchTheme.warning; break;
      case 'resolved': statusColor = StitchTheme.success; break;
      case 'closed': statusColor = StitchTheme.textMuted; break;
      default: statusColor = StitchTheme.primary;
    }

    return StitchCard(
      onTap: () => context.push('/support_chat/${ticket['id']}').then((_) => _fetchTickets()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(ticket['subject'] ?? 'No Subject', 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StitchTheme.textMain)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(ticket['category'] ?? 'General', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(color: StitchTheme.textMuted)),
              const SizedBox(width: 8),
              Text(DateFormat('MMM dd, HH:mm').format(date), style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
              const Spacer(),
              if (priority == 'high')
                const Icon(Icons.priority_high_rounded, size: 14, color: StitchTheme.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: StitchTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: StitchTheme.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No tickets yet', style: TextStyle(color: StitchTheme.textMuted, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('If you have any issues, create a ticket.', textAlign: TextAlign.center, style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
    final faqs = [
      {'q': 'Withdrawal time?', 'a': 'Usually within 2-4 hours, max 24 hours.'},
      {'q': 'Account blocked?', 'a': 'Check rules. Contact us if you think it\'s a mistake.'},
      {'q': 'How to play?', 'a': 'Join a room using ID/Pass given 10 mins before start.'},
    ];

    return Column(
      children: faqs.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: StitchCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(f['q']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(f['a']!, style: const TextStyle(fontSize: 13, color: StitchTheme.textMuted)),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }
}
