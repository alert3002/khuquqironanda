  import 'package:flutter/material.dart';
  import 'package:url_launcher/url_launcher.dart';
  import '../api/api_service.dart';
  import '../models/user_model.dart';
  import 'payment_webview.dart';
  import 'payment_history_screen.dart';

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

  class _BalanceScreenState extends State<BalanceScreen> {
    User? _user;
    bool _isLoading = true;
    final TextEditingController _amountController = TextEditingController();

    @override
    void initState() {
      super.initState();
      if (widget.initialAmount != null && widget.initialAmount! > 0) {
        _amountController.text = widget.initialAmount!.toStringAsFixed(2);
      }
      _loadUserProfile();
      if (widget.autoStartPayment && (widget.initialAmount ?? 0) > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _submitPayment();
        });
      }
    }

    @override
    void dispose() {
      _amountController.dispose();
      super.dispose();
    }

    Future<void> _loadUserProfile() async {
      final user = await ApiService.getUserProfile();
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    }

    Future<void> _refreshBalanceAfterPayment({String? previousBalance}) async {
      const maxAttempts = 5;
      const delay = Duration(seconds: 2);

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        await Future.delayed(delay);
        await _loadUserProfile();
        final newBalance = _user?.balance;
        final prevValue = previousBalance != null ? double.tryParse(previousBalance) : null;
        final newValue = newBalance != null ? double.tryParse(newBalance) : null;
        if (newValue != null && prevValue == null) return;
        if (newValue != null && prevValue != null) {
          if ((newValue - prevValue).abs() > 0.01) return;
        }
      }
    }

    Future<void> _submitPayment() async {
      final amountText = _amountController.text.trim();
      if (amountText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Лутфан маблағро ворид кунед')),
        );
        return;
      }

      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Маблағи нодуруст')),
        );
        return;
      }

      await _processPayment(amount);
    }

    // Умумии функсия барои иҷрои пардохт
    Future<void> _processPayment(
      double amount,
    ) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final result = await ApiService.initSmartpayPayment(
          amount,
          description: widget.paymentDescription,
        );

        if (mounted) {
          Navigator.of(context).pop();
        }

        final balanceBefore = _user?.balance;
        if (result['success'] == true && result['html_form'] != null) {
          final paymentResult = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentWebView(
                htmlForm: result['html_form'],
              ),
            ),
          );

          if (mounted) {
            if (paymentResult == PaymentResultStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Баланс пур шуд!"),
                  backgroundColor: Colors.green,
                ),
              );
              await _refreshBalanceAfterPayment(previousBalance: balanceBefore);
            } else if (paymentResult == PaymentResultStatus.failed) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Пардохт рад шуд"),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (paymentResult == PaymentResultStatus.canceled) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Пардохт бекор шуд"),
                  backgroundColor: Colors.red,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Пардохт анҷом нашуд"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['error'] ?? 'Хатогӣ дар оғози пардохт'),
                backgroundColor: Colors.red,
              ),
            );
          }
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

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: const Text("Баланс ва Пардохт")),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Тавозун:",
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${_user?.balance ?? '0'} сомонӣ",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Пур кардани баланси барномаи ҲУҚУҚИ РОНАНДА бо ҳамёнҳои:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildWalletLogo('img/wallet_2.webp'),
                        _buildWalletLogo('img/wallet_3.webp'),
                        _buildWalletLogo('img/wallet_5.webp'),
                        _buildWalletLogo('img/wallet_4.webp'),
                        _buildWalletLogo('img/wallet_6.webp'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Маблағ (сомонӣ)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "Пардохт",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PaymentHistoryScreen(),
                            ),
                          );
                        },
                        child: const Text("Историяи пардохт"),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Бозгашт"),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Агар пардохт кардеду балансатон пур нашуд чеки пардохторо ба администратори баронма равон кунед!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => _openUrl('https://t.me/group1week'),
                          icon: Image.asset(
                            'img/telegram.png',
                            width: 28,
                            height: 28,
                            errorBuilder: (_, __, ___) => const Icon(Icons.telegram_outlined),
                            color: const Color.fromARGB(255, 23, 146, 247),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => _openUrl('https://wa.me/+992987003002'),
                          icon: Image.asset(
                            'img/whatsapp.png',
                            width: 28,
                            height: 28,
                            errorBuilder: (_, __, ___) => const Icon(Icons.chat),
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
