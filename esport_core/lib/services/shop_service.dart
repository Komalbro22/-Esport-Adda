import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_product_model.dart';
import '../models/shop_order_model.dart';

class ShopService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Products
  Future<List<ShopProduct>> getActiveProducts() async {
    final response = await _supabase
        .from('shop_products')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return response.map((e) => ShopProduct.fromJson(e)).toList();
  }

  Future<List<ShopProduct>> getAllProducts() async {
    final response = await _supabase
        .from('shop_products')
        .select()
        .order('created_at', ascending: false);
    return response.map((e) => ShopProduct.fromJson(e)).toList();
  }

  Future<void> createProduct(ShopProduct product) async {
    await _supabase.from('shop_products').insert({
      'name': product.name,
      'description': product.description,
      'image_url': product.imageUrl,
      'price': product.price,
      'category': product.category,
      'is_digital': product.isDigital,
      'allowed_wallet_type': product.allowedWalletType,
      'is_active': product.isActive,
    });
  }

  Future<void> updateProduct(ShopProduct product) async {
    await _supabase.from('shop_products').update({
      'name': product.name,
      'description': product.description,
      'image_url': product.imageUrl,
      'price': product.price,
      'category': product.category,
      'is_digital': product.isDigital,
      'allowed_wallet_type': product.allowedWalletType,
      'is_active': product.isActive,
    }).eq('id', product.id);
  }

  Future<void> deleteProduct(String id) async {
    await _supabase.from('shop_products').delete().eq('id', id);
  }

  // Orders
  Future<List<ShopOrder>> getUserOrders(String userId) async {
    final response = await _supabase
        .from('shop_orders')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response.map((e) => ShopOrder.fromJson(e)).toList();
  }

  Future<List<ShopOrder>> getAllOrders() async {
    final response = await _supabase
        .from('shop_orders')
        .select('*, shop_products(*), users(*)')
        .order('created_at', ascending: false);
    return response.map((e) => ShopOrder.fromJson(e)).toList();
  }

  Future<void> updateOrderStatus(String orderId, String status, {String? deliveryData}) async {
    // For cancellations we must call the RPC so the user's wallet gets refunded.
    if (status == 'cancelled') {
      await _supabase.rpc('cancel_shop_order', params: {'p_order_id': orderId});
      return;
    }

    final data = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (deliveryData != null) {
      data['delivery_data'] = deliveryData;
    }

    await _supabase.from('shop_orders').update(data).eq('id', orderId);
  }

  // Purchases
  Future<Map<String, dynamic>> purchaseProduct(String userId, String productId) async {
    final response = await _supabase.rpc('purchase_shop_product', params: {
      'p_user_id': userId,
      'p_product_id': productId,
    });
    return response as Map<String, dynamic>;
  }

  Future<void> cancelOrder(String orderId) async {
    await _supabase.rpc('cancel_shop_order', params: {'p_order_id': orderId});
  }

  // Global settings
  Future<String> getDefaultShopWalletType() async {
    final response = await _supabase.from('app_settings').select('default_shop_wallet_type').limit(1).maybeSingle();
    return response?['default_shop_wallet_type'] ?? 'both';
  }

  Future<void> updateDefaultShopWalletType(String type) async {
    final exists = await _supabase.from('app_settings').select('id').limit(1).maybeSingle();
    if (exists == null) {
      // should never happen if SQL is correctly seeded, but fallback
      await _supabase.from('app_settings').insert({'default_shop_wallet_type': type});
    } else {
      await _supabase.from('app_settings').update({'default_shop_wallet_type': type}).eq('id', exists['id']);
    }
  }
}
