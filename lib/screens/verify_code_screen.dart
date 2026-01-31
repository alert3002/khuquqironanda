import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_service.dart';
import 'home_screen.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String phone;

  const VerifyCodeScreen({
    super.key,
    required this.phone,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  Timer? _timer;
  int _remainingSeconds = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _remainingSeconds = 30;
      _canResend = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _onResendPressed() async {
    if (!_canResend || _isLoading) return;

    setState(() => _isLoading = true);

    final result = await ApiService.sendCode(widget.phone);

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Код бори дигар фиристода шуд!"),
          backgroundColor: Colors.green,
        ),
      );
      _startTimer(); // Restart the 30-second timer
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? "Хатогӣ! Лутфан дубора кӯшиш кунед."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onVerifyPressed() async {
    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Лутфан коди СМС-ро ворид кунед")),
      );
      return;
    }

    setState(() => _isLoading = true);

    String code = _codeController.text.trim();
    final result = await ApiService.verifyCode(widget.phone, code);

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      // Check for device restriction error (403)
      if (result['statusCode'] == 403) {
        // Show device restriction dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("Дастгоҳ маҳдуд аст"),
              content: const Text(
                "Ин аккаунт ба дастгоҳи дигар пайваст аст. Лутфан бо админ тамос гиред.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Хуб"),
                ),
              ],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? "Код нодуруст аст!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              const Icon(Icons.sms, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              
              // Title
              const Text(
                "Коди СМС-ро ворид кунед",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              
              // Phone number display
              Text(
                widget.phone,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),

              // Code input field
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6), // Assuming 6-digit code
                ],
                decoration: const InputDecoration(
                  labelText: "Коди СМС",
                  hintText: "0000",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                onSubmitted: (_) => _onVerifyPressed(),
              ),
              const SizedBox(height: 30),

              // Verify button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onVerifyPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Тасдиқ ва Ворид",
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Resend code section
              if (!_canResend)
                Text(
                  "СМС-ро аз нав фиристодан ${_formatTime(_remainingSeconds)}",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                )
              else
                TextButton(
                  onPressed: _isLoading ? null : _onResendPressed,
                  child: const Text(
                    "СМС-ро аз нав фиристодан",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

