import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    final unreadIds = _notifications
        .where((n) => (n['is_read'] ?? false) == false)
        .map((n) => n['id'])
        .toList();

    if (unreadIds.isEmpty) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .inFilter('id', unreadIds);
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }

    await _fetchNotifications();
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'tournament':
        return Icons.emoji_events;
      case 'challenge':
        return Icons.videogame_asset;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'voucher':
        return Icons.confirmation_number;
      case 'fair_play':
        return Icons.gavel;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'admin_push':
        return Icons.admin_panel_settings_rounded;
      case 'shop_order':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            onPressed: _isLoading ? null : _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: StitchLoading())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final bool isRead = notification['is_read'] ?? false;
                      final DateTime createdAt = DateTime.parse(notification['created_at']);
                    final String message =
                        (notification['message'] ?? notification['body'] ?? '').toString();
                    final String type = (notification['type'] ?? 'admin_push').toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: StitchTheme.primary.withOpacity(0.1),
                          child: Icon(_getIconForType(type), color: StitchTheme.primary),
                          ),
                          title: Text(
                            notification['title'],
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                            Text(message),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd MMM, hh:mm a').format(createdAt),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                          onTap: () {
                          // Mark as read when user taps.
                          final id = notification['id'];
                          if (id != null && (notification['is_read'] ?? false) == false) {
                            _supabase.from('notifications').update({'is_read': true}).eq('id', id).then((_) {
                              _fetchNotifications();
                            }).catchError((e) {
                              debugPrint('Error marking notification as read: $e');
                            });
                          }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
