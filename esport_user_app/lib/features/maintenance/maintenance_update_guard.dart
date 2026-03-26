import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'maintenance_screen.dart';
import 'update_required_screen.dart';
import 'package:esport_core/esport_core.dart';

class MaintenanceUpdateGuard extends StatefulWidget {
  final Widget child;

  const MaintenanceUpdateGuard({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<MaintenanceUpdateGuard> createState() => _MaintenanceUpdateGuardState();
}

class _MaintenanceUpdateGuardState extends State<MaintenanceUpdateGuard> {
  final _supabase = Supabase.instance.client;
  String? _currentVersion;

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _currentVersion = info.version;
      });
    }
  }

  bool _isVersionOutdated(String latestVersion) {
    if (_currentVersion == null) return false;
    
    // Simple version comparison (e.g., 1.0.0 vs 1.0.1)
    try {
      final currentParts = _currentVersion!.split('.').map(int.parse).toList();
      final latestParts = latestVersion.split('.').map(int.parse).toList();

      for (var i = 0; i < latestParts.length; i++) {
        final latest = latestParts[i];
        final current = i < currentParts.length ? currentParts[i] : 0;
        
        if (latest > current) return true;
        if (latest < current) return false;
      }
    } catch (e) {
      // Fallback to simple string comparison if parsing fails
      return _currentVersion != latestVersion;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      // Listen to the first row of app_settings
      stream: _supabase.from('app_settings').stream(primaryKey: ['id']).limit(1),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // If error occurs, show the error for debugging. 
          // Note: In production, you might want a simpler fallback.
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text('Connection Error', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to connect to app settings. ${snapshot.error.toString().contains('column') ? 'Database migration might be missing.' : ''}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    StitchButton(
                      text: 'Retry',
                      onPressed: () {
                        // This will trigger a rebuild and retry the stream
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Scaffold(body: StitchLoading());
        }

        final settings = snapshot.data!.first;
        final isMaintenance = settings['is_maintenance_mode'] as bool? ?? false;
        final maintenanceMessage = settings['maintenance_message'] as String? ?? 'We are currently under maintenance.';
        final latestVersion = settings['user_app_version'] as String? ?? '1.0.0';
        final updateUrl = settings['user_app_update_url'] as String? ?? '';

        // 1. Check Maintenance Mode
        if (isMaintenance) {
          return MaintenanceScreen(message: maintenanceMessage);
        }

        // 2. Check App Update
        if (_isVersionOutdated(latestVersion)) {
          return UpdateRequiredScreen(
            latestVersion: latestVersion,
            updateUrl: updateUrl,
          );
        }

        // 3. All good, show the app
        return widget.child;
      },
    );
  }
}
