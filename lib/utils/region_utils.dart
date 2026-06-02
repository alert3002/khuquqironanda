import 'package:flutter/widgets.dart';

import '../models/user_model.dart';

/// True when user is likely in Tajikistan (SmartPay white-label banks).
bool isTajikistanUser(User? user) {
  final phone = user?.phone ?? '';
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('992') && digits.length >= 12) return true;
  if (digits.length == 9) return true;

  final locale = WidgetsBinding.instance.platformDispatcher.locale;
  if (locale.countryCode?.toUpperCase() == 'TJ') return true;
  if (locale.languageCode.toLowerCase() == 'tg') return true;

  return false;
}
