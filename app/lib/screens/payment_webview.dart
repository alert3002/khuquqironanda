import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
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
  final String? paymentUrl;
  final String? bottomHint;

  const PaymentWebView({
    super.key,
    this.htmlForm = '',
    this.paymentUrl,
    this.bottomHint,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  bool _paymentResolved = false;
  bool _loadFailed = false;
  String? _loadError;
  Timer? _autoRefreshTimer;
  Timer? _loadingTimeout;

  static const _safariUa =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
      'Mobile/15E148 Safari/604.1';

  @override
  void initState() {
    super.initState();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _refreshIfNeeded(),
    );
    // Агар саҳифа дер бор шавад — спиннерро пинҳон мекунем
    _loadingTimeout = Timer(const Duration(seconds: 12), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _loadingTimeout?.cancel();
    super.dispose();
  }

  WebUri? get _baseUri {
    final url = widget.paymentUrl?.trim();
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.hasScheme) {
        return WebUri('${uri.scheme}://${uri.host}/');
      }
    }
    if (widget.htmlForm.toLowerCase().contains('alif')) {
      return WebUri('https://web.alif.tj/');
    }
    if (widget.htmlForm.toLowerCase().contains('smartpay')) {
      return WebUri('https://smartpay.tj/');
    }
    return WebUri('https://books.1week.tj/');
  }

  Future<void> _loadContent(InAppWebViewController controller) async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
      _loadError = null;
    });
    _loadingTimeout?.cancel();
    _loadingTimeout = Timer(const Duration(seconds: 12), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });

    final url = widget.paymentUrl?.trim();
    final html = widget.htmlForm.trim();

    try {
      if (html.isNotEmpty) {
        // baseUrl ҳатмӣ — бе он дар iOS POST-и форма банд мешавад
        await controller.loadData(
          data: html,
          mimeType: 'text/html',
          encoding: 'utf-8',
          baseUrl: _baseUri,
        );
      } else if (url != null && url.isNotEmpty) {
        await controller.loadUrl(
          urlRequest: URLRequest(
            url: WebUri(url),
            headers: {'Accept': 'text/html,application/xhtml+xml'},
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
          _loadError = 'Пайванди пардохт нест';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadFailed = true;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    final url = widget.paymentUrl?.trim();
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // HTML form — кӯшиши кушодани action URL
    final match = RegExp(
      r'''action=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(widget.htmlForm);
    if (match != null) {
      final uri = Uri.tryParse(match.group(1)!);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Онлайн пардохт'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Дар браузер',
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser),
          ),
          IconButton(
            tooltip: 'Навсозӣ',
            onPressed: () {
              if (webViewController != null) {
                _loadContent(webViewController!);
              }
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    sharedCookiesEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    userAgent: (!kIsWeb && (Platform.isIOS || Platform.isAndroid))
                        ? _safariUa
                        : null,
                    // iOS: иҷозати navigation аз HTML form
                    allowsBackForwardNavigationGestures: true,
                  ),
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                    _loadContent(controller);
                  },
                  onLoadStart: (controller, url) {
                    if (mounted) {
                      setState(() {
                        _isLoading = true;
                        _loadFailed = false;
                      });
                    }
                    _checkPaymentStatus(url?.toString());
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress >= 85 && mounted && _isLoading) {
                      setState(() => _isLoading = false);
                    }
                  },
                  onLoadStop: (controller, url) async {
                    if (mounted) {
                      setState(() => _isLoading = false);
                    }
                    _checkPaymentStatus(url?.toString());
                    await _checkPaymentContent(controller);
                  },
                  onReceivedError: (controller, request, error) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        _loadFailed = true;
                        _loadError = error.description;
                      });
                    }
                  },
                  onReceivedHttpError: (controller, request, response) {
                    final code = response.statusCode ?? 0;
                    if (code >= 400 && mounted) {
                      setState(() {
                        _isLoading = false;
                        // 4xx на ҳамеша хато — баъзе саҳифаҳо redirect мекунанд
                        if (code >= 500) {
                          _loadFailed = true;
                          _loadError = 'Хатои сервер ($code)';
                        }
                      });
                    }
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
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
                  const ColoredBox(
                    color: Color(0x66FFFFFF),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_loadFailed && !_isLoading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            _loadError ?? 'Саҳифа бор нашуд',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              if (webViewController != null) {
                                _loadContent(webViewController!);
                              }
                            },
                            child: const Text('Аз нав кӯшиш'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _openInBrowser,
                            child: const Text('Дар Safari / браузер кушоед'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.bottomHint != null && widget.bottomHint!.isNotEmpty)
            Material(
              color: const Color(0xFF424242),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    widget.bottomHint!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _checkPaymentStatus(String? url) {
    if (_paymentResolved || url == null || url.isEmpty) return;

    final normalizedUrl = url.toLowerCase();
    PaymentResultStatus? status;
    if ((normalizedUrl.contains('orderid=') &&
            normalizedUrl.contains('dc=success')) ||
        normalizedUrl.contains('/payment/success/') ||
        normalizedUrl.contains('/payment/alif/return') ||
        (normalizedUrl.contains('/success') &&
            !normalizedUrl.contains('unsuccess')) ||
        normalizedUrl.contains('success=true')) {
      status = PaymentResultStatus.success;
    }

    if (status == null &&
        (normalizedUrl.contains('/payment/cancel/') ||
            normalizedUrl.contains('cancel=true'))) {
      status = PaymentResultStatus.canceled;
    }

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
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Барнома барои кушодани пайванд ёфт нашуд'),
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
    _loadingTimeout?.cancel();
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
      'успешно оплачен',
    ];
    final canceledTokens = [
      'бекор карда шуд',
      'отменена',
      'payment cancelled',
      'payment canceled',
    ];
    final failedTokens = [
      'пардохт рад шуд',
      'оплата отклонена',
      'payment failed',
      'payment declined',
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
