class SmartPayBank {
  final int id;
  final String name;
  final String iconAsset;

  const SmartPayBank({
    required this.id,
    required this.name,
    required this.iconAsset,
  });
}

/// Banks for SmartPay white-label (Tajikistan).
const List<SmartPayBank> smartPayBanks = [
  SmartPayBank(id: 8, name: 'Alif Mobi', iconAsset: 'img/wallet_2.webp'),
  SmartPayBank(id: 9, name: 'Eskhata', iconAsset: 'img/wallet_3.webp'),
  SmartPayBank(id: 21, name: 'DC Next', iconAsset: 'img/wallet_4.webp'),
];
