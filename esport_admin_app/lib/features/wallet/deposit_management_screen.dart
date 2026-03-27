import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DepositManagementScreen extends StatefulWidget {
  final bool isTab;
  const DepositManagementScreen({super.key, this.isTab = false});

  @override
  State<DepositManagementScreen> createState() => _DepositManagementScreenState();
}

class _DepositManagementScreenState extends State<DepositManagementScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  bool _isMoreLoading = false;
  bool _hasMore = true;
  static const int _pageSize = 15;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchRequests();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isMoreLoading && _hasMore) {
        _loadMoreRequests();
      }
    }
  }

  Future<void> _fetchRequests() async {
    try {
      final data = await _supabase
          .from('deposit_requests')
          .select('*, users(name, username)')
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);
      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(data);
          _hasMore = _requests.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreRequests() async {
    if (_isMoreLoading || !_hasMore) return;
    setState(() => _isMoreLoading = true);
    try {
      final data = await _supabase
          .from('deposit_requests')
          .select('*, users(name, username)')
          .order('created_at', ascending: false)
          .range(_requests.length, _requests.length + _pageSize - 1);
      if (mounted) {
        setState(() {
          final newItems = List<Map<String, dynamic>>.from(data);
          _requests.addAll(newItems);
          _hasMore = newItems.length == _pageSize;
          _isMoreLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isMoreLoading = false);
    }
  }

  Future<void> _handleRequest(Map<String, dynamic> req, String action) async {
    setState(() => _isLoading = true);
    try {
      final isApproved = action == 'approve';
      // Ensure session is fresh before call
      final sessionResponse = await _supabase.auth.refreshSession();
      final session = sessionResponse.session;

      if (session == null) {
        if (mounted) context.go('/login');
        throw Exception('Session expired. Please log in again.');
      }
      
      debugPrint('Calling approve_deposit with token length: ${session.accessToken.length}');

      final response = await _supabase.functions.invoke(
        'approve_deposit',
        body: {
          'request_id': req['id'],
          'approved': isApproved
        },
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': SupabaseConfig.anonKey,
        },
      );
      
      if (response.status == 200) {
        if (mounted) StitchSnackbar.showSuccess(context, isApproved ? 'Deposit approved' : 'Deposit rejected');
      } else {
        final err = response.data?['error'] ?? 'Action failed';
        throw Exception(err);
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, e.toString());
    } finally {
      _fetchRequests();
    }
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isTab ? null : AppBar(
        title: const Text('Deposit Requests'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _isLoading
          ? const Center(child: StitchLoading())
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              color: StitchTheme.primary,
              backgroundColor: StitchTheme.surface,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _requests.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == _requests.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: StitchLoading()),
                    );
                  }
                  final req = _requests[index];
                  final isPending = req['status'] == 'pending';
                  
                  return StitchCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(req['users']?['name'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: StitchTheme.textMain)),
                            Text('₹${req['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: StitchTheme.success)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('@${req['users']?['username']}', style: const TextStyle(color: StitchTheme.textMuted)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('MMM dd, HH:mm').format(DateTime.parse(req['created_at']).toLocal()), style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                            StitchBadge(
                              text: req['status'].toString(),
                              color: isPending ? StitchTheme.warning : (req['status'] == 'approved' ? StitchTheme.success : StitchTheme.error),
                            )
                          ],
                        ),
                        if (req['transaction_id'] != null && req['transaction_id'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: StitchTheme.surfaceHighlight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.tag_rounded, size: 14, color: StitchTheme.textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'TXN ID: ${req['transaction_id']}',
                                    style: const TextStyle(color: StitchTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16, color: StitchTheme.secondary),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: req['transaction_id'].toString()));
                                    StitchSnackbar.showSuccess(context, 'Transaction ID copied!');
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (req['screenshot_url'] != null) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _showImageDialog(req['screenshot_url']),
                            child: Container(
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(image: CachedNetworkImageProvider(req['screenshot_url']), fit: BoxFit.cover)
                              ),
                              child: const Center(child: Icon(Icons.zoom_in, color: Colors.white, size: 32)),
                            ),
                          )
                        ],
                        if (isPending) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: StitchButton(text: 'Reject', isSecondary: true, onPressed: () => _handleRequest(req, 'reject'))),
                              const SizedBox(width: 16),
                              Expanded(child: StitchButton(text: 'Approve', onPressed: () => _handleRequest(req, 'approve'))),
                            ],
                          )
                        ]
                      ],
                    )
                  );
                },
              ),
            ),
    );
  }
}
