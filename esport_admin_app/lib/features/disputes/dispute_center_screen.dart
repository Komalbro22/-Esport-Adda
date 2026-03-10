import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DisputeCenterScreen extends StatefulWidget {
  const DisputeCenterScreen({Key? key}) : super(key: key);

  @override
  State<DisputeCenterScreen> createState() => _DisputeCenterScreenState();
}

class _DisputeCenterScreenState extends State<DisputeCenterScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _disputes = [];

  @override
  void initState() {
    super.initState();
    _fetchDisputes();
  }

  Future<void> _fetchDisputes() async {
    try {
      final data = await _supabase.from('challenges')
          .select('*, creator:users!creator_id(username), opponent:users!opponent_id(username), games(name)')
          .eq('status', 'dispute')
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _disputes = List<Map<String, dynamic>>.from(data as List);
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
        title: const Text('Dispute Center'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDisputes,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _disputes.isEmpty 
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _disputes.length,
                itemBuilder: (context, index) => _buildDisputeCard(_disputes[index]),
              ),
      ),
    );
  }

  Widget _buildDisputeCard(Map<String, dynamic> d) {
    return StitchCard(
      onTap: () async {
        final result = await context.push('/dispute_detail/${d['id']}');
        if (result == true) _fetchDisputes();
      },
      child: ListTile(
        title: Text('${d['creator']['username']} vs ${d['opponent']['username']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Game: ${d['games']['name']} | Fee: ₹${d['entry_fee']}'),
            Text('Created: ${DateFormat('MMM dd, HH:mm').format(DateTime.parse(d['created_at']))}', style: const TextStyle(fontSize: 10)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.orangeAccent),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gavel_rounded, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          const Text('No disputed matches found', style: TextStyle(color: StitchTheme.textMuted)),
        ],
      ),
    );
  }
}
