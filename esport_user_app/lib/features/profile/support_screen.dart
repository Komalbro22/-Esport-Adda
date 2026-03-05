import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _supabase = Supabase.instance.client;
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitTicket() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      StitchSnackbar.showError(context, 'Please fill all fields');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase.from('support_tickets').insert({
        'user_id': userId,
        'subject': subject,
        'message': message,
      });

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Support ticket submitted successfully!');
        _subjectCtrl.clear();
        _messageCtrl.clear();
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to submit ticket');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Support')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How can we help you?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: StitchTheme.textMain),
            ),
            const SizedBox(height: 8),
            const Text(
              'Feel free to ask any question or report an issue. Our team will get back to you soon.',
              style: TextStyle(color: StitchTheme.textMuted),
            ),
            const SizedBox(height: 32),
            StitchInput(
              label: 'Subject',
              controller: _subjectCtrl,
              hintText: 'e.g., Payment Issue, Game Bug',
            ),
            const SizedBox(height: 20),
            StitchInput(
              label: 'Message',
              controller: _messageCtrl,
              hintText: 'Describe your issue in detail...',
              maxLines: 5,
            ),
            const SizedBox(height: 32),
            StitchButton(
              text: 'Submit Ticket',
              isLoading: _isSubmitting,
              onPressed: _submitTicket,
            ),
            const SizedBox(height: 48),
            const Text(
              'Common FAQs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain),
            ),
            const SizedBox(height: 16),
            _buildFAQItem('How to add money?', 'Go to Wallet tab and click Add Money.'),
            _buildFAQItem('What is Per Kill reward?', 'You earn this amount for every kill you get in the match.'),
            _buildFAQItem('How to join a match?', 'Select a game, pick a tournament, and click Join.'),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StitchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: const TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.primary)),
            const SizedBox(height: 4),
            Text(answer, style: const TextStyle(fontSize: 13, color: StitchTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
