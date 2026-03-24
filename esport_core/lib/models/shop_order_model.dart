class ShopOrder {
  final String id;
  final String userId;
  final String? productId;
  final double amount;
  final String? paidFrom;
  final String status;
  final String? deliveryData;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ShopOrder({
    required this.id,
    required this.userId,
    this.productId,
    required this.amount,
    this.paidFrom,
    this.status = 'pending',
    this.deliveryData,
    this.createdAt,
    this.updatedAt,
  });

  factory ShopOrder.fromJson(Map<String, dynamic> json) {
    return ShopOrder(
      id: json['id'],
      userId: json['user_id'],
      productId: json['product_id'],
      amount: double.parse(json['amount'].toString()),
      paidFrom: json['paid_from'],
      status: json['status'] ?? 'pending',
      deliveryData: json['delivery_data'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      if (productId != null) 'product_id': productId,
      'amount': amount,
      if (paidFrom != null) 'paid_from': paidFrom,
      'status': status,
      if (deliveryData != null) 'delivery_data': deliveryData,
    };
  }
}
