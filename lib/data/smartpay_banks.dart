class SmartPayBank {
  final int uiId;
  final int? deeplinkBankId;
  final String name;
  final String iconAsset;

  const SmartPayBank({
    required this.uiId,
    required this.deeplinkBankId,
    required this.name,
    required this.iconAsset,
  });

  bool get usesWebPayment => deeplinkBankId == null;
}

const List<SmartPayBank> smartPayBanks = [
  SmartPayBank(
    uiId: 1,
    deeplinkBankId: 8,
    name: 'Alif Mobi',
    iconAsset: 'assets/smartpay/alif.png',
  ),
  SmartPayBank(
    uiId: 2,
    deeplinkBankId: 9,
    name: 'Eskhata',
    iconAsset: 'assets/smartpay/eskhata.png',
  ),
  SmartPayBank(
    uiId: 3,
    deeplinkBankId: null,
    name: 'DC Next',
    iconAsset: 'assets/smartpay/dc.png',
  ),
];

SmartPayBank? smartPayBankByUiId(int? uiId) {
  if (uiId == null) return null;
  for (final b in smartPayBanks) {
    if (b.uiId == uiId) return b;
  }
  return null;
}
