class User {
  final int id;
  final String phone;
  final String firstName;
  final String lastName;
  final String balance;
  final String? birthDate;

  User({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.balance,
    this.birthDate,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      phone: json['phone'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      balance: json['balance'] ?? '0',
      birthDate: json['birth_date'],
    );
  }
}
