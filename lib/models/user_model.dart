class User {
  final int id;
  final String phone;
  final String firstName;
  final String lastName;
  final String balance;
  final String? birthDate;
  final int? telegramId;
  final String telegramUsername;
  final String loginLabel;

  User({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.balance,
    this.birthDate,
    this.telegramId,
    this.telegramUsername = '',
    this.loginLabel = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      phone: json['phone']?.toString() ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      balance: json['balance']?.toString() ?? '0',
      birthDate: json['birth_date'],
      telegramId: json['telegram_id'] is int
          ? json['telegram_id']
          : int.tryParse('${json['telegram_id'] ?? ''}'),
      telegramUsername: json['telegram_username']?.toString() ?? '',
      loginLabel: json['login_label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'first_name': firstName,
      'last_name': lastName,
      'balance': balance,
      'birth_date': birthDate,
      'telegram_id': telegramId,
      'telegram_username': telegramUsername,
      'login_label': loginLabel,
    };
  }
}
