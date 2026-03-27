import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({Key? key}) : super(key: key);

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _supabase = Supabase.instance.client;
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  
  String _selectedCategory = 'Deposit Issue';
  String _selectedPriority = 'normal';
  String? _imageUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Deposit Issue',
    'Withdraw Issue',
    'Tournament Issue',
    'Bug Report',
    'Account Issue',
    'Other'
  ];

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
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
        setState(() {
          _imageUrl = jsonData['data']['url'];
          _isUploading = false;
        });
        if (!mounted) return;
        StitchSnackbar.showSuccess(context, 'Image attached!');
      } else {
        throw Exception();
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      if (!mounted) return;
      StitchSnackbar.showError(context, 'Image upload failed');
    }
  }

  Future<void> _submitTicket() async {
    if (_subjectCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      StitchSnackbar.showError(context, 'Please fill subject and message');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      
      // 1. Create ticket
      final ticketRes = await _supabase.from('support_tickets').insert({
        'user_id': userId,
        'subject': _subjectCtrl.text.trim(),
        'category': _selectedCategory,
        'priority': _selectedPriority,
      }).select().single();

      final ticketId = ticketRes['id'];

      // 2. Create first message
      await _supabase.from('support_messages').insert({
        'ticket_id': ticketId,
        'sender_id': userId,
        'message': _messageCtrl.text.trim(),
        'image_url': _imageUrl,
        'sender_role': 'player',
      });

      if (mounted) {
        StitchSnackbar.showSuccess(context, 'Ticket created successfully!');
        context.pop(true);
      }
    } catch (e) {
      debugPrint('Support Ticket Error: $e');
      if (mounted) StitchSnackbar.showError(context, 'Failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TELL US WHAT\'S WRONG', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 20),
            StitchInput(label: 'Subject', controller: _subjectCtrl, hintText: 'Short summary of the issue'),
            const SizedBox(height: 20),
            _buildDropdownLabel('Category'),
            const SizedBox(height: 8),
            _buildCategoryDropdown(),
            const SizedBox(height: 20),
            _buildDropdownLabel('Priority'),
            const SizedBox(height: 8),
            _buildPriorityChips(),
            const SizedBox(height: 20),
            StitchInput(label: 'Detailed Description', controller: _messageCtrl, maxLines: 5, hintText: 'Explain the issue in detail...'),
            const SizedBox(height: 20),
            _buildImagePicker(),
            const SizedBox(height: 32),
            StitchButton(
              text: 'Submit Ticket',
              isLoading: _isSubmitting,
              onPressed: _submitTicket,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownLabel(String label) {
    return Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: StitchTheme.textMain));
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: StitchTheme.surface,
          style: const TextStyle(color: StitchTheme.textMain),
          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
      ),
    );
  }

  Widget _buildPriorityChips() {
    return Row(
      children: [
        _priorityChip('low', 'Low', Colors.blue),
        const SizedBox(width: 8),
        _priorityChip('normal', 'Normal', Colors.green),
        const SizedBox(width: 8),
        _priorityChip('high', 'High', Colors.red),
      ],
    );
  }

  Widget _priorityChip(String value, String label, Color color) {
    bool isSelected = _selectedPriority == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPriority = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : StitchTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.05)),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: isSelected ? color : StitchTheme.textMuted, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Attach Image (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: StitchTheme.textMain)),
        const SizedBox(height: 12),
        if (_imageUrl != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(imageUrl: _imageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8, right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _imageUrl = null)),
                ),
              ),
            ],
          )
        else
          InkWell(
            onTap: _isUploading ? null : _pickAndUploadImage,
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: StitchTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05), style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isUploading)
                    const StitchLoading()
                  else ...[
                    const Icon(Icons.add_photo_alternate_rounded, color: StitchTheme.primary, size: 32),
                    const SizedBox(height: 8),
                    const Text('Upload Screenshot', style: TextStyle(color: StitchTheme.textMuted, fontSize: 12)),
                  ]
                ],
              ),
            ),
          ),
      ],
    );
  }
}
