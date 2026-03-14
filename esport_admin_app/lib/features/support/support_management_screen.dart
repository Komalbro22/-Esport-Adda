import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SupportManagementScreen extends StatefulWidget {
  const SupportManagementScreen({Key? key}) : super(key: key);

  @override
  State<SupportManagementScreen> createState() => _SupportManagementScreenState();
}

class _SupportManagementScreenState extends State<SupportManagementScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
       if (_tabController.indexIsChanging) _fetchTickets();
    });
    _fetchTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentStatus {
    switch (_tabController.index) {
      case 0: return 'open';
      case 1: return 'in_progress';
      case 2: return 'resolved';
      case 3: return 'closed';
      default: return 'open';
    }
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('support_tickets')
          .select('*, users(name, username, avatar_url)')
          .eq('status', _currentStatus)
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
      appBar: AppBar(
        title: const Text('Support Desk'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        bottom: TabBar(
          controller: _tabController,
          labelColor: StitchTheme.primary,
          unselectedLabelColor: StitchTheme.textMuted,
          indicatorColor: StitchTheme.primary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'OPEN'),
            Tab(text: 'IN PROGRESS'),
            Tab(text: 'RESOLVED'),
            Tab(text: 'CLOSED'),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: StitchLoading()) 
          : RefreshIndicator(
              onRefresh: _fetchTickets,
              color: StitchTheme.primary,
              child: _tickets.isEmpty 
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildTicketCard(_tickets[index]),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView( // ListView for RefreshIndicator to work
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Icon(Icons.support_agent_rounded, size: 64, color: StitchTheme.textMuted.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text('No $_currentStatus tickets', style: const TextStyle(color: StitchTheme.textMuted, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final user = ticket['users'];
    final priority = ticket['priority'] ?? 'normal';
    final date = DateTime.parse(ticket['updated_at']).toLocal();
    
    Color priorityColor;
    switch (priority) {
      case 'high': priorityColor = Colors.red; break;
      case 'normal': priorityColor = Colors.orange; break;
      case 'low': priorityColor = Colors.blue; break;
      default: priorityColor = Colors.grey;
    }

    return StitchCard(
      onTap: () => context.push('/admin_ticket/${ticket['id']}').then((_) => _fetchTickets()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StitchAvatar(
                radius: 20,
                name: user?['name'] ?? 'P',
                avatarUrl: user?['avatar_url'],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?['name'] ?? user?['username'] ?? 'Unknown', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(ticket['category'] ?? 'General', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: priorityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: priorityColor.withOpacity(0.3))),
                child: Text(priority.toUpperCase(), style: TextStyle(color: priorityColor, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(ticket['subject'] ?? 'No Subject', style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Updated ${DateFormat('MMM dd, HH:mm').format(date)}',
                style: const TextStyle(fontSize: 11, color: StitchTheme.textMuted),
              ),
              const Icon(Icons.chevron_right_rounded, color: StitchTheme.textMuted, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
