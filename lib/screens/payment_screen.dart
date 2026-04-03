import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../api/api_service.dart';
import 'payment_webview.dart';

class PaymentScreen extends StatefulWidget {
  final double amount;
  final int? bookId;
  final VoidCallback? onPaymentSuccess;

  const PaymentScreen({
    super.key,
    required this.amount,
    this.bookId,
    this.onPaymentSuccess,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
  try {
    // Агар шумо барои Алиф тугма сохта бошед, бояд ApiService.initAlifPayment-ро ҷеғ занед
    // Ман як логикаи оддиро менависам:
    final result = await ApiService.initAlifPayment(widget.amount); 

    if (result['html_form'] != null) {
      final htmlForm = result['html_form'] as String;
      
      // Истифодаи PaymentWebView (ки аллакай дар лоиҳаи шумо ҳаст)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentWebView(htmlForm: htmlForm),
          ),
        );
      }
    } else {
      setState(() {
        _error = "Хатогӣ дар гирифтани формаи пардохт";
      });
    }
  } catch (e) {
    setState(() {
      _error = e.toString();
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пардохт ба воситаи DC Bank'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Пардохтро бекор мекунед?'),
                content: const Text('Агар шумо саҳифаро тарк кунед, пардохт бекор мешавад.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Бекор кардан'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Ха, бекор кардан'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                      _initializePayment();
                    },
                    child: const Text('Дубора кӯшиш кардан'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Баргаштан'),
                  ),
                ],
              ),
            )
          : kIsWeb
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      const Text('Пардохт дар табаи нави браузер кушода шуд.'),
                      const SizedBox(height: 16),
                      const Text('Лутфан пас аз анҷоми пардохт ба ин саҳифа баргардед.'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          if (widget.onPaymentSuccess != null) {
                            widget.onPaymentSuccess!();
                          }
                          Navigator.of(context).pop();
                        },
                        child: const Text('Пардохтро анҷом додам'),
                      ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
