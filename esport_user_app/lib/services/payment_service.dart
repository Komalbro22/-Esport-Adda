import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:esport_core/esport_core.dart';

class PaymentService {
  final _supabase = Supabase.instance.client;
  late Razorpay _razorpay;

  // callbacks
  Function(String)? onPaymentSuccess;
  Function(String)? onPaymentError;

  PaymentService() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Call our edge function to verify the signature (Webhook acts as primary DB updater)
    try {
      final res = await _supabase.functions.invoke('razorpay_verify_payment', body: {
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
      });

      if (res.status == 200) {
        onPaymentSuccess?.call("Payment Successful! Wallet updated.");
      } else {
        onPaymentError?.call("Payment verification failed. If money was deducted, contact support.");
      }
    } catch (e) {
      // Even if immediate frontend verification fails, the webhook should handle it.
      onPaymentSuccess?.call("Payment processing. Check wallet history shortly.");
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    onPaymentError?.call(response.message ?? 'Payment failed or cancelled');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    onPaymentError?.call('External Wallet payments are not currently supported.');
  }

  Future<void> openRazorpayCheckout({
    required double amount, 
    required String keyId,
  }) async {
    try {
      // Create order from endpoint
      final res = await _supabase.functions.invoke('razorpay_create_order', body: {
        'amount': amount
      });

      if (res.status == 200 && res.data['success']) {
         final orderId = res.data['order']['id'];
         final user = _supabase.auth.currentUser;

         var options = {
            'key': keyId,
            'amount': (amount * 100).toInt(),
            'name': 'Esport Adda',
            'description': 'Wallet Deposit',
            'order_id': orderId,
            'prefill': {
              'contact': user?.userMetadata?['phone'] ?? '',
              'email': user?.email ?? ''
            },
            'theme': {
              'color': '#00D1FF' // Primary blue style
            }
         };

         _razorpay.open(options);
      } else {
         onPaymentError?.call(res.data['error'] ?? 'Failed to create order');
      }
    } catch (e) {
       onPaymentError?.call('Server error: unable to create payment order. Try again later.');
    }
  }

  // Fetch active method from DB via RPC
  Future<Map<String, dynamic>?> getActivePaymentMethod() async {
     try {
       final res = await _supabase.rpc('get_active_payment_method');
       return res as Map<String, dynamic>?;
     } catch (e) {
       return null;
     }
  }
}
