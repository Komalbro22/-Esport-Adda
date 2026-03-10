import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class FairPlayScoreLogsScreen extends StatefulWidget {
  final String userId;
  final String? username;

  const FairPlayScoreLogsScreen({Key? key, required this.userId, this.username}) : super(key: key);

  @override
  State<FairPlayScoreLogsScreen> createState() => _FairPlayScoreLogsScreenState();
}

class _FairPlayScoreLogsScreenState extends State<FairPlayScoreLogsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    try {
      final data = await _supabase.from('fair_score_logs')
          .select('*')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data as List);
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
        title: Text('Fair Play Logs: ${widget.username ?? 'User'}'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchLogs,
            child: _logs.isEmpty 
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildLogCard(_logs[index]),
                ),
          ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final isPositive = log['change_amount'] > 0;
    return StitchCard(
      child: ListTile(
        leading: Icon(
          isPositive ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
          color: isPositive ? Colors.greenAccent : Colors.redAccent,
        ),
        title: Text(log['reason'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Changed at: ${DateFormat('MMM dd, HH:mm').format(DateTime.parse(log['created_at']))}', style: const TextStyle(fontSize: 10)),
        trailing: Text(
          '${isPositive ? '+' : ''}${log['change_amount']}',
          style: TextStyle(
            color: isPositive ? Colors.greenAccent : Colors.redAccent,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.white10),
          SizedBox(height: 16),
          Text('No score adjustments found', style: TextStyle(color: StitchTheme.textMuted)),
        ],
      ),
    );
  }
}
