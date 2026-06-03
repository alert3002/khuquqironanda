import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_service.dart';
import '../data/smartpay_banks.dart';
import '../models/user_model.dart';
import '../utils/region_utils.dart';
import 'payment_webview.dart';

class SmartPayPaymentScreen extends StatefulWidget {
  final double? initialAmount;
  final String? paymentDescription;
  final User? user;

  const SmartPayPaymentScreen({
    super.key,
    this.initialAmount,
    this.paymentDescription,
    this.user,
  });

  @override
  State<SmartPayPaymentScreen> createState() => _SmartPayPaymentScreenState();
}

class _SmartPayPaymentScreenState extends State<SmartPayPaymentScreen>
    with WidgetsBindingObserver {
  static const _primary = Color(0xFF1565C0);
  static const _surface = Color(0xFFF5F7FA);
  static const _card = Colors.white;

  final TextEditingController _amountController = TextEditingController();
  int? _selectedBankId;
  bool _isPaying = false;
  String? _pendingOrderId;
  String? _balanceBefore;
  Timer? _pollTimer;
  User? _user;

  TextStyle get _titleStyle =>
      GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.black87);
  TextStyle get _bodyStyle =>
      GoogleFonts.montserrat(fontWeight: FontWeight.w500, color: Colors.black54);
  TextStyle get _labelStyle =>
      GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13);

  bool get _showBanks => isTajikistanUser(_user ?? widget.user);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _user = widget.user;
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(2);
    }
    _loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingOrderId != null) {
      _pollPaymentStatus();
    }
  }

  Future<void> _loadProfile() async {
    final user = await ApiService.getUserProfile();
    if (!mounted) return;
    setState(() => _user = user);
  }

  Future<void> _payNow() async {
    final amountText = _amountController.text.trim().replaceAll(',', '.');
    if (amountText.isEmpty) {
      _snack('Лутфан маблағро ворид кунед');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _snack('Маблағи нодуруст');
      return;
    }

    if (_showBanks && _selectedBankId == null) {
      _snack('Бонкро интихоб кунед');
      return;
    }

    final bank = smartPayBankByUiId(_selectedBankId);

    setState(() => _isPaying = true);
    _balanceBefore = _user?.balance;

    try {
      final result = await ApiService.initSmartpayPayment(
        amount,
        description: widget.paymentDescription,
        bankId: _showBanks ? bank?.deeplinkBankId : null,
      );

      if (!mounted) return;
      setState(() => _isPaying = false);

      if (result['success'] != true) {
        _snack(result['error']?.toString() ?? 'Хатогӣ дар оғози пардохт', error: true);
        return;
      }

      final orderId = result['order_id']?.toString();
      final deeplink = result['deeplink_url']?.toString();
      final paymentLink = result['payment_link']?.toString();

      if (orderId != null && orderId.isNotEmpty) {
        _pendingOrderId = orderId;
        _startPolling();
      }

      if (deeplink != null && deeplink.isNotEmpty) {
        await _openDeeplink(deeplink, paymentLink);
        return;
      }

      if (paymentLink != null && paymentLink.isNotEmpty) {
        await _openWebPayment(paymentLink, htmlForm: result['html_form']?.toString());
        return;
      }

      _snack('Пайванди пардохт дастрас нест', error: true);
    } catch (e) {
      if (mounted) {
        setState(() => _isPaying = false);
        _snack('Хатогии пайвастшавӣ: $e', error: true);
      }
    }
  }

  Future<void> _openDeeplink(String deeplink, String? paymentLink) async {
    final uri = Uri.parse(deeplink);
    var opened = false;
    try {
      opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }

    // Дар iOS launchUrl зиёд вақт false бармегардонад, ҳатто вақте ки бонк кушода мешавад.
    if (Platform.isIOS) {
      if (!opened && paymentLink != null && paymentLink.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 2500));
        if (!mounted) return;
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle != AppLifecycleState.resumed) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Барномаи бонк ёфт нашуд. Пардохти веб кушода мешавад...',
                style: _bodyStyle.copyWith(color: Colors.white),
              ),
            ),
          );
        }
        await _openWebPayment(paymentLink);
      }
      return;
    }

    if (!opened && paymentLink != null && paymentLink.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Барномаи бонк ёфт нашуд. Пардохти веб кушода мешавад...',
              style: _bodyStyle.copyWith(color: Colors.white),
            ),
          ),
        );
      }
      await _openWebPayment(paymentLink);
    }
  }

  Future<void> _openWebPayment(String paymentLink, {String? htmlForm}) async {
    final paymentResult = await Navigator.push<PaymentResultStatus>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentWebView(
          htmlForm: htmlForm ?? '',
          paymentUrl: htmlForm == null || htmlForm.isEmpty ? paymentLink : null,
        ),
      ),
    );

    if (!mounted) return;

    if (paymentResult == PaymentResultStatus.success) {
      await _onPaymentSuccess();
    } else if (paymentResult == PaymentResultStatus.failed) {
      _snack('Пардохт рад шуд', error: true);
    } else if (paymentResult == PaymentResultStatus.canceled) {
      _snack('Пардохт бекор шуд', error: true);
    } else {
      await _pollPaymentStatus(showSnackOnSuccess: true);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollPaymentStatus(showSnackOnSuccess: true);
    });
  }

  Future<void> _pollPaymentStatus({bool showSnackOnSuccess = false}) async {
    final orderId = _pendingOrderId;
    if (orderId == null) return;

    final statusResult = await ApiService.checkSmartpayStatus(orderId);
    final status = statusResult['status']?.toString().toUpperCase();

    if (status == 'SUCCESS') {
      _pollTimer?.cancel();
      _pendingOrderId = null;
      if (showSnackOnSuccess) await _onPaymentSuccess();
      return;
    }
    if (status == 'FAILED') {
      _pollTimer?.cancel();
      _pendingOrderId = null;
      if (mounted) _snack('Пардохт рад шуд', error: true);
      return;
    }

    await _refreshBalanceIfChanged();
  }

  Future<void> _refreshBalanceIfChanged() async {
    final user = await ApiService.getUserProfile();
    if (!mounted || user == null) return;

    final prev = double.tryParse(_balanceBefore ?? '0') ?? 0;
    final next = double.tryParse(user.balance) ?? 0;
    if ((next - prev).abs() > 0.01) {
      _pollTimer?.cancel();
      _pendingOrderId = null;
      setState(() => _user = user);
      await _onPaymentSuccess();
    }
  }

  Future<void> _onPaymentSuccess() async {
    await _loadProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Баланс пур шуд!', style: _bodyStyle.copyWith(color: Colors.white)),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: _bodyStyle.copyWith(color: Colors.white)),
        backgroundColor: error ? Colors.red.shade600 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.montserratTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          title: Text('Пардохт', style: _titleStyle.copyWith(color: Colors.white)),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBalanceCard(),
                const SizedBox(height: 24),
                Text('Маблағ (TJS)', style: _labelStyle),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _card,
                    hintText: '0.00',
                    hintStyle: _bodyStyle,
                    suffixText: 'сомонӣ',
                    suffixStyle: _bodyStyle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                  ),
                ),
                if (_showBanks) ...[
                  const SizedBox(height: 28),
                  Text('Бонкро интихоб кунед', style: _labelStyle),
                  const SizedBox(height: 12),
                  _buildBankGrid(),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isPaying ? null : _payNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    child: _isPaying
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Пардохт кардан',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Пас аз пардохт дар барномаи бонк, баланс ба таври худкор навсозӣ мешавад.',
                  textAlign: TextAlign.center,
                  style: _bodyStyle.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = _user?.balance ?? widget.user?.balance ?? '0';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Тавозун', style: _bodyStyle.copyWith(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            '$balance сомонӣ',
            style: GoogleFonts.montserrat(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemCount: smartPayBanks.length,
      itemBuilder: (context, index) {
        final bank = smartPayBanks[index];
        final selected = _selectedBankId == bank.uiId;
        return Material(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => setState(() => _selectedBankId = bank.uiId),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _primary : Colors.grey.shade200,
                  width: selected ? 2.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 52,
                          width: 52,
                          child: Image.asset(
                            bank.iconAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.account_balance,
                              color: selected ? _primary : Colors.grey,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                      if (selected)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bank.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected ? _primary : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
