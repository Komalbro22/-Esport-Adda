import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/voucher_model.dart';
import 'dart:convert';
import 'supabase_config.dart';

class VoucherService {
  final SupabaseClient _supabase;

  VoucherService(this._supabase);

  // --- Common ---

  Future<List<VoucherCategory>> getActiveCategories() async {
    final response = await _supabase
        .from('voucher_categories')
        .select()
        .eq('status', 'active')
        .order('name');
    return (response as List).map((json) => VoucherCategory.fromJson(json)).toList();
  }

  Future<List<VoucherAmount>> getActiveAmounts(String categoryId) async {
    final response = await _supabase
        .from('voucher_amounts')
        .select()
        .eq('category_id', categoryId)
        .eq('status', 'active')
        .order('amount');
    return (response as List).map((json) => VoucherAmount.fromJson(json)).toList();
  }

  Future<List<VoucherCode>> getUserVoucherCodes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('voucher_codes')
        .select()
        .eq('used_by', user.id)
        .order('used_at', ascending: false);
    return (response as List).map((json) => VoucherCode.fromJson(json)).toList();
  }
  
  Future<List<VoucherWithdrawRequest>> getUserWithdrawRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('voucher_withdraw_requests')
        .select('*, voucher_categories(name)')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return (response as List).map((json) => VoucherWithdrawRequest.fromJson(json)).toList();
  }

  /// Calls the Edge Function to redeem a voucher and deduct funds atomically
  Future<Map<String, dynamic>> redeemVoucher({
    required String categoryId,
    required double amount,
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      final response = await _supabase.functions.invoke(
        'redeem_voucher',
        body: {
          'category_id': categoryId,
          'amount': amount,
        },
      );
      
      if (response.status == 200) {
        // Parse the JSON response
        final data = response.data;
        if (data is String) {
           return jsonDecode(data);
        }
        return data as Map<String, dynamic>;
      } else {
        throw Exception(response.data?['error'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      if (e is FunctionException) {
        throw Exception(e.details ?? e.reasonPhrase ?? 'Edge Function failed');
      }
      throw Exception('Failed to redeem voucher: $e');
    }
  }

  // --- Admin ---

  Future<List<VoucherCategory>> getAllCategories() async {
    final response = await _supabase
        .from('voucher_categories')
        .select()
        .order('created_at');
    return (response as List).map((json) => VoucherCategory.fromJson(json)).toList();
  }

  Future<VoucherCategory> createCategory(String name, String? iconUrl) async {
    final response = await _supabase
        .from('voucher_categories')
        .insert({
          'name': name,
          'icon_url': iconUrl,
          'status': 'active'
        })
        .select()
        .single();
    return VoucherCategory.fromJson(response);
  }

  Future<void> updateCategoryStatus(String id, String status) async {
    await _supabase
        .from('voucher_categories')
        .update({'status': status})
        .eq('id', id);
  }

  Future<VoucherAmount> createAmount(String categoryId, double amount) async {
    final response = await _supabase
        .from('voucher_amounts')
        .insert({
          'category_id': categoryId,
          'amount': amount,
          'status': 'active'
        })
        .select()
        .single();
    return VoucherAmount.fromJson(response);
  }
  
  Future<void> updateAmountStatus(String id, String status) async {
    await _supabase
        .from('voucher_amounts')
        .update({'status': status})
        .eq('id', id);
  }

  Future<List<VoucherCode>> getAllCodes() async {
    final response = await _supabase
        .from('voucher_codes')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((json) => VoucherCode.fromJson(json)).toList();
  }
  
  Future<void> addVoucherCode(String categoryId, double amount, String code) async {
    await _supabase
        .from('voucher_codes')
        .insert({
          'category_id': categoryId,
          'amount': amount,
          'voucher_code': code,
          'status': 'available'
        });
  }
  
  Future<void> deleteVoucherCode(String id) async {
    await _supabase
        .from('voucher_codes')
        .delete()
        .eq('id', id);
  }

  Future<List<VoucherWithdrawRequest>> getAllWithdrawRequests() async {
    try {
      final response = await _supabase
          .from('voucher_withdraw_requests')
          .select('*, voucher_categories(name), users(name, email)') // Left join by default
          .order('created_at', ascending: false);
          
      return (response as List).map((json) => VoucherWithdrawRequest.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching voucher requests: $e');
      rethrow;
    }
  }

  Future<void> fulfillVoucherRequest(String requestId, String code) async {
    // Fulfils a pending request manually
    await _supabase
        .from('voucher_withdraw_requests')
        .update({
          'status': 'completed',
          'voucher_code': code,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
        
    // Optionally update the wallet_transactions status to completed
    await _supabase
        .from('wallet_transactions')
        .update({'status': 'completed'})
        .eq('reference_id', requestId);
  }

  Future<void> rejectVoucherRequest(String requestId) async {
    // 1. Get request to know amount and user ID
    final requestData = await _supabase
        .from('voucher_withdraw_requests')
        .select()
        .eq('id', requestId)
        .single();
        
    final amount = double.parse(requestData['amount'].toString());
    final userId = requestData['user_id'];

    // 2. Reject request
    await _supabase
        .from('voucher_withdraw_requests')
        .update({
          'status': 'rejected',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
        
    // 3. Update the wallet_transactions status to rejected
    await _supabase
        .from('wallet_transactions')
        .update({'status': 'rejected'})
        .eq('reference_id', requestId);
        
    // 4. Refund winning wallet
    final walletResp = await _supabase
        .from('user_wallets')
        .select('winning_wallet')
        .eq('user_id', userId)
        .single();
        
    final newWinningWallet = double.parse(walletResp['winning_wallet'].toString()) + amount;
    
    await _supabase
        .from('user_wallets')
        .update({'winning_wallet': newWinningWallet})
        .eq('user_id', userId);
  }
}
