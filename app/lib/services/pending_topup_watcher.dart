import 'dart:async' show Timer, unawaited;

import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_service.dart';

/// Tracks SmartPay top-ups until webhook confirms SUCCESS (even across screens).
class PendingTopUpWatcher extends ChangeNotifier with WidgetsBindingObserver {
  PendingTopUpWatcher._();

  static final PendingTopUpWatcher instance = PendingTopUpWatcher._();

  static const _orderKey = 'pending_topup_order_id';
  static const _amountKey = 'pending_topup_amount';
  static const _balanceBeforeKey = 'pending_topup_balance_before';
  static const _startedKey = 'pending_topup_started_ms';

  Timer? _timer;
  int _pollTick = 0;
  bool _syncing = false;

  String? activeOrderId;
  String? pendingAmount;
  String? balanceBefore;
  int pendingCount = 0;
  String? statusMessage;
  bool justSucceeded = false;
  String? lastCreditedAmount;

  bool get isWatching => activeOrderId != null && activeOrderId!.isNotEmpty;
  bool get hasPending => isWatching || pendingCount > 0;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    _restoreFromHive();
    if (isWatching) {
      _startTimer();
      unawaited(syncNow(silent: true));
    }
  }

  void disposeWatcher() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && hasPending) {
      unawaited(syncNow());
    }
  }

  void _restoreFromHive() {
    try {
      final box = Hive.box('settings');
      activeOrderId = box.get(_orderKey)?.toString();
      pendingAmount = box.get(_amountKey)?.toString();
      balanceBefore = box.get(_balanceBeforeKey)?.toString();
      if (activeOrderId != null && activeOrderId!.isEmpty) {
        activeOrderId = null;
      }
    } catch (_) {}
  }

  Future<void> _persistToHive() async {
    try {
      final box = Hive.box('settings');
      if (isWatching) {
        await box.put(_orderKey, activeOrderId);
        await box.put(_amountKey, pendingAmount ?? '');
        await box.put(_balanceBeforeKey, balanceBefore ?? '');
        await box.put(_startedKey, DateTime.now().millisecondsSinceEpoch);
      } else {
        await box.delete(_orderKey);
        await box.delete(_amountKey);
        await box.delete(_balanceBeforeKey);
        await box.delete(_startedKey);
      }
    } catch (_) {}
  }

  Future<void> trackPayment({
    required String orderId,
    required String amount,
    String? balanceBeforeValue,
  }) async {
    activeOrderId = orderId;
    pendingAmount = amount;
    balanceBefore = balanceBeforeValue;
    justSucceeded = false;
    lastCreditedAmount = null;
    statusMessage =
        'Пардохт дар интизорӣ. Баъди тасдиқи бонк баланс автоматӣ нав мешавад (одатан 1–3 дақиқа).';
    _pollTick = 0;
    await _persistToHive();
    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollTick++;
      unawaited(syncNow(silent: _pollTick > 2));
      if (_pollTick >= 300) {
        _timer?.cancel();
        statusMessage =
            'Бонк боз ҳам кор мекунад. Баланс баъди тасдиқ автоматӣ нав мешавад — ба профил баред ё икони навсозиро пахш кунед.';
        notifyListeners();
      }
    });
  }

  Future<Map<String, dynamic>> syncNow({bool silent = false}) async {
    if (_syncing) {
      return {'success': false, 'busy': true};
    }
    _syncing = true;
    try {
      if (isWatching) {
        await ApiService.checkSmartpayStatus(activeOrderId!);
      }

      final sync = await ApiService.syncPendingTopUpsAndBalance();
      pendingCount = sync['pending_count'] as int? ?? 0;
      final becameSuccess = sync['became_success'] as int? ?? 0;
      final balance = sync['balance']?.toString();

      var success = false;
      if (isWatching) {
        final statusResult =
            await ApiService.checkSmartpayStatus(activeOrderId!);
        final status = statusResult['status']?.toString().toUpperCase();
        if (status == 'SUCCESS') {
          success = true;
        } else if (status == 'FAILED') {
          await _clearActive(
            message: 'Пардохт рад шуд ё бекор карда шуд.',
          );
          notifyListeners();
          return {'success': false, 'failed': true};
        }
      }

      if (!success && isWatching && balance != null && balanceBefore != null) {
        final prev = double.tryParse(balanceBefore!) ?? 0;
        final next = double.tryParse(balance) ?? 0;
        if ((next - prev).abs() > 0.009) {
          success = true;
        }
      }

      if (success || becameSuccess > 0) {
        final credited = pendingAmount ?? '';
        await _clearActive();
        justSucceeded = true;
        lastCreditedAmount = credited.isNotEmpty ? credited : null;
        statusMessage = null;
        pendingCount = sync['pending_count'] as int? ?? 0;
        notifyListeners();
        return {
          'success': true,
          'balance': balance,
          'became_success': becameSuccess + (success ? 1 : 0),
          'credited': credited,
        };
      }

      if (isWatching) {
        statusMessage =
            'Пардохт ${pendingAmount ?? ''} сомонӣ дар интизорӣ. Баъди гузаштани маблағ аз бонк баланс автоматӣ нав мешавад.';
      } else if (pendingCount > 0) {
        statusMessage =
            '$pendingCount пардохт дар интизорӣ. Баъди тасдиқи бонк баланс автоматӣ нав мешавад.';
      } else {
        statusMessage = null;
      }

      notifyListeners();
      return {
        'success': true,
        'balance': balance,
        'pending_count': pendingCount,
      };
    } finally {
      _syncing = false;
    }
  }

  Future<void> _clearActive({String? message}) async {
    activeOrderId = null;
    pendingAmount = null;
    balanceBefore = null;
    _timer?.cancel();
    _pollTick = 0;
    if (message != null) {
      statusMessage = message;
    }
    await _persistToHive();
  }

  void consumeSuccessFlag() {
    justSucceeded = false;
    lastCreditedAmount = null;
  }

  Future<void> stopWatching() async {
    await _clearActive();
    notifyListeners();
  }
}
