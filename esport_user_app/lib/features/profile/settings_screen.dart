import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  Future<void> _showChangePasswordDialog() async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StitchInput(
                label: 'New Password',
                controller: passController,
                isPassword: true,
              ),
              const SizedBox(height: 16),
              StitchInput(
                label: 'Confirm Password',
                controller: confirmController,
                isPassword: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final pass = passController.text.trim();
                if (pass != confirmController.text.trim()) {
                  StitchSnackbar.showError(context, 'Passwords do not match');
                  return;
                }
                if (pass.length < 6) {
                  StitchSnackbar.showError(context, 'Minimum 6 characters');
                  return;
                }

                setDialogState(() => isLoading = true);
                try {
                  await AuthService.updatePassword(pass);
                  // Log Activity
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user != null) {
                    await AuthService.logActivity(
                      userId: user.id,
                      type: 'password_change',
                      description: 'User changed password from settings',
                    );
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    StitchSnackbar.showSuccess(context, 'Password updated successfully');
                  }
                } catch (e) {
                  if (context.mounted) StitchSnackbar.showError(context, e.toString());
                } finally {
                  setDialogState(() => isLoading = false);
                }
              },
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('PREFERENCES', style: TextStyle(fontSize: 12, color: StitchTheme.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          StitchCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push Notifications', style: TextStyle(color: StitchTheme.textMain)),
                  subtitle: const Text('Get updates on new tournaments', style: TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
                  value: _notificationsEnabled,
                  activeColor: StitchTheme.primary,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                ),
                const Divider(height: 1, color: StitchTheme.surfaceHighlight),
                ListTile(
                  title: const Text('Language', style: TextStyle(color: StitchTheme.textMain)),
                  subtitle: const Text('English (United States)', style: TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: StitchTheme.textMuted),
                  onTap: () => StitchSnackbar.showInfo(context, 'Language options coming soon'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('ACCOUNT', style: TextStyle(fontSize: 12, color: StitchTheme.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          StitchCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Change Password', style: TextStyle(color: StitchTheme.textMain)),
                  subtitle: const Text('Update your security credentials', style: TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
                  trailing: const Icon(Icons.lock_outline, size: 18, color: StitchTheme.textMuted),
                  onTap: () => _showChangePasswordDialog(),
                ),
                const Divider(height: 1, color: StitchTheme.surfaceHighlight),
                ListTile(
                  title: const Text('Privacy Policy', style: TextStyle(color: StitchTheme.textMain)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: StitchTheme.textMuted),
                  onTap: () => context.push('/legal/privacy_policy'),
                ),
                const Divider(height: 1, color: StitchTheme.surfaceHighlight),
                ListTile(
                  title: const Text('Terms and Conditions', style: TextStyle(color: StitchTheme.textMain)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: StitchTheme.textMuted),
                  onTap: () => context.push('/legal/terms_and_conditions'),
                ),
                const Divider(height: 1, color: StitchTheme.surfaceHighlight),
                ListTile(
                  title: const Text('Refund Policy', style: TextStyle(color: StitchTheme.textMain)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: StitchTheme.textMuted),
                  onTap: () => context.push('/legal/refund_policy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'App Version 1.0.0',
              style: TextStyle(color: StitchTheme.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
