import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esport_core/esport_core.dart';
import 'package:intl/intl.dart';

class CreatePromoDialog extends StatefulWidget {
  const CreatePromoDialog({Key? key}) : super(key: key);

  @override
  State<CreatePromoDialog> createState() => _CreatePromoDialogState();
}

class _CreatePromoDialogState extends State<CreatePromoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _amountController = TextEditingController();
  final _limitController = TextEditingController();
  
  String _rewardType = 'deposit';
  String _usageType = 'unlimited';
  DateTime? _expiryDate;
  bool _isSubmitting = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('promo_codes').insert({
        'code': _codeController.text.trim().toUpperCase(),
        'reward_amount': double.parse(_amountController.text),
        'reward_type': _rewardType,
        'usage_type': _usageType,
        'usage_limit': _usageType == 'limited' ? int.parse(_limitController.text) : null,
        'expires_at': _expiryDate?.toIso8601String(),
        'is_active': true,
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) StitchSnackbar.showError(context, 'Failed to create promo code');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Promo Code'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'PROMO CODE (e.g. MEGA50)'),
                textCapitalization: TextCapitalization.characters,
                validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'REWARD AMOUNT (₹)'),
                keyboardType: TextInputType.number,
                validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _rewardType,
                decoration: const InputDecoration(labelText: 'REWARD TYPE'),
                items: const [
                  DropdownMenuItem(value: 'deposit', child: Text('Deposit Wallet')),
                  DropdownMenuItem(value: 'winning', child: Text('Winning Wallet')),
                ],
                onChanged: (val) => setState(() => _rewardType = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _usageType,
                decoration: const InputDecoration(labelText: 'USAGE TYPE'),
                items: const [
                  DropdownMenuItem(value: 'unlimited', child: Text('Unlimited Users')),
                  DropdownMenuItem(value: 'limited', child: Text('Limited Users')),
                ],
                onChanged: (val) => setState(() => _usageType = val!),
              ),
              if (_usageType == 'limited') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _limitController,
                  decoration: const InputDecoration(labelText: 'USAGE LIMIT (Total users)'),
                  keyboardType: TextInputType.number,
                  validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
                ),
              ],
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expiry Date', style: TextStyle(fontSize: 14)),
                subtitle: Text(_expiryDate == null ? 'No Expiry' : DateFormat('dd MMM yyyy').format(_expiryDate!)),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: _selectDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        SizedBox(
          width: 100,
          child: StitchButton(
            text: 'CREATE',
            onPressed: _isSubmitting ? null : _save,
            isLoading: _isSubmitting,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _amountController.dispose();
    _limitController.dispose();
    super.dispose();
  }
}
