class SubscriptionPlan {
  final int id;
  final String name;
  final double price;
  final int days;
  final bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.days,
    required this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: (json['price'] is String) 
          ? double.tryParse(json['price']) ?? 0.0
          : (json['price'] ?? 0.0).toDouble(),
      days: json['days'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'days': days,
      'is_active': isActive,
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

