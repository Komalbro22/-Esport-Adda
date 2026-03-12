class VoucherCategory {
  final String id;
  final String name;
  final String? iconUrl;
  final String status;
  final DateTime createdAt;

  VoucherCategory({
    required this.id,
    required this.name,
    this.iconUrl,
    required this.status,
    required this.createdAt,
  });

  factory VoucherCategory.fromJson(Map<String, dynamic> json) {
    return VoucherCategory(
      id: json['id'],
      name: json['name'],
      iconUrl: json['icon_url'],
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'icon_url': iconUrl,
      'status': status,
    };
  }
}

class VoucherAmount {
  final String id;
  final String categoryId;
  final double amount;
  final String status;
  final DateTime createdAt;

  VoucherAmount({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory VoucherAmount.fromJson(Map<String, dynamic> json) {
    return VoucherAmount(
      id: json['id'],
      categoryId: json['category_id'],
      amount: double.parse(json['amount'].toString()),
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'category_id': categoryId,
      'amount': amount,
      'status': status,
    };
  }
}

class VoucherCode {
  final String id;
  final String categoryId;
  final double amount;
  final String voucherCode;
  final String status;
  final String? usedBy;
  final DateTime? usedAt;
  final DateTime createdAt;

  VoucherCode({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.voucherCode,
    required this.status,
    this.usedBy,
    this.usedAt,
    required this.createdAt,
  });

  factory VoucherCode.fromJson(Map<String, dynamic> json) {
    return VoucherCode(
      id: json['id'],
      categoryId: json['category_id'],
      amount: double.parse(json['amount'].toString()),
      voucherCode: json['voucher_code'],
      status: json['status'] ?? 'available',
      usedBy: json['used_by'],
      usedAt: json['used_at'] != null ? DateTime.parse(json['used_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'category_id': categoryId,
      'amount': amount,
      'voucher_code': voucherCode,
      'status': status,
      if (usedBy != null) 'used_by': usedBy,
      if (usedAt != null) 'used_at': usedAt?.toIso8601String(),
    };
  }
}

class VoucherWithdrawRequest {
  final String id;
  final String userId;
  final String categoryId;
  final double amount;
  final String status;
  final String? voucherCode;
  final DateTime createdAt;
  final DateTime? completedAt;

  // Optional relations populated by joins
  final String? categoryName;
  final String? userName;

  VoucherWithdrawRequest({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amount,
    required this.status,
    this.voucherCode,
    required this.createdAt,
    this.completedAt,
    this.categoryName,
    this.userName,
  });

  factory VoucherWithdrawRequest.fromJson(Map<String, dynamic> json) {
    return VoucherWithdrawRequest(
      id: json['id'],
      userId: json['user_id'],
      categoryId: json['category_id'],
      amount: double.parse(json['amount'].toString()),
      status: json['status'] ?? 'pending',
      voucherCode: json['voucher_code'],
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      categoryName: json['voucher_categories']?['name'],
      userName: json['users']?['name'] ?? json['users']?['email'], // Depending on relation mapping
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'amount': amount,
      'status': status,
      if (voucherCode != null) 'voucher_code': voucherCode,
      if (completedAt != null) 'completed_at': completedAt?.toIso8601String(),
    };
  }
}
