class SubscriptionPlan {
  final int id;
  final String name;
  final double price;
  final int days;
  final bool isActive;
  /// Product ID дар App Store Connect (агар холӣ бошад, дар iOS IAP нест).
  final String? appleProductId;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.days,
    required this.isActive,
    this.appleProductId,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final rawApple = json['apple_product_id'];
    return SubscriptionPlan(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] is String)
          ? double.tryParse(json['price']) ?? 0.0
          : (json['price'] ?? 0.0).toDouble(),
      days: json['days'] ?? 0,
      isActive: json['is_active'] ?? true,
      appleProductId: rawApple is String && rawApple.trim().isNotEmpty
          ? rawApple.trim()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'days': days,
      'is_active': isActive,
      if (appleProductId != null) 'apple_product_id': appleProductId,
    };
  }

  // Helper method to format price display
  String get formattedPrice => '${price.toStringAsFixed(2)} сомонӣ';
  
  // Helper method to format duration display
  String get formattedDuration {
    if (days <= 0) return '0 рӯз';
    return '$days рӯз';
  }
}

