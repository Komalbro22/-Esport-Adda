class ShopProduct {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double price;
  final String? category;
  final bool isDigital;
  final String allowedWalletType;
  final bool isActive;
  final DateTime? createdAt;

  ShopProduct({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.price,
    this.category,
    this.isDigital = true,
    this.allowedWalletType = 'global',
    this.isActive = true,
    this.createdAt,
  });

  factory ShopProduct.fromJson(Map<String, dynamic> json) {
    return ShopProduct(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['image_url'],
      price: double.parse(json['price'].toString()),
      category: json['category'],
      isDigital: json['is_digital'] ?? true,
      allowedWalletType: json['allowed_wallet_type'] ?? 'global',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      'price': price,
      if (category != null) 'category': category,
      'is_digital': isDigital,
      'allowed_wallet_type': allowedWalletType,
      'is_active': isActive,
    };
  }
}
