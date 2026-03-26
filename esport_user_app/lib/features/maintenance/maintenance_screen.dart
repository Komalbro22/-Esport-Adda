import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';

class MaintenanceScreen extends StatelessWidget {
  final String message;

  const MaintenanceScreen({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.engineering_rounded,
              size: 100,
              color: StitchTheme.primary,
            ),
            const SizedBox(height: 32),
            const Text(
              'Under Maintenance',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: StitchTheme.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: StitchTheme.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            const Text(
              'Please check back soon!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: StitchTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
