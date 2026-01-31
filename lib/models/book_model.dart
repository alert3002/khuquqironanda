import 'subscription_plan_model.dart';

class Chapter {
  final int id;
  final String title;
  final String content;
  final bool isFree;
  final int order;
  final bool isPurchased; // Оё боб харида шудааст
  final bool isPremium; // Оё боб VIP аст

  Chapter({
    required this.id,
    required this.title,
    required this.content,
    required this.isFree,
    required this.order,
    required this.isPurchased,
    required this.isPremium,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      isFree: json['is_free'] ?? false,
      order: json['order'] ?? 0,
      isPurchased: json['is_purchased'] ?? false,
      isPremium: json['is_premium'] ?? false,
    );
  }
  
  // Метод барои санҷидани, оё бобро хондан мумкин аст
  bool get canRead => isFree || isPurchased;
}

class Book {
  final int id;
  final String title;
  final String description;
  final String coverImage; // URL-и расм
  final String price;
  final List<Chapter> chapters;
  final bool isPurchased; // Оё китоб харида шудааст
  final List<SubscriptionPlan> plans; // Нақшаҳои обуна
  final DateTime? expiresAt; // Санаи анҷоми обуна

  Book({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImage,
    required this.price,
    required this.chapters,
    required this.isPurchased,
    required this.plans,
    this.expiresAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    List<Chapter> chaptersList = [];
    if (json['chapters'] != null && json['chapters'] is List) {
      chaptersList = (json['chapters'] as List)
          .map((chapter) => Chapter.fromJson(chapter))
          .toList();
    }

    // Parse subscription plans
    List<SubscriptionPlan> plansList = [];
    if (json['plans'] != null && json['plans'] is List) {
      plansList = (json['plans'] as List)
          .map((plan) => SubscriptionPlan.fromJson(plan))
          .toList();
    }

    // Parse expires_at
    DateTime? expiresAt;
    if (json['expires_at'] != null) {
      try {
        expiresAt = DateTime.parse(json['expires_at']);
      } catch (e) {
        print("Error parsing expires_at: $e");
      }
    }

    return Book(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      coverImage: json['cover_image'] ?? '',
      price: json['price'] ?? '0',
      chapters: chaptersList,
      isPurchased: json['is_purchased'] ?? false,
      plans: plansList,
      expiresAt: expiresAt,
    );
  }

  // Helper method to get cheapest plan price
  double? get cheapestPlanPrice {
    if (plans.isEmpty) return null;
    final sortedPlans = List<SubscriptionPlan>.from(plans)
      ..sort((a, b) => a.price.compareTo(b.price));
    return sortedPlans.first.price;
  }

  // Helper method to format expiration date
  String? get formattedExpiresAt {
    if (expiresAt == null) return null;
    return "${expiresAt!.year}-${expiresAt!.month.toString().padLeft(2, '0')}-${expiresAt!.day.toString().padLeft(2, '0')}";
  }
}
