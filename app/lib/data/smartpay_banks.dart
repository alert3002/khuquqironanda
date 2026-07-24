class SmartPayBank {
  final int uiId;
  /// null = саҳифаи умумии SmartPay (ҳамаи бонкҳо)
  final int? deeplinkBankId;
  final String name;
  final String subtitle;
  final String iconAsset;
  /// alif | smartpay
  final String kind;

  const SmartPayBank({
    required this.uiId,
    required this.deeplinkBankId,
    required this.name,
    this.subtitle = '',
    required this.iconAsset,
    required this.kind,
  });

  bool get isAlif => kind == 'alif';
  bool get isSmartPay => kind == 'smartpay';
}

const List<SmartPayBank> smartPayBanks = [
  SmartPayBank(
    uiId: 1,
    deeplinkBankId: 8,
    name: 'Alif',
    subtitle: 'Корти Милли',
    iconAsset: 'assets/smartpay/alif.png',
    kind: 'alif',
  ),
  SmartPayBank(
    uiId: 2,
    deeplinkBankId: null,
    name: 'SmartPay',
    subtitle: 'Бо ҳамаи ҳамёни бонкҳо',
    iconAsset: 'assets/smartpay/smartpay.png',
    kind: 'smartpay',
  ),
];

SmartPayBank? smartPayBankByUiId(int? uiId) {
  if (uiId == null) return null;
  for (final b in smartPayBanks) {
    if (b.uiId == uiId) return b;
  }
  return null;
}
