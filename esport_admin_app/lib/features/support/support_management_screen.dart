import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:intl/intl.dart';

class SupportManagementScreen extends StatefulWidget {
  const SupportManagementScreen({Key? key}) : super(key: key);

  @override
  State<SupportManagementScreen> createState() => _SupportManagementScreenState();
}

class _SupportManagementScreenState extends State<SupportManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tickets = [];
  String _filterStatus = 'open';

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      var query = _supabase
          .from('support_tickets')
          .select('*, users(username, email)');

      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }

      final data = await query.order('created_at', ascending: false);
      
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

  Future<void> _updateTicketStatus(String id, String status) async {
    try {
      await _supabase.from('support_tickets').update({'status': status}).eq('id', id);
      StitchSnackbar.showSuccess(context, 'Ticket marked as $status');
      _fetchTickets();
    } catch (e) {
      StitchSnackbar.showError(context, 'Failed to update ticket');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Management'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (val) {
              setState(() => _filterStatus = val);
              _fetchTickets();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Tickets')),
              const PopupMenuItem(value: 'open', child: Text('Open Tickets')),
              const PopupMenuItem(value: 'closed', child: Text('Closed Tickets')),
            ],
          ),
        ],
      ),
      body: _isLoading 
          ? const StitchLoading() 
          : RefreshIndicator(
              onRefresh: _fetchTickets,
              child: _tickets.isEmpty 
                  ? const Center(child: Text('No tickets found', style: TextStyle(color: StitchTheme.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ticket = _tickets[index];
                        final user = ticket['users'];
                        final isOpen = ticket['status'] == 'open';
                        
                        return StitchCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  StitchBadge(
                                    text: ticket['status'].toString(),
                                    color: isOpen ? Colors.orange : Colors.green,
                                  ),
                                  const Spacer(),
                                  Text(
                                    DateFormat('dd MMM, HH:mm').format(DateTime.parse(ticket['created_at'])),
                                    style: const TextStyle(fontSize: 12, color: StitchTheme.textMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                ticket['subject'],
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'From: ${user?['username'] ?? 'Unknown'} (${user?['email'] ?? ''})',
                                style: const TextStyle(color: StitchTheme.primary, fontSize: 13),
                              ),
                              const Divider(height: 24, color: StitchTheme.surfaceHighlight),
                              Text(
                                ticket['message'],
                                style: const TextStyle(color: StitchTheme.textMuted, fontSize: 14),
                              ),
                              if (isOpen) ...[
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: StitchButton(
                                        text: 'Close Ticket',
                                        isSecondary: true,
                                        onPressed: () => _updateTicketStatus(ticket['id'], 'closed'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: StitchButton(
                                        text: 'Respond',
                                        onPressed: () {
                                          StitchSnackbar.showInfo(context, 'Direct response feature coming soon');
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
