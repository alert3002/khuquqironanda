import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
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
  WebViewController? _webViewController;
  bool _isLoading = true;
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
        _isLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      _error = e.toString();
      _isLoading = false;
    });
  }
}

  void _initializeWebView(String htmlForm) {
    try {
      // Сохтани WebViewController
      _webViewController = WebViewController();
      
      // setJavaScriptMode танҳо барои платформаҳое, ки онро дастгирӣ мекунанд
      try {
        if (!kIsWeb) {
          _webViewController!.setJavaScriptMode(JavaScriptMode.unrestricted);
        }
      } catch (e) {
        // Агар setJavaScriptMode дастгирӣ нашавад (мас. Windows), онро нодида мегирем
        print('setJavaScriptMode not supported on this platform: $e');
      }
      
      _webViewController!
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
              
              // Санҷиш: Оё ба callback URL гузаронида шудем?
              if (url.contains('/payment/success/')) {
                _handlePaymentSuccess();
              } else if (url.contains('/payment/cancel/')) {
                _handlePaymentCancel();
              } else if (url.contains('/payment/decline/')) {
                _handlePaymentDecline();
              }
            },
            onWebResourceError: (WebResourceError error) {
              setState(() {
                _error = 'Хатогии пайвастшавӣ: ${error.description}';
                _isLoading = false;
              });
            },
          ),
        )
        ..loadRequest(
          Uri.dataFromString(
            htmlForm,
            mimeType: 'text/html',
            encoding: Encoding.getByName('utf-8'),
          ),
        );

      setState(() {
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Хатогӣ ҳангоми омодасозии WebView: $e';
        _isLoading = false;
      });
    }
  }

  void _handlePaymentSuccess() {
    // Навсозии баланс
    if (widget.onPaymentSuccess != null) {
      widget.onPaymentSuccess!();
    }
    
    // Намоиши пайғоми муваффақият
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Муваффақият'),
          content: const Text('Пардохт бомуваффақият анҷом шуд!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Пӯшидани диалог
                Navigator.of(context).pop(); // Баргаштан ба саҳифаи қаблӣ
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _handlePaymentCancel() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Пардохт бекор шуд'),
          content: const Text('Шумо пардохтро бекор кардед.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _handlePaymentDecline() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Пардохт рад шуд'),
          content: const Text('Пардохт рад карда шуд. Лутфан дубора кӯшиш кунед.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
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
                        _isLoading = true;
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
              : _webViewController != null
                  ? Stack(
                      children: [
                        WebViewWidget(controller: _webViewController!),
                        if (_isLoading)
                          Container(
                            color: Colors.white,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Интизор шавед...'),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
    );
  }
}
