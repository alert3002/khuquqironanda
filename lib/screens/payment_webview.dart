import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

enum PaymentResultStatus {
  success,
  failed,
  canceled,
}

class PaymentWebView extends StatefulWidget {
  final String htmlForm;

  const PaymentWebView({
    super.key,
    required this.htmlForm,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  bool _paymentResolved = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _refreshIfNeeded(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Онлайн пардохт"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _refreshIfNeeded,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              useShouldOverrideUrlLoading: true,
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
              // Load the HTML form data
              controller.loadData(
                data: widget.htmlForm,
                mimeType: 'text/html',
                encoding: 'utf-8',
              );
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
              });
              _checkPaymentStatus(url?.toString());
            },
            onLoadStop: (controller, url) async {
              setState(() {
                _isLoading = false;
              });
              _checkPaymentStatus(url?.toString());
              await _checkPaymentContent(controller);
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString();
              _checkPaymentStatus(url);

              if (url != null && url.isNotEmpty) {
                final uri = Uri.parse(url);
                final scheme = uri.scheme.toLowerCase();
                if (scheme != 'http' && scheme != 'https') {
                  await _launchExternalUrl(url);
                  return NavigationActionPolicy.CANCEL;
                }
              }

              return NavigationActionPolicy.ALLOW;
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  void _checkPaymentStatus(String? url) {
    if (_paymentResolved || url == null || url.isEmpty) return;

    // Check for successful payment:
    // 1. DC Bank: URL contains orderId= and dc=success
    // 2. SmartPay or general: URL contains /success or success=true
    final normalizedUrl = url.toLowerCase();
    PaymentResultStatus? status;
    if ((normalizedUrl.contains('orderid=') && normalizedUrl.contains('dc=success')) ||
        normalizedUrl.contains('/payment/success/') ||
        normalizedUrl.contains('/success') ||
        normalizedUrl.contains('success=true')) {
      status = PaymentResultStatus.success;
    }

    // Check for canceled payment:
    if (status == null &&
        (normalizedUrl.contains('/payment/cancel/') ||
            normalizedUrl.contains('cancel=true'))) {
      status = PaymentResultStatus.canceled;
    }

    // Check for failed payment:
    if (status == null &&
        (normalizedUrl.contains('dc=fail') ||
            normalizedUrl.contains('/payment/fail/') ||
            normalizedUrl.contains('fail=true') ||
            normalizedUrl.contains('/decline') ||
            normalizedUrl.contains('decline=true'))) {
      status = PaymentResultStatus.failed;
    }

    if (status != null) {
      _resolvePayment(status);
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    final fallback = _extractFallbackUrl(url);
    final candidates = <Uri>[
      Uri.parse(url),
      if (fallback != null) Uri.parse(fallback),
    ];

    for (final candidate in candidates) {
      try {
        final launched = await launchUrl(
          candidate,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {
        // Try the next candidate (e.g., browser fallback)
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Барнома барои кушодани пайванд ёфт нашуд"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _extractFallbackUrl(String url) {
    final key = 'browser_fallback_url=';
    final start = url.indexOf(key);
    if (start == -1) return null;
    var value = url.substring(start + key.length);
    final end = value.indexOf(';');
    if (end != -1) {
      value = value.substring(0, end);
    }
    return Uri.decodeComponent(value);
  }

  void _refreshIfNeeded() {
    if (_paymentResolved || _isLoading) return;
    webViewController?.reload();
  }

  void _resolvePayment(PaymentResultStatus status) {
    if (_paymentResolved || !mounted) return;
    _paymentResolved = true;
    _autoRefreshTimer?.cancel();
    Navigator.pop(context, status);
  }

  Future<void> _checkPaymentContent(InAppWebViewController controller) async {
    if (_paymentResolved) return;

    String? text;
    try {
      final result = await controller.evaluateJavascript(
        source: 'document.body ? document.body.innerText : ""',
      );
      if (result is String) {
        text = result;
      }
    } catch (_) {
      return;
    }

    if (text == null || text.trim().isEmpty) return;

    final normalized = text.toLowerCase();
    final successTokens = [
      'пардохт шуд',
      'пардохт қабул шуд',
      'оплата прошла',
      'оплата принята',
      'success',
      'successful',
      'succes',
      'успешно',
    ];
    final canceledTokens = [
      'бекор',
      'отмена',
      'cancelled',
      'canceled',
      'cancel',
    ];
    final failedTokens = [
      'рад шуд',
      'fail',
      'failed',
      'отказ',
      'ошибка',
      'decline',
    ];

    if (successTokens.any(normalized.contains)) {
      _resolvePayment(PaymentResultStatus.success);
      return;
    }
    if (canceledTokens.any(normalized.contains)) {
      _resolvePayment(PaymentResultStatus.canceled);
      return;
    }
    if (failedTokens.any(normalized.contains)) {
      _resolvePayment(PaymentResultStatus.failed);
    }
  }
}
