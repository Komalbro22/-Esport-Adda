import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isMoreLoading = false;
  bool _hasMore = true;
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, blocked
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  static const int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();
  
  // Debounce search
  final ValueNotifier<bool> _isFilteringNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchUsers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isMoreLoading && _hasMore) {
        _loadMoreUsers();
      }
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final data = await _supabase
          .from('users')
          .select('*, user_wallets(deposit_wallet, winning_wallet, total_kills, total_wins, matches_played)')
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);
      
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _applyFilters(); // Apply filters after fetch
          _hasMore = _users.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    _filteredUsers = _users.where((user) {
      final matchesSearch = _searchQuery.isEmpty || 
        (user['username']?.toString() ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (user['email']?.toString() ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (user['id']?.toString() ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesFilter = _filterStatus == 'all' || 
          (_filterStatus == 'active' && user['is_blocked'] == false) ||
          (_filterStatus == 'blocked' && user['is_blocked'] == true);
      
      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> _loadMoreUsers() async {
    if (_isMoreLoading || !_hasMore) return;
    setState(() => _isMoreLoading = true);
    try {
      final data = await _supabase
          .from('users')
          .select('*, user_wallets(deposit_wallet, winning_wallet, total_kills, total_wins, matches_played)')
          .order('created_at', ascending: false)
          .range(_users.length, _users.length + _pageSize - 1);
      
      if (mounted) {
        setState(() {
          final newUsers = List<Map<String, dynamic>>.from(data);
          _users.addAll(newUsers);
          _applyFilters(); // Apply filters after fetch
          _hasMore = newUsers.length == _pageSize;
          _isMoreLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isMoreLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading 
                ? const StitchLoading() 
                : _filteredUsers.isEmpty 
                    ? const Center(child: Text('No users found', style: TextStyle(color: StitchTheme.textMuted)))
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredUsers.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == _filteredUsers.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: StitchLoading()),
                            );
                          }
                          final user = _filteredUsers[index];
                          final wallet = user['user_wallets'];
                          final totalBalance = (wallet?['deposit_wallet'] ?? 0) + (wallet?['winning_wallet'] ?? 0);
                          
                          return StitchCard(
                            onTap: () => context.push('/user_detail/${user['id']}'),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: StitchTheme.surfaceHighlight,
                                  backgroundImage: user['avatar_url'] != null ? CachedNetworkImageProvider(user['avatar_url']) : null,
                                  child: user['avatar_url'] == null ? const Icon(Icons.person, color: StitchTheme.primary) : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user['username'] ?? 'No Username', style: const TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                                      Text(user['email'] ?? '', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          _buildBadge('₹$totalBalance', StitchTheme.success),
                                          const SizedBox(width: 8),
                                          _buildBadge('K: ${wallet?['total_kills'] ?? 0}', StitchTheme.primary),
                                          const SizedBox(width: 8),
                                          _buildBadge('W: ${wallet?['total_wins'] ?? 0}', StitchTheme.secondary),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildStatusChip(user['is_blocked'] ?? false),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('dd MMM').format(DateTime.parse(user['created_at'])),
                                      style: const TextStyle(fontSize: 10, color: StitchTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: StitchTheme.surface,
      child: Column(
        children: [
          TextField(
            onChanged: (v) {
              setState(() => _searchQuery = v);
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: 'Search by username, email or ID...',
              prefixIcon: const Icon(Icons.search, color: StitchTheme.textMuted),
              filled: true,
              fillColor: StitchTheme.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFilterChip('All', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Active', 'active'),
              const SizedBox(width: 8),
              _buildFilterChip('Blocked', 'blocked'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filterStatus = value);
        _applyFilters();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? StitchTheme.primary : StitchTheme.surfaceHighlight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : StitchTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return StitchBadge(text: text, color: color);
  }

  Widget _buildStatusChip(bool isBlocked) {
    return StitchBadge(
      text: isBlocked ? 'BLOCKED' : 'ACTIVE',
      color: isBlocked ? Colors.red : Colors.green,
    );
  }
}
