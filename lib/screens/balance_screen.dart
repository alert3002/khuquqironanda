import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_service.dart';
import '../data/smartpay_banks.dart';
import '../models/user_model.dart';
import '../services/pending_topup_watcher.dart';
import '../utils/region_utils.dart';
import '../widgets/pending_topup_banner.dart';
import 'payment_history_screen.dart';
import 'payment_webview.dart';

class BalanceScreen extends StatefulWidget {
  final double? initialAmount;
  final String? paymentDescription;
  final bool autoStartPayment;

  const BalanceScreen({
    super.key,
    this.initialAmount,
    this.paymentDescription,
    this.autoStartPayment = false,
  });

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> with WidgetsBindingObserver {
  User? _user;
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _amountController = TextEditingController();
  int? _selectedBankId;
  bool _isPaying = false;
  String? _balanceBefore;
  late final PendingTopUpWatcher _watcher;

  bool get _useSmartPayWallets => isTajikistanUser(_user);

  @override
  void initState() {
    super.initState();
    _watcher = PendingTopUpWatcher.instance;
    _watcher.addListener(_onWatcherUpdate);
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    }
    _loadUserProfile();
    unawaited(_watcher.syncNow(silent: true));
  }

  void _onWatcherUpdate() {
    if (!mounted) return;
    setState(() {});
    if (_watcher.justSucceeded) {
      final amount = _watcher.lastCreditedAmount;
      _watcher.consumeSuccessFlag();
      unawaited(_loadUserProfile());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            amount != null && amount.isNotEmpty
                ? 'Баланс пур шуд! +$amount сомонӣ'
                : 'Баланс пур шуд!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _watcher.removeListener(_onWatcherUpdate);
    WidgetsBinding.instance.removeObserver(this);
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _watcher.hasPending) {
      unawaited(_watcher.syncNow());
    }
  }

  Future<void> _refreshBalanceFromServer() async {
    final sync = await _watcher.syncNow();
    final user = await ApiService.getUserProfile();
    if (!mounted) return;
    setState(() => _user = user);
    final pending = sync['pending_count'] as int? ?? _watcher.pendingCount;
    if (pending > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Баланс: ${user?.balance ?? "0"} сомонӣ. '
            'Пардохт дар интизорӣ — баъди тасдиқи бонк автоматӣ нав мешавад.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Баланс навсозӣ шуд: ${user?.balance ?? "0"} сомонӣ'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _loadUserProfile() async {
    final cached = await ApiService.getUserProfileCached();
    if (mounted && cached != null) {
      setState(() {
        _user = cached;
        _errorMessage = null;
        _isLoading = false;
      });
    }

    final user = await ApiService.getUserProfile();
    if (mounted) {
      setState(() {
        _user = user ?? cached;
        _errorMessage = _user == null ? ApiService.lastAuthErrorMessage : null;
        _isLoading = false;
      });
    }
  }

  double? _parseAmount() {
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    if (amountText.isEmpty) return null;
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return null;
    return amount;
  }

  /// SmartPay ҳадди ақал 2 сомонӣ талаб мекунад.
  static const double _minTopUpAmount = 2.0;

  String _friendlyPaymentError(Object? raw) {
    final text = raw?.toString() ?? '';
    final lower = text.toLowerCase();
    if (lower.contains('минимальн') ||
        lower.contains('минимал') ||
        (lower.contains('min') && lower.contains('2')) ||
        lower.contains('2 сомон')) {
      return 'Минималӣ $_minTopUpAmount сомонӣ ворид кунед';
    }
    // Агар JSON/dict пурра омада бошад — танҳо message-ро гиред
    final msgMatch = RegExp(
      r'''message['":\s]+['"]([^'"]+)''',
      caseSensitive: false,
    ).firstMatch(text);
    if (msgMatch != null) {
      final m = msgMatch.group(1) ?? '';
      if (m.toLowerCase().contains('минимальн') || m.contains('2 сомон')) {
        return 'Минималӣ $_minTopUpAmount сомонӣ ворид кунед';
      }
      if (m.length < 120) return m;
    }
    if (text.length > 160) {
      return 'Пардохт оғоз нашуд. Маблағро санҷед ва боз кӯшиш кунед.';
    }
    return text.isEmpty ? 'Хатогӣ дар оғози пардохт' : text;
  }

  bool _ensureMinAmount(double amount) {
    if (amount + 1e-9 < _minTopUpAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Минималӣ ${_minTopUpAmount.toStringAsFixed(0)} сомонӣ ворид кунед',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return false;
    }
    return true;
  }


  Future<void> _submitPayment() async {
    final amount = _parseAmount();
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Лутфан маблағи дурустро ворид кунед'),
        ),
      );
      return;
    }
    if (!_ensureMinAmount(amount)) return;

