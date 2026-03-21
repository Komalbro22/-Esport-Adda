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

class _TournamentManagementScreenState extends State<TournamentManagementScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tournaments = [];
  bool _isLoadMoreRunning = false;
  int _page = 0;
  final int _pageSize = 20;
  bool _hasNextPage = true;
  final ScrollController _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchTournaments();
    _scrollController.addListener(_loadMore);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchTournaments({bool isLoadMore = false}) async {
    try {
      if (!isLoadMore) {
        _page = 0;
        _hasNextPage = true;
      }

      final query = _supabase
          .from('tournaments')
          .select('*, games(name, logo_url)')
          .order('created_at', ascending: false)
          .range(_page * _pageSize, (_page + 1) * _pageSize - 1);

      final data = await query;
      final List<Map<String, dynamic>> fetchedTournaments = List<Map<String, dynamic>>.from(data as List);

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _tournaments.addAll(fetchedTournaments);
          } else {
            _tournaments = fetchedTournaments;
          }
          _isLoading = false;
          _hasNextPage = fetchedTournaments.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadMore() async {
    if (_hasNextPage && !_isLoading && !_isLoadMoreRunning && _scrollController.position.extentAfter < 300) {
      if (mounted) setState(() => _isLoadMoreRunning = true);
      _page++;
      await _fetchTournaments(isLoadMore: true);
      if (mounted) setState(() => _isLoadMoreRunning = false);
    }
  }

  // ── Filtered lists ────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _filter(List<String> statuses) {
    return _tournaments.where((t) {
      final status = t['status']?.toString() ?? '';
      final matchesStatus = statuses.contains(status);
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          (t['title']?.toString().toLowerCase().contains(query) ?? false) ||
          (t['games']?['name']?.toString().toLowerCase().contains(query) ?? false);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  List<Map<String, dynamic>> get _upcoming => _filter(['upcoming']);
  List<Map<String, dynamic>> get _ongoing => _filter(['ongoing']);
  // Completed tab shows both completed AND cancelled
  List<Map<String, dynamic>> get _completed => _filter(['completed', 'cancelled']);

  // ── Copy Tournament ───────────────────────────────────────────────────────

  void _copyTournament(Map<String, dynamic> source) {
    // Pre-fill with source data but status = upcoming, no start_time, no room info
    _showAddEditDialog(copyFrom: source);
  }

  // ── Add / Edit Dialog ─────────────────────────────────────────────────────

  void _showAddEditDialog({Map<String, dynamic>? tournament, Map<String, dynamic>? copyFrom}) async {
    final source = tournament ?? copyFrom;
    final isEditing = tournament != null;
    final isCopying = copyFrom != null;

    // Fix: Must select is_active and challenge_enabled to filter games correctly
    final gamesRes = await _supabase.from('games').select('id, name, is_active, challenge_enabled');
    final List<Map<String, dynamic>> games = List<Map<String, dynamic>>.from(gamesRes);
    // Filter out games that have challenges enabled (cannot have tournaments)
    final activeGames = games.where((g) => g['is_active'] == true && g['challenge_enabled'] != true).toList();

    if (activeGames.isEmpty && !isEditing) {
      if (mounted) StitchSnackbar.showError(context, 'Please add an active game first');
      return;
    }

    String selectedGameId = (source != null && games.any((g) => g['id'] == source['game_id']))
        ? source['game_id']
        : activeGames.first['id'];

    String selectedType = source?['tournament_type'] ?? 'solo';
    String selectedPrizeType = source?['prize_type'] ?? 'fixed';
    
    final titleCtrl = TextEditingController(
        text: isCopying ? '${source!['title']} (Copy)' : (source?['title'] ?? ''));
    final entryFeeCtrl = TextEditingController(text: source?['entry_fee']?.toString() ?? '0');
    final perKillCtrl = TextEditingController(text: source?['per_kill_reward']?.toString() ?? '0');
    final slotsCtrl = TextEditingController(text: source?['total_slots']?.toString() ?? '100');
    final totalPrizeCtrl = TextEditingController(text: source?['total_prize_pool']?.toString() ?? '0');
    final commissionCtrl = TextEditingController(text: source?['commission_percentage']?.toString() ?? '10');
    final bannerCtrl = TextEditingController(text: isCopying ? (source?['banner_url'] ?? '') : (source?['banner_url'] ?? ''));
    final prizeDescCtrl = TextEditingController(text: source?['prize_description'] ?? '');
    final rulesCtrl = TextEditingController(text: source?['rules'] ?? '');
    final mapNameCtrl = TextEditingController(text: source?['map_name'] ?? '');
    final modeCtrl = TextEditingController(text: source?['mode'] ?? '');

    String initialPrizeConfig = '';
    if (source?['rank_prizes'] != null) {
      final Map rp = source!['rank_prizes'] as Map;
      initialPrizeConfig = rp.entries.map((e) => '${e.key}=${e.value}').join(', ');
    }
    final prizeConfigCtrl = TextEditingController(text: initialPrizeConfig);

    String initialRankPercentages = '';
    if (source?['rank_percentages'] != null) {
      final Map rp = source!['rank_percentages'] as Map;
      initialRankPercentages = rp.entries.map((e) => '${e.key}=${e.value}').join(', ');
    }
    final rankPercentagesCtrl = TextEditingController(text: initialRankPercentages.isEmpty ? '1=50, 2=20, 3=10' : initialRankPercentages);

    void generateDescription() {
      final fee = double.tryParse(entryFeeCtrl.text) ?? 0;
      final perKill = double.tryParse(perKillCtrl.text) ?? 0;
      final type = selectedPrizeType;
      
      String desc = 'Join this competitive ${selectedType.toUpperCase()} tournament and win big!\n\n';
      desc += '• Entry Fee: ₹$fee\n';
      if (perKill > 0) desc += '• Per Kill Reward: ₹$perKill\n';
      
      if (type == 'fixed') {
        desc += '• Total Prize Pool: ₹${totalPrizeCtrl.text}\n';
        desc += '• Prize Type: Fixed (Guaranteed Rewards)\n';
      } else {
        desc += '• Prize Type: Dynamic (Increases with Players)\n';
        desc += '• Commission: ${commissionCtrl.text}%\n';
      }
      desc += '\nEnsure you read all the rules before joining. Good luck!';
      prizeDescCtrl.text = desc;
    }

    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    
    // ... rest of the setup logic ...
    if (isEditing && source?['start_time'] != null) {
      final dt = DateTime.parse(source!['start_time']).toLocal();
      selectedDate = dt;
      selectedTime = TimeOfDay.fromDateTime(dt);
    }

    final startCtrl = TextEditingController(
        text: selectedDate != null ? DateFormat('MMM dd, yyyy • HH:mm').format(selectedDate!) : '');
    bool isUploading = false;
    bool isFeatured = isEditing ? (source?['is_featured'] ?? false) : false;

    Future<void> pickAndUpload(StateSetter setDialogState) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile == null) return;
      setDialogState(() => isUploading = true);
      try {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        const apiKey = 'b40febb06056bca6bfdae97dde6b481c';
        final response = await http.post(Uri.parse('https://api.imgbb.com/1/upload'),
            body: {'key': apiKey, 'image': base64Image});
        if (response.statusCode == 200) {
          final url = jsonDecode(response.body)['data']['url'];
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
        StitchSnackbar.showError(context, 'Upload failed');
      }
    }

    if (!mounted) return;

    String dialogTitle = isEditing
        ? 'EDIT TOURNAMENT'
        : isCopying
            ? 'COPY TOURNAMENT'
            : 'NEW TOURNAMENT';

    StitchDialog.show(
      context: context,
      title: dialogTitle,
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
                  _buildDropdown(games, selectedGameId, (v) => setDialogState(() => selectedGameId = v!)),
                  const SizedBox(height: 20),

                  const Text('BASIC INFO', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Title', controller: titleCtrl, hintText: 'e.g. Pro Season 1'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildTypeDropdown(selectedType, (v) => setDialogState(() => selectedType = v!))),
                    const SizedBox(width: 12),
                    Expanded(child: StitchInput(label: 'Slots', controller: slotsCtrl, keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: StitchInput(label: 'Entry (₹)', controller: entryFeeCtrl, keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: StitchInput(label: 'Per Kill (₹)', controller: perKillCtrl, keyboardType: TextInputType.number)),
                  ]),

                  const SizedBox(height: 20),
                  const Text('PRIZE CONFIGURATION', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  _buildPrizeTypeDropdown(selectedPrizeType, (v) => setDialogState(() => selectedPrizeType = v!)),
                  const SizedBox(height: 12),
                  if (selectedPrizeType == 'fixed') ...[
                    StitchInput(label: 'Total Prize Pool (₹)', controller: totalPrizeCtrl, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    StitchInput(label: 'Prize Config (1=500, 2=200)', controller: prizeConfigCtrl, hintText: '1=500, 2=200'),
                  ] else ...[
                    Row(children: [
                       Expanded(child: StitchInput(label: 'Commission %', controller: commissionCtrl, keyboardType: TextInputType.number)),
                       const SizedBox(width: 12),
                       const Expanded(child: SizedBox()), // Placeholder
                    ]),
                    const SizedBox(height: 12),
                    StitchInput(label: 'Rank Percentages (1=50, 2=20)', controller: rankPercentagesCtrl, hintText: '1=50, 2=20'),
                    const SizedBox(height: 4),
                    const Text('Sum of percentages should be <= 100', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10)),
                  ],
                  const SizedBox(height: 16),
                  StitchButton(text: 'AUTO-GENERATE DESCRIPTION', isSecondary: true, onPressed: generateDescription),

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
                          data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark(primary: StitchTheme.primary, surface: StitchTheme.surface)),
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
                  const Text('EXTRA DETAILS', style: TextStyle(color: StitchTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: StitchInput(label: 'Map Name', controller: mapNameCtrl, hintText: 'e.g. Erangel')),
                    const SizedBox(width: 12),
                    Expanded(child: StitchInput(label: 'Game Mode', controller: modeCtrl, hintText: 'e.g. TPP')),
                  ]),
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
                          child: IconButton(icon: const Icon(Icons.add_photo_alternate_rounded, color: StitchTheme.primary, size: 20), onPressed: () => pickAndUpload(setDialogState)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Description', controller: prizeDescCtrl, maxLines: 4, hintText: 'Tournament description...'),
                  const SizedBox(height: 12),
                  StitchInput(label: 'Rules', controller: rulesCtrl, maxLines: 4, hintText: 'Tournament rules...'),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('FEATURED', style: TextStyle(color: StitchTheme.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    subtitle: const Text('Show in home screen carousel', style: TextStyle(color: StitchTheme.textMuted, fontSize: 11)),
                    value: isFeatured,
                    activeColor: StitchTheme.primary,
                    onChanged: (v) => setDialogState(() => isFeatured = v),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      primaryButtonText: isEditing ? 'SAVE CHANGES' : isCopying ? 'CREATE COPY' : 'CREATE TOURNAMENT',
      onPrimaryPressed: () async {
        if (titleCtrl.text.trim().isEmpty || selectedDate == null || selectedTime == null) {
          StitchSnackbar.showError(context, 'Title and start time are required');
          return;
        }

        final dt = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute).toUtc();
        
        Map<String, dynamic>? rankPrizes;
        if (selectedPrizeType == 'fixed' && prizeConfigCtrl.text.trim().isNotEmpty) {
          rankPrizes = {};
          for (var p in prizeConfigCtrl.text.split(',')) {
            final parts = p.split('=');
            if (parts.length == 2) {
              final rank = parts[0].trim();
              final amount = double.tryParse(parts[1].trim());
              if (amount != null) rankPrizes[rank] = amount;
            }
          }
        }

        Map<String, dynamic>? rankPercentages;
        if (selectedPrizeType == 'dynamic' && rankPercentagesCtrl.text.trim().isNotEmpty) {
          rankPercentages = {};
          double totalP = 0;
          for (var p in rankPercentagesCtrl.text.split(',')) {
            final parts = p.split('=');
            if (parts.length == 2) {
              final rank = parts[0].trim();
              final percent = double.tryParse(parts[1].trim());
              if (percent != null) {
                rankPercentages[rank] = percent;
                totalP += percent;
              }
            }
          }
          if (totalP > 100) {
            StitchSnackbar.showError(context, 'Percentages cannot exceed 100%');
            return;
          }
        }

        try {
          final payload = {
            'game_id': selectedGameId,
            'title': titleCtrl.text.trim(),
            'tournament_type': selectedType,
            'prize_type': selectedPrizeType,
            'commission_percentage': double.tryParse(commissionCtrl.text.trim()) ?? 10,
            'entry_fee': double.tryParse(entryFeeCtrl.text.trim()) ?? 0,
            'per_kill_reward': double.tryParse(perKillCtrl.text.trim()) ?? 0,
            'total_slots': int.tryParse(slotsCtrl.text.trim()) ?? 100,
            'total_prize_pool': double.tryParse(totalPrizeCtrl.text.trim()) ?? 0,
            'start_time': dt.toIso8601String(),
            'banner_url': bannerCtrl.text.trim().isEmpty ? null : bannerCtrl.text.trim(),
            'prize_description': prizeDescCtrl.text.trim().isEmpty ? null : prizeDescCtrl.text.trim(),
            'rules': rulesCtrl.text.trim().isEmpty ? null : rulesCtrl.text.trim(),
            'map_name': mapNameCtrl.text.trim().isEmpty ? null : mapNameCtrl.text.trim(),
            'mode': modeCtrl.text.trim().isEmpty ? null : modeCtrl.text.trim(),
            'rank_prizes': selectedPrizeType == 'fixed' ? rankPrizes : null,
            'rank_percentages': selectedPrizeType == 'dynamic' ? rankPercentages : null,
            'is_featured': isFeatured,
          };

          if (isEditing) {
            await _supabase.from('tournaments').update(payload).eq('id', tournament['id']);
          } else {
            payload['status'] = 'upcoming';
            payload['joined_slots'] = 0;
            payload['created_by'] = _supabase.auth.currentUser!.id;
            await _supabase.from('tournaments').insert(payload);
          }

          if (mounted) {
            context.pop();
            StitchSnackbar.showSuccess(context, isEditing ? 'Tournament updated' : isCopying ? 'Tournament copied!' : 'Tournament created');
            _fetchTournaments();
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Error saving tournament');
        }
      },
    );

  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchTheme.background,
      appBar: AppBar(
        title: const Text('Tournament Management', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: StitchTheme.primary,
          indicatorWeight: 3,
          labelColor: StitchTheme.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
          unselectedLabelColor: StitchTheme.textMuted,
          tabs: [
            Tab(text: 'UPCOMING (${_upcoming.length})'),
            Tab(text: 'ONGOING (${_ongoing.length})'),
            Tab(text: 'COMPLETED (${_completed.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const StitchLoading()
          : Column(
              children: [
                // Search bar
                Container(
                  color: StitchTheme.surface,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search tournaments, games...',
                      hintStyle: const TextStyle(color: StitchTheme.textMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: StitchTheme.textMuted, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: StitchTheme.textMuted, size: 18),
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _searchQuery = '';
                              }),
                            )
                          : null,
                      filled: true,
                      fillColor: StitchTheme.surfaceHighlight,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTournamentList(_upcoming),
                      _buildTournamentList(_ongoing),
                      _buildTournamentList(_completed),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: StitchTheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 28),
      ),
    );
  }

  Widget _buildTournamentList(List<Map<String, dynamic>> tournaments) {
    if (tournaments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 56, color: StitchTheme.textMuted.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text('No tournaments found', style: TextStyle(color: StitchTheme.textMuted, fontSize: 14)),
          ],
        ),
      );
    }

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final t in tournaments) {
      final dateKey = t['start_time'] != null
          ? DateFormat('MMMM dd, yyyy').format(DateTime.parse(t['start_time']).toLocal()).toUpperCase()
          : 'NO DATE SET';
      grouped.putIfAbsent(dateKey, () => []).add(t);
    }

    return RefreshIndicator(
    onRefresh: () => _fetchTournaments(),
    color: StitchTheme.primary,
    child: ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: grouped.length + (_hasNextPage ? 1 : 0),
      itemBuilder: (context, groupIndex) {
        if (groupIndex == grouped.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: StitchLoading(),
            ),
          );
        }

        final dateKey = grouped.keys.elementAt(groupIndex);
        final items = grouped[dateKey]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Text(dateKey, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: StitchTheme.textMuted, letterSpacing: 1)),
                  const SizedBox(width: 8),
                  Container(height: 1, width: 20, color: StitchTheme.surfaceHighlight),
                  const Spacer(),
                  Text('${items.length} Tournament${items.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 11, color: StitchTheme.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ...items.map((t) => _buildTournamentTile(t)),
          ],
        );
      },
    ),
  );
}

  Widget _buildTournamentTile(Map<String, dynamic> t) {
    final status = t['status']?.toString() ?? 'upcoming';
    final statusColor = _getStatusColor(status);
    final entryFee = (t['entry_fee'] as num?)?.toDouble() ?? 0;
    final joinedSlots = t['joined_slots'] ?? 0;
    final totalSlots = t['total_slots'] ?? 0;
    final slotProgress = totalSlots > 0 ? joinedSlots / totalSlots : 0.0;
    final startTime = t['start_time'] != null
        ? DateTime.parse(t['start_time']).toLocal()
        : null;
    final bannerUrl = t['banner_url'];
    final gameName = t['games']?['name']?.toString() ?? 'Game';
    final type = t['tournament_type']?.toString().toUpperCase() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/tournament_admin/${t['id']}'),
        child: Container(
          decoration: BoxDecoration(
            color: StitchTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner / Game logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: bannerUrl != null
                          ? Image.network(bannerUrl, width: 60, height: 60, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholderIcon(statusColor))
                          : _placeholderIcon(statusColor),
                    ),
                    const SizedBox(width: 14),

                    // Main info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title + fee
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(t['title'] ?? '',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: StitchTheme.textMain, height: 1.2)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entryFee == 0 ? 'Free' : '₹${entryFee.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: entryFee == 0 ? Colors.green : StitchTheme.textMain,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Game • Type badge
                          Row(
                            children: [
                              Text(gameName, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusColor.withOpacity(0.25)),
                                ),
                                child: Text(
                                  status == 'cancelled' ? 'CANCELLED' : status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(type, style: const TextStyle(color: StitchTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Time & slots row
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 13, color: StitchTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                startTime != null ? DateFormat('hh:mm a').format(startTime) : 'TBA',
                                style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12),
                              ),
                              const SizedBox(width: 16),
                              const Icon(Icons.group_rounded, size: 13, color: StitchTheme.textMuted),
                              const SizedBox(width: 4),
                              Text('$joinedSlots/$totalSlots Teams',
                                  style: const TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: StitchTheme.textMuted, size: 20),
                  ],
                ),
              ),

              // Slot progress bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: slotProgress.clamp(0.0, 1.0),
                    backgroundColor: StitchTheme.surfaceHighlight,
                    color: statusColor,
                    minHeight: 3,
                  ),
                ),
              ),

              // Action buttons row
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Row(
                  children: [
                    // Copy button — always available
                    TextButton.icon(
                      onPressed: () => _copyTournament(t),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('COPY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    if (status == 'upcoming' || status == 'ongoing') ...[
                      TextButton.icon(
                        onPressed: () => _showAddEditDialog(tournament: t),
                        icon: const Icon(Icons.edit_rounded, size: 14),
                        label: const Text('EDIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: StitchTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(t),
                      icon: const Icon(Icons.delete_outline_rounded, size: 14),
                      label: const Text('DELETE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: StitchTheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => context.push('/tournament_admin/${t['id']}'),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('MANAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: StitchTheme.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> tournament) {
    StitchDialog.show(
      context: context,
      title: 'Delete Tournament',
      content: Text('Delete "${tournament['title']}"? This will also delete all joined teams. This action cannot be undone.', style: const TextStyle(color: StitchTheme.textMuted)),
      primaryButtonText: 'Delete',
      primaryButtonColor: StitchTheme.error,
      onPrimaryPressed: () async {
        try {
          await _supabase.from('tournaments').delete().eq('id', tournament['id']);
          if (mounted) {
            context.pop();
            StitchSnackbar.showSuccess(context, 'Tournament deleted');
            _fetchTournaments();
          }
        } catch (e) {
          if (mounted) StitchSnackbar.showError(context, 'Failed to delete tournament');
        }
      },
      secondaryButtonText: 'Cancel',
      onSecondaryPressed: () => context.pop(),
    );
  }

  Widget _placeholderIcon(Color color) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.emoji_events_rounded, color: color, size: 28),
    );
  }

  Widget _buildDropdown(List<Map<String, dynamic>> games, String value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: StitchTheme.surfaceHighlight, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: StitchTheme.surface,
          style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 14),
          items: games.map((g) => DropdownMenuItem<String>(value: g['id'], child: Text(g['name'].toString().toUpperCase()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTypeDropdown(String value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: StitchTheme.surfaceHighlight, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: StitchTheme.surface,
          style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 'solo', child: Text('SOLO')),
            DropdownMenuItem(value: 'duo', child: Text('DUO')),
            DropdownMenuItem(value: 'squad', child: Text('SQUAD')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPrizeTypeDropdown(String value, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: StitchTheme.surfaceHighlight, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: StitchTheme.surface,
          style: const TextStyle(color: StitchTheme.textMain, fontWeight: FontWeight.bold, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 'fixed', child: Text('FIXED PRIZE POOL')),
            DropdownMenuItem(value: 'dynamic', child: Text('DYNAMIC PRIZE POOL')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming': return StitchTheme.secondary;
      case 'ongoing': return StitchTheme.warning;
      case 'completed': return StitchTheme.success;
      case 'cancelled': return Colors.red;
      default: return StitchTheme.textMuted;
    }
  }
}
