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

  void _showAddEditDialog([Map<String, dynamic>? tournament]) async {
    final isEditing = tournament != null;
    // Fetch games for dropdown
    final gamesRes = await _supabase.from('games').select('id, name');
    final List<Map<String, dynamic>> games = List<Map<String, dynamic>>.from(gamesRes);
    final activeGames = games.where((g) => g['is_active'] == true).toList();
    
    if (activeGames.isEmpty && !isEditing) {
      if (mounted) StitchSnackbar.showError(context, 'Please add a game first before creating a tournament.');
      return;
    }

    String selectedGameId = isEditing && games.any((g) => g['id'] == tournament['game_id']) 
        ? tournament['game_id'] 
        : activeGames.first['id'];

    String selectedType = isEditing ? tournament['tournament_type'] : 'solo';
    final titleCtrl = TextEditingController(text: isEditing ? tournament['title'] : '');
    final entryFeeCtrl = TextEditingController(text: isEditing ? tournament['entry_fee'].toString() : '0');
    final perKillCtrl = TextEditingController(text: isEditing ? tournament['per_kill_reward'].toString() : '0');
    final slotsCtrl = TextEditingController(text: isEditing ? tournament['total_slots'].toString() : '100');
    final totalPrizeCtrl = TextEditingController(text: isEditing ? (tournament['total_prize_pool']?.toString() ?? '0') : '0');
    
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    
    if (isEditing && tournament['start_time'] != null) {
      final dt = DateTime.parse(tournament['start_time']).toLocal();
      selectedDate = dt;
      selectedTime = TimeOfDay.fromDateTime(dt);
    }

    final startCtrl = TextEditingController(text: selectedDate != null ? DateFormat('MMM dd, yyyy • HH:mm').format(selectedDate!) : '');
    final bannerCtrl = TextEditingController(text: isEditing ? (tournament['banner_url'] ?? '') : '');
    final prizeDescCtrl = TextEditingController(text: isEditing ? (tournament['prize_description'] ?? '') : '');

    String initialPrizeConfig = '';
    if (isEditing && tournament['rank_prizes'] != null) {
       final Map rp = tournament['rank_prizes'] as Map;
       // Format as `1=100, 2=50`
       initialPrizeConfig = rp.entries.map((e) => '${e.key}=${e.value}').join(', ');
    }
    final prizeConfigCtrl = TextEditingController(text: initialPrizeConfig);
    
    bool isUploading = false;
    bool isFeatured = isEditing ? (tournament['is_featured'] ?? false) : false;

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
    if (!mounted) return;

    StitchDialog.show(
      context: context,
      title: isEditing ? 'EDIT TOURNAMENT' : 'NEW TOURNAMENT',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('GAME CATEGORY', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: StitchTheme.surfaceHighlight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGameId,
                        isExpanded: true,
                        dropdownColor: StitchTheme.surface,
                        style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 14),
                        items: games.map((g) => DropdownMenuItem<String>(
                          value: g['id'], 
                          child: Text(g['name'].toString().toUpperCase())
                        )).toList(),
                        onChanged: (v) => setDialogState(() => selectedGameId = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text('TOURNAMENT DETAILS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Enter Title', controller: titleCtrl, hintText: 'e.g. Pro Season 1'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: StitchTheme.surfaceHighlight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedType,
                              isExpanded: true,
                              dropdownColor: StitchTheme.surface,
                              style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: 'solo', child: Text('SOLO')),
                                DropdownMenuItem(value: 'duo', child: Text('DUO')),
                                DropdownMenuItem(value: 'squad', child: Text('SQUAD')),
                              ],
                              onChanged: (v) => setDialogState(() => selectedType = v!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: StitchInput(label: 'Slots', controller: slotsCtrl, keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: StitchInput(label: 'Entry (₹)', controller: entryFeeCtrl, keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: StitchInput(label: 'Per Kill (₹)', controller: perKillCtrl, keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Total Prize Pool (₹)', controller: totalPrizeCtrl, keyboardType: TextInputType.number),
                  
                  const SizedBox(height: 20),
                  const Text('SCHEDULE', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context, 
                        initialDate: DateTime.now(), 
                        firstDate: DateTime.now(), 
                        lastDate: DateTime(2030),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(primary: StitchTheme.primary, surface: StitchTheme.surface),
                          ),
                          child: child!,
                        ),
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (time != null) {
                          setDialogState(() {
                            selectedDate = date;
                            selectedTime = time;
                            final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            startCtrl.text = DateFormat('MMM dd, yyyy • HH:mm').format(dt);
                          });
                        }
                      }
                    },
                    child: AbsorbPointer(
                      child: StitchInput(
                        label: 'Start Time', 
                        controller: startCtrl, 
                        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: StitchTheme.primary),
                        hintText: 'Select date & time',
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  const Text('ASSETS & PRIZES', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: StitchInput(label: 'Banner URL', controller: bannerCtrl, hintText: 'https://...')),
                      const SizedBox(width: 12),
                      if (isUploading)
                        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: StitchTheme.primary))
                      else
                        Container(
                          decoration: BoxDecoration(color: StitchTheme.surfaceHighlight, borderRadius: BorderRadius.circular(10)),
                          child: IconButton(
                            icon: const Icon(Icons.add_photo_alternate_rounded, color: StitchTheme.primary, size: 20),
                            onPressed: () => pickAndUpload(setDialogState),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(color: StitchTheme.surfaceHighlight, borderRadius: BorderRadius.circular(10)),
                        child: IconButton(
                          icon: const Icon(Icons.collections_rounded, color: StitchTheme.primary, size: 20),
                          onPressed: () async {
                            final selectedUrl = await context.push<String?>('/assets?selection=true');
                            if (selectedUrl != null) {
                              setDialogState(() => bannerCtrl.text = selectedUrl);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Tournament Description and Rules', controller: prizeDescCtrl, maxLines: 3, hintText: 'Enter description or rules...'),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Prize Configuration (Format: 1=100, 2=50)', controller: prizeConfigCtrl, maxLines: 2, hintText: '1=500, 2=200, 3=100'),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('FEATURED TOURNAMENT', style: TextStyle(color: StitchTheme.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    subtitle: const Text('Show this tournament in the home screen carousel', style: TextStyle(color: StitchTheme.textMuted, fontSize: 11)),
                    value: isFeatured,
                    activeColor: StitchTheme.primary,
                    activeTrackColor: StitchTheme.primary.withOpacity(0.2),
                    onChanged: (v) => setDialogState(() => isFeatured = v),
                  ),
                ],
              ),
            ),
          );
        }
      ),
      primaryButtonText: isEditing ? 'SAVE CHANGES' : 'CREATE TOURNAMENT',
      onPrimaryPressed: () async {
        if (titleCtrl.text.trim().isEmpty || selectedDate == null || selectedTime == null) {
          StitchSnackbar.showError(context, 'Missing required fields');
          return;
        }

        final dt = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute).toUtc();
        Map<String, dynamic>? rankPrizes;
        if (prizeConfigCtrl.text.trim().isNotEmpty) {
          rankPrizes = {};
          final pairs = prizeConfigCtrl.text.split(',');
          for (var p in pairs) {
            final parts = p.split('=');
            if (parts.length == 2) {
              final rank = parts[0].trim();
              final amount = double.tryParse(parts[1].trim());
              if (amount != null) {
                rankPrizes[rank] = amount;
              }
            }
          }
        }

        try {
          final payload = {
            'game_id': selectedGameId,
            'title': titleCtrl.text.trim(),
            'tournament_type': selectedType,
            'entry_fee': double.tryParse(entryFeeCtrl.text.trim()) ?? 0,
            'per_kill_reward': double.tryParse(perKillCtrl.text.trim()) ?? 0,
            'total_slots': int.tryParse(slotsCtrl.text.trim()) ?? 100,
            'total_prize_pool': double.tryParse(totalPrizeCtrl.text.trim()) ?? 0,
            'start_time': dt.toIso8601String(),
            'banner_url': bannerCtrl.text.trim().isEmpty ? null : bannerCtrl.text.trim(),
            'prize_description': prizeDescCtrl.text.trim().isEmpty ? null : prizeDescCtrl.text.trim(),
            'rank_prizes': rankPrizes,
            'is_featured': isFeatured,
          };

          if (isEditing) {
            await _supabase.from('tournaments').update(payload).eq('id', tournament['id']);
          } else {
            payload['created_by'] = _supabase.auth.currentUser!.id;
            await _supabase.from('tournaments').insert(payload);
          }
          
          if (mounted) {
            context.pop();
            StitchSnackbar.showSuccess(context, isEditing ? 'Tournament updated successfully' : 'Tournament created successfully');
            _fetchTournaments();
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, isEditing ? 'Error updating tournament' : 'Error creating tournament');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: const Text('TOURNAMENT CONTROL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 18)),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth > 800 ? 800 : constraints.maxWidth;
          final ScrollController scrollController = ScrollController();
          
          if (_isLoading) return const StitchLoading();

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                child: RefreshIndicator(
                  onRefresh: _fetchTournaments,
                  color: StitchTheme.primary,
                  child: ListView.separated(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _tournaments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final t = _tournaments[index];
                      final status = t['status'].toString();
                      return StitchCard(
                        onTap: () => context.push('/tournament_admin/${t['id']}'),
                        padding: EdgeInsets.zero,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                _getStatusColor(status).withOpacity(0.05),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: StitchTheme.surfaceHighlight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Icon(
                                  status == 'ongoing' ? Icons.play_circle_filled_rounded : 
                                  status == 'upcoming' ? Icons.event_rounded : Icons.check_circle_rounded,
                                  color: _getStatusColor(status),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: StitchTheme.textMain)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          t['games']?['name']?.toString().toUpperCase() ?? 'GAME', 
                                          style: const TextStyle(color: StitchTheme.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('•', style: TextStyle(color: Colors.white24)),
                                        const SizedBox(width: 8),
                                        Text(
                                          t['start_time'] != null ? DateFormat('MMM dd, HH:mm').format(DateTime.parse(t['start_time']).toLocal()) : 'TBA', 
                                          style: const TextStyle(color: StitchTheme.textMuted, fontSize: 11)
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _getStatusColor(status).withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(color: _getStatusColor(status), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${t['joined_slots']}/${t['total_slots']} SLOTS', 
                                    style: const TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                                  ),
                                  if (status == 'upcoming' || status == 'ongoing')
                                    TextButton(
                                      onPressed: () => _showAddEditDialog(t),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('EDIT', style: TextStyle(color: StitchTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                                    )
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        }
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: StitchTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: const Text('NEW TOURNAMENT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
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