    // Агар Alif интихоб шуда бошад → пардохти Alif Банк (Корти Милли)
    if (_useSmartPayWallets && _selectedBankId == 1) {
      await _startAlifPayment(amount);
      return;
    }

    // Тугмаи «Пардохт» — саҳифаи SmartPay (веб)
    if (_useSmartPayWallets) {
      await _startSmartPayPayment(amount, openSmartPayPage: true);
      return;
    }

    await _processPaymentLegacy(amount);
  }

  Future<void> _onWalletTap(SmartPayBank bank) async {
    setState(() => _selectedBankId = bank.uiId);
    final amount = _parseAmount();
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Аввал маблағро ворид кунед')),
      );
      return;
    }
    if (!_ensureMinAmount(amount)) return;
    // Alif → web.alif.tj | SmartPay → саҳифаи SmartPay (ҳамаи бонкҳо)
    if (bank.isAlif) {
      await _startAlifPayment(amount);
      return;
    }
    await _startSmartPayPayment(amount, openSmartPayPage: true);
  }

  Future<void> _startAlifPayment(double amount) async {
    if (_isPaying) return;

    setState(() => _isPaying = true);
    _balanceBefore = _user?.balance;

    try {
      final result = await ApiService.initAlifPayment(
        amount,
        description: widget.paymentDescription ??
            'Пур кардани баланси барномаи ҳуқуқи ронанда: ${amount.toStringAsFixed(2)} сомонӣ',
      );

      if (!mounted) return;
      setState(() => _isPaying = false);

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyPaymentError(
                result['error'] ?? 'Хатогӣ дар оғози пардохти Alif',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final orderId = result['order_id']?.toString();
      final htmlForm = result['html_form']?.toString();
      final paymentLink = result['payment_link']?.toString() ??
          result['payment_url']?.toString();

      if (orderId != null && orderId.isNotEmpty) {
        await _watcher.trackPayment(
          orderId: orderId,
          amount: amount.toStringAsFixed(2),
          balanceBeforeValue: _balanceBefore,
        );
      }

      if ((htmlForm != null && htmlForm.isNotEmpty) ||
          (paymentLink != null && paymentLink.isNotEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Саҳифаи Alif Банк кушода мешавад. Баъди пардохт баланс автоматӣ нав мешавад.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        await _openWebPayment(paymentLink ?? '', htmlForm: htmlForm);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пайванди Alif дастрас нест'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хатогии пайвастшавӣ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startSmartPayPayment(
    double amount, {
    int? bankId,
    bool openSmartPayPage = false,
  }) async {
    if (_isPaying) return;

    setState(() => _isPaying = true);
    _balanceBefore = _user?.balance;

    try {
      final result = await ApiService.initSmartpayPayment(
        amount,
        description: widget.paymentDescription,
        bankId: openSmartPayPage ? null : bankId,
      );

      if (!mounted) return;
      setState(() => _isPaying = false);

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyPaymentError(
                result['error'] ?? 'Хатогӣ дар оғози пардохт',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final orderId = result['order_id']?.toString();
      final deeplink = result['deeplink_url']?.toString();
      final paymentLink = result['payment_link']?.toString();

      if (orderId != null && orderId.isNotEmpty) {
        await _watcher.trackPayment(
          orderId: orderId,
          amount: amount.toStringAsFixed(2),
          balanceBeforeValue: _balanceBefore,
        );
      }

      // Тугмаи Пардохт → саҳифаи SmartPay
      if (openSmartPayPage) {
        if (paymentLink != null && paymentLink.isNotEmpty) {
          await _openWebPayment(
            paymentLink,
            htmlForm: result['html_form']?.toString(),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Пайванди SmartPay дастрас нест'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (deeplink != null && deeplink.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Барномаи бонк кушода мешавад. Баъди пардохт баланс автоматӣ нав мешавад.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        await _openDeeplink(deeplink, paymentLink);
        return;
      }

      if (paymentLink != null && paymentLink.isNotEmpty) {
        await _openWebPayment(
          paymentLink,
          htmlForm: result['html_form']?.toString(),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пайванди пардохт дастрас нест'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хатогии пайвастшавӣ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openDeeplink(String deeplink, String? paymentLink) async {
    final uri = Uri.parse(deeplink);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (Platform.isIOS) {
      if (!opened && paymentLink != null && paymentLink.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 2500));
        if (!mounted) return;
        if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Барномаи бонк ёфт нашуд. Пардохти веб кушода мешавад...'),
          ),
        );
        await _openWebPayment(paymentLink);
      }
      return;
    }

    if (!opened && paymentLink != null && paymentLink.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Барномаи бонк ёфт нашуд. Пардохти веб кушода мешавад...'),
        ),
      );
      await _openWebPayment(paymentLink);
    }
  }

  Future<void> _openWebPayment(String paymentLink, {String? htmlForm}) async {
    final isAlif = (htmlForm ?? '').toLowerCase().contains('alif') ||
        paymentLink.toLowerCase().contains('alif');
    final paymentResult = await Navigator.push<PaymentResultStatus>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentWebView(
          htmlForm: htmlForm ?? '',
          paymentUrl: paymentLink.isNotEmpty ? paymentLink : null,
          bottomHint: isAlif
              ? 'Саҳифаи Alif Банк кушода мешавад. Баъди пардохт баланс автоматӣ нав мешавад.'
              : 'Саҳифаи SmartPay кушода мешавад. Баъди пардохт баланс автоматӣ нав мешавад.',
        ),
      ),
    );

    if (!mounted) return;

    // Баъди бозгашт аз SmartPay — фавран статус ва балансро навсозӣ
    final sync = await _watcher.syncNow();
    await _loadUserProfile();

    if (!mounted) return;

    if (paymentResult == PaymentResultStatus.success ||
        _watcher.justSucceeded ||
        ((sync['became_success'] as int? ?? 0) > 0)) {
      // Snack аз watcher меояд агар justSucceeded
      if (!_watcher.justSucceeded) {
        _showSnack('Баланс навсозӣ шуд: ${_user?.balance ?? "0"} сомонӣ');
      }
    } else if (paymentResult == PaymentResultStatus.failed) {
      _showSnack('Пардохт рад шуд', error: true);
    } else if (paymentResult == PaymentResultStatus.canceled) {
      _showSnack('Пардохт бекор шуд', error: true);
    } else if (_watcher.hasPending) {
      _showSnack(
        'Пардохт дар интизорӣ. Баланс баъди тасдиқи SmartPay автоматӣ пур мешавад.',
      );
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _processPaymentLegacy(double amount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await ApiService.initSmartpayPayment(
        amount,
        description: widget.paymentDescription,
      );

      if (mounted) Navigator.of(context).pop();

      final balanceBefore = _user?.balance;
      final htmlForm = result['html_form']?.toString();
      final paymentLink = result['payment_link']?.toString();

      if (result['success'] == true &&
          ((htmlForm != null && htmlForm.isNotEmpty) ||
              (paymentLink != null && paymentLink.isNotEmpty))) {
        final paymentResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebView(
              htmlForm: htmlForm ?? '',
              paymentUrl:
                  (htmlForm == null || htmlForm.isEmpty) ? paymentLink : null,
            ),
          ),
        );

        if (!mounted) return;
        if (paymentResult == PaymentResultStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Баланс пур шуд!'),
              backgroundColor: Colors.green,
            ),
          );
          await _refreshBalanceAfterPayment(previousBalance: balanceBefore);
        } else if (paymentResult == PaymentResultStatus.failed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пардохт рад шуд'),
              backgroundColor: Colors.red,
            ),
          );
        } else if (paymentResult == PaymentResultStatus.canceled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пардохт бекор шуд'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Хатогӣ дар оғози пардохт'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хатогии пайвастшавӣ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshBalanceAfterPayment({String? previousBalance}) async {
    const maxAttempts = 5;
    const delay = Duration(seconds: 2);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      await Future.delayed(delay);
      await _loadUserProfile();
      final newBalance = _user?.balance;
      final prevValue =
          previousBalance != null ? double.tryParse(previousBalance) : null;
      final newValue = newBalance != null ? double.tryParse(newBalance) : null;
      if (newValue != null && prevValue == null) return;
      if (newValue != null && prevValue != null) {
        if ((newValue - prevValue).abs() > 0.01) return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Баланс ва Пардохт')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _errorMessage ??
                          'Маълумоти профил дастрас нест. Лутфан дубора ворид шавед.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      PendingTopUpBanner(watcher: _watcher),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Тавозун:',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_user?.balance ?? '0'} сомонӣ',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Навсозии баланс',
                              onPressed: _isPaying ? null : _refreshBalanceFromServer,
                              icon: const Icon(Icons.refresh_rounded, size: 22),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Усули пардохт:',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_useSmartPayWallets)
                        _buildSelectableWallets()
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildWalletLogo('assets/smartpay/alif.png'),
                            _buildWalletLogo('assets/smartpay/smartpay.png'),
                          ],
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Маблағ (сомонӣ)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isPaying ? null : _submitPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isPaying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Пардохт',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                      if (_useSmartPayWallets) ...[
                        const SizedBox(height: 10),
                        Text(
                          _selectedBankId == 1
                              ? 'Alif — пардохт бо Корти Милли'
                              : _selectedBankId == 2
                                  ? 'SmartPay — бо ҳамаи ҳамёни бонкҳо'
                                  : 'Alif ё SmartPay-ро интихоб кунед, ё «Пардохт» пахш кунед',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PaymentHistoryScreen(),
                              ),
                            );
                          },
                          child: const Text('Историяи пардохт'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Бозгашт'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAutoUpdateHint(),
                      // Ёрии чек — дар профил болои баланс нишон дода мешавад
                    ],
                  ),
                ),
    );
  }

  Widget _buildAutoUpdateHint() {
    return Text(
      'Баъди пардохт баланс автоматӣ нав мешавад. '
      'Агар нагузашт — дар профил чекро ба админ фиристед.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
    );
  }

  Widget _buildSelectableWallets() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: smartPayBanks.map((bank) {
        final selected = _selectedBankId == bank.uiId;
        final accent = bank.isSmartPay
            ? const Color(0xFF0D7377)
            : const Color(0xFF00A651);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Material(
              color: Colors.white,
              elevation: selected ? 4 : 1,
              shadowColor: accent.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: _isPaying ? null : () => _onWalletTap(bank),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? accent : const Color(0xFFE8ECF1),
                      width: selected ? 2.2 : 1,
                    ),
                    gradient: selected
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              accent.withValues(alpha: 0.10),
                              Colors.white,
                            ],
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      if (bank.isSmartPay)
                        Container(
                          width: double.infinity,
                          height: 64,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D7377),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D7377)
                                    .withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            bank.iconAsset,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text(
                                'SmartPay',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 64,
                          height: 64,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF14C45A),
                                Color(0xFF00A651),
                                Color(0xFF008C44),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00A651)
                                    .withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              bank.iconAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        bank.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: selected ? accent : const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (bank.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          bank.subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? accent.withValues(alpha: 0.95)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWalletLogo(String assetPath) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_wallet),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
