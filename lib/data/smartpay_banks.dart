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
  SmartPayBank(id: 8, name: 'Alif Mobi', iconAsset: 'assets/smartpay/alif.png'),
  SmartPayBank(id: 9, name: 'Eskhata', iconAsset: 'assets/smartpay/eskhata.png'),
  SmartPayBank(id: 21, name: 'DC Next', iconAsset: 'assets/smartpay/dc.png'),
];
