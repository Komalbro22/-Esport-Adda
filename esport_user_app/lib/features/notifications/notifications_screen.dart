import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;

  Future<void> _markAsRead(String id) async {
    await _supabase.from('notifications').update({'is_read': true}).eq('id', id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('notifications')
            .stream(primaryKey: ['id'])
            .eq('user_id', _supabase.auth.currentUser!.id)
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: StitchLoading());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading notifications', style: TextStyle(color: StitchTheme.error)));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No recent notifications.',
                style: TextStyle(color: StitchTheme.textMuted),
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final note = notifications[index];
              final isRead = note['is_read'] as bool? ?? false;
              final createdAt = DateTime.parse(note['created_at']).toLocal();
              final timeString = DateFormat('MMM d, h:mm a').format(createdAt);

              IconData iconData = Icons.notifications;
              Color iconColor = StitchTheme.primary;

              switch (note['type']) {
                case 'deposit_status':
                  iconData = Icons.account_balance_wallet;
                  iconColor = note['title'].toString().contains('Approved') ? StitchTheme.success : StitchTheme.error;
                  break;
                case 'withdraw_status':
                  iconData = Icons.money_off;
                  iconColor = note['title'].toString().contains('Approved') ? StitchTheme.success : StitchTheme.error;
                  break;
                case 'broadcast':
                  iconData = Icons.announcement;
                  iconColor = StitchTheme.warning;
                  break;
                case 'tournament':
                  iconData = Icons.sports_esports;
                  iconColor = StitchTheme.accent;
                  break;
              }

              return ListTile(
                onTap: () {
                  if (!isRead) _markAsRead(note['id']);
                },
                tileColor: isRead ? StitchTheme.surface : StitchTheme.surfaceHighlight.withOpacity(0.5),
                leading: CircleAvatar(
                  backgroundColor: StitchTheme.surfaceHighlight,
                  child: Icon(iconData, color: iconColor),
                ),
                title: Text(
                  note['title'] ?? 'Notification',
                  style: TextStyle(
                    color: StitchTheme.textMain,
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      note['body'] ?? '',
                      style: const TextStyle(color: StitchTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeString,
                      style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
