import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({Key? key}) : super(key: key);

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _supabase = Supabase.instance.client;
  
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  
  bool _isSending = false;
  String _targetType = 'broadcast'; // 'broadcast', 'tournament', 'user'
  
  // Dropdowns data
  List<Map<String, dynamic>> _tournaments = [];
  String? _selectedTournamentId;

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  Future<void> _fetchTournaments() async {
    final response = await _supabase.from('tournaments')
      .select('id, title')
      .inFilter('status', ['upcoming', 'ongoing'])
      .order('created_at');
    
    if (mounted) {
      setState(() {
         _tournaments = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      StitchSnackbar.showError(context, 'Title and Message are required');
      return;
    }

    if (_targetType == 'tournament' && _selectedTournamentId == null) {
      StitchSnackbar.showError(context, 'Please select a tournament');
      return;
    }

    setState(() => _isSending = true);

    try {
      final payload = {
         'title': title,
         'body': body,
         'is_broadcast': _targetType == 'broadcast',
         'tournament_id': _targetType == 'tournament' ? _selectedTournamentId : null,
         'type': 'admin_push'
      };

      await _supabase.functions.invoke(
        'send_notification',
        body: payload,
        headers: {
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken ?? ''}',
          'apikey': SupabaseConfig.anonKey,
        },
      );

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Notification sent successfully');
        _titleController.clear();
        _bodyController.clear();
      }
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to send: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Notification', style: TextStyle(color: StitchTheme.primary, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StitchCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Target Audience', style: TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'broadcast', label: Text('All Users'), icon: Icon(Icons.public)),
                      ButtonSegment(value: 'tournament', label: Text('By Tournament'), icon: Icon(Icons.emoji_events)),
                    ],
                    selected: {_targetType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                         _targetType = newSelection.first;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                        return states.contains(MaterialState.selected) ? StitchTheme.primary : StitchTheme.surfaceHighlight;
                      }),
                      foregroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
                        return states.contains(MaterialState.selected) ? StitchTheme.surface : StitchTheme.textMuted;
                      }),
                    ),
                  ),
                  
                  if (_targetType == 'tournament') ...[
                    const SizedBox(height: 16),
                    const Text('Select Tournament', style: TextStyle(fontWeight: FontWeight.w600, color: StitchTheme.textMain)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: StitchTheme.surfaceHighlight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedTournamentId,
                          hint: const Text('Choose a tournament...', style: TextStyle(color: StitchTheme.textMuted)),
                          dropdownColor: StitchTheme.surfaceHighlight,
                          style: const TextStyle(color: StitchTheme.textMain),
                          items: _tournaments.map((t) {
                            return DropdownMenuItem<String>(
                              value: t['id'],
                              child: Text(t['title']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedTournamentId = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            StitchCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Message Details', style: TextStyle(fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                  const SizedBox(height: 16),
                  StitchInput(
                    label: 'Push Notification Title',
                    controller: _titleController,
                    hintText: 'e.g., Match Starting Soon!',
                  ),
                  const SizedBox(height: 16),
                  StitchInput(
                    label: 'Message Body',
                    controller: _bodyController,
                    hintText: 'e.g., Please enter your game ID in the app.',
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
               width: double.infinity,
               child: StitchButton(
                 text: 'Send Push Notification',
                 onPressed: _sendNotification,
                 isLoading: _isSending,
               ),
            ),
          ],
        ),
      ),
    );
  }
}
