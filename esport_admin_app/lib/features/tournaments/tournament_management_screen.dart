import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TournamentManagementScreen extends StatefulWidget {
  const TournamentManagementScreen({Key? key}) : super(key: key);

  @override
  State<TournamentManagementScreen> createState() => _TournamentManagementScreenState();
}

class _TournamentManagementScreenState extends State<TournamentManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tournaments = [];

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  Future<void> _fetchTournaments() async {
    try {
      final data = await _supabase
          .from('tournaments')
          .select('*, games(name)')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _tournaments = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() async {
    // Fetch active games for dropdown
    final gamesRes = await _supabase.from('games').select('id, name').eq('is_active', true);
    final List<Map<String, dynamic>> games = List<Map<String, dynamic>>.from(gamesRes);
    
    if (games.isEmpty) {
      if (mounted) StitchSnackbar.showError(context, 'Please add a game first before creating a tournament.');
      return;
    }

    String selectedGameId = games.first['id'];
    String selectedType = 'solo';
    final titleCtrl = TextEditingController();
    final entryFeeCtrl = TextEditingController(text: '0');
    final perKillCtrl = TextEditingController(text: '0');
    final slotsCtrl = TextEditingController(text: '100');
    final startCtrl = TextEditingController();
    final bannerCtrl = TextEditingController();
    final prizeDescCtrl = TextEditingController();
    bool isUploading = false;

    Future<void> pickAndUpload(StateSetter setDialogState) async {
       final picker = ImagePicker();
       final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
       if (pickedFile == null) return;

       setDialogState(() => isUploading = true);
       try {
         final bytes = await pickedFile.readAsBytes();
         final base64Image = base64Encode(bytes);
         
         const apiKey = 'b40febb06056bca6bfdae97dde6b481c';
         final response = await http.post(
           Uri.parse('https://api.imgbb.com/1/upload'),
           body: {
             'key': apiKey,
             'image': base64Image,
           },
         );
         
         if (response.statusCode == 200) {
           final jsonData = jsonDecode(response.body);
           final url = jsonData['data']['url'];
           setDialogState(() {
              bannerCtrl.text = url;
              isUploading = false;
           });
           StitchSnackbar.showSuccess(context, 'Banner uploaded!');
         } else {
           throw Exception();
         }
       } catch (e) {
         setDialogState(() => isUploading = false);
         StitchSnackbar.showError(context, 'Banner upload failed');
       }
    }
    
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    if (!mounted) return;

    StitchDialog.show(
      context: context,
      title: 'Create Tournament',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedGameId,
                    decoration: const InputDecoration(labelText: 'Select Game', border: OutlineInputBorder()),
                    dropdownColor: StitchTheme.surfaceHighlight,
                    style: const TextStyle(color: StitchTheme.textMain),
                    items: games.map((g) => DropdownMenuItem<String>(value: g['id'], child: Text(g['name']))).toList(),
                    onChanged: (v) => setDialogState(() => selectedGameId = v!),
                  ),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Tournament Title', controller: titleCtrl),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                          dropdownColor: StitchTheme.surfaceHighlight,
                          style: const TextStyle(color: StitchTheme.textMain),
                          items: const [
                            DropdownMenuItem(value: 'solo', child: Text('Solo')),
                            DropdownMenuItem(value: 'duo', child: Text('Duo')),
                            DropdownMenuItem(value: 'squad', child: Text('Squad')),
                          ],
                          onChanged: (v) => setDialogState(() => selectedType = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: StitchInput(label: 'Total Slots', controller: slotsCtrl, keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: StitchInput(label: 'Entry Fee (₹)', controller: entryFeeCtrl, keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: StitchInput(label: 'Per Kill (₹)', controller: perKillCtrl, keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (time != null) {
                          setDialogState(() {
                            selectedDate = date;
                            selectedTime = time;
                            final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            startCtrl.text = DateFormat('yyyy-MM-dd HH:mm').format(dt);
                          });
                        }
                      }
                    },
                    child: AbsorbPointer(
                      child: StitchInput(label: 'Start Date & Time', controller: startCtrl, prefixIcon: const Icon(Icons.calendar_today)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: StitchInput(label: 'Banner URL', controller: bannerCtrl)),
                      const SizedBox(width: 8),
                      if (isUploading)
                        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        IconButton(
                          icon: const Icon(Icons.add_photo_alternate_rounded, color: StitchTheme.primary),
                          tooltip: 'Upload Banner',
                          onPressed: () => pickAndUpload(setDialogState),
                        ),
                      IconButton(
                        icon: const Icon(Icons.collections, color: StitchTheme.primary),
                        tooltip: 'Pick from Assets',
                        onPressed: () async {
                          final selectedUrl = await context.push<String?>('/assets?selection=true');
                          if (selectedUrl != null) {
                            setDialogState(() => bannerCtrl.text = selectedUrl);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Prize Description (Optional)', controller: prizeDescCtrl, maxLines: 3),
                ],
              ),
            ),
          );
        }
      ),
      primaryButtonText: 'Create',
      onPrimaryPressed: () async {
        if (titleCtrl.text.trim().isEmpty || selectedDate == null || selectedTime == null) {
          StitchSnackbar.showError(context, 'Title and Start Date are required');
          return;
        }

        final dt = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute).toUtc();
        
        try {
          await _supabase.from('tournaments').insert({
            'game_id': selectedGameId,
            'title': titleCtrl.text.trim(),
            'tournament_type': selectedType,
            'entry_fee': double.parse(entryFeeCtrl.text.trim()),
            'per_kill_reward': double.parse(perKillCtrl.text.trim()),
            'total_slots': int.parse(slotsCtrl.text.trim()),
            'start_time': dt.toIso8601String(),
            'banner_url': bannerCtrl.text.trim().isEmpty ? null : bannerCtrl.text.trim(),
            'prize_description': prizeDescCtrl.text.trim().isEmpty ? null : prizeDescCtrl.text.trim(),
            'created_by': _supabase.auth.currentUser!.id,
          });
          
          if (mounted) {
            context.pop();
            StitchSnackbar.showSuccess(context, 'Tournament created');
            _fetchTournaments();
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Failed to create');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tournaments'),
      ),
      body: _isLoading
          ? const StitchLoading()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _tournaments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final t = _tournaments[index];
                return StitchCard(
                  onTap: () => context.push('/tournament_admin/${t['id']}'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
                            const SizedBox(height: 4),
                            Text(t['games']['name'], style: const TextStyle(color: StitchTheme.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Text(t['start_time'] != null ? DateFormat('MMM dd, HH:mm').format(DateTime.parse(t['start_time']).toLocal()) : 'TBA', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StitchBadge(
                            text: t['status'].toString(),
                            color: _getStatusColor(t['status']),
                          ),
                          const SizedBox(height: 12),
                          Text('${t['joined_slots']}/${t['total_slots']} Slots', style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: StitchTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming': return StitchTheme.secondary;
      case 'ongoing': return StitchTheme.warning;
      case 'completed': return StitchTheme.success;
      default: return StitchTheme.textMuted;
    }
  }
}
