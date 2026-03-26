import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final String latestVersion;
  final String updateUrl;

  const UpdateRequiredScreen({
    Key? key,
    required this.latestVersion,
    required this.updateUrl,
  }) : super(key: key);

  Future<void> _launchUpdateUrl(BuildContext context) async {
    final uri = Uri.parse(updateUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        StitchSnackbar.showError(context, 'Could not launch download link');
      }
    }
  }

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
              Icons.update_rounded,
              size: 100,
              color: StitchTheme.primary,
            ),
            const SizedBox(height: 32),
            const Text(
              'Update Required',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: StitchTheme.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'A new version ($latestVersion) is available with exciting new features and improvements. Please update to continue.',
              style: const TextStyle(
                fontSize: 16,
                color: StitchTheme.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: StitchButton(
                text: 'Update Now',
                onPressed: () => _launchUpdateUrl(context),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Stay ahead of the game!',
              style: TextStyle(
                fontSize: 12,
                color: StitchTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
