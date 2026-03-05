import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

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
                  title: const Text('Theme Mode', style: TextStyle(color: StitchTheme.textMain)),
                  subtitle: const Text('Dark Mode (Default)', style: TextStyle(fontSize: 12, color: StitchTheme.textMuted)),
                  trailing: const Icon(Icons.brightness_4_outlined, size: 20, color: StitchTheme.primary),
                  onTap: () => StitchSnackbar.showInfo(context, 'Theme selection coming soon'),
                ),
                const Divider(height: 1, color: StitchTheme.surfaceHighlight),
                ListTile(
                  title: const Text('Privacy Policy', style: TextStyle(color: StitchTheme.textMain)),
                  trailing: const Icon(Icons.open_in_new, size: 18, color: StitchTheme.textMuted),
                  onTap: () {},
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
