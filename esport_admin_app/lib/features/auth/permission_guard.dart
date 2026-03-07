import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';

/// Wraps a child widget with a permission check.
/// If [allowed] is false, shows an "Access Denied" screen instead.
class PermissionGuard extends StatelessWidget {
  final bool allowed;
  final Widget child;

  const PermissionGuard({Key? key, required this.allowed, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (allowed) return child;
    return Scaffold(
      appBar: AppBar(title: const Text('Access Denied')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: StitchTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 48, color: StitchTheme.error),
            ),
            const SizedBox(height: 24),
            const Text(
              'Access Denied',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: StitchTheme.textMain),
            ),
            const SizedBox(height: 8),
            const Text(
              'You do not have permission to access this section.\nContact your super admin to get access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: StitchTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
