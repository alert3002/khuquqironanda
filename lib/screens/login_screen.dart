import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_service.dart';
import 'verify_code_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false; // Оё ҳозир боргирӣ рафта истодааст?

  // Функсия барои тугмаи "Ирсоли СМС"
  void _onSendPressed() async {
    setState(() => _isLoading = true);
    String phoneDigits = _phoneController.text.trim();
    
    // Validate phone number is exactly 9 digits
    if (phoneDigits.length != 9) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Лутфан рақами телефони 9-рақамаро ворид кунед")),
      );
      return;
    }
    
    // Prepend +992 to the 9 digits
    String phone = '+992$phoneDigits';

    final result = await ApiService.sendCode(phone);

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Navigate to verify code screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyCodeScreen(phone: phone),
          ),
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
            content: Text(result['error'] ?? "Хатогӣ! Интернет ё рақамро санҷед."),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Лого ё Навиштаҷот
              const Icon(Icons.menu_book_rounded, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "Хуш омадед",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // Майдони Рақам
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                style: const TextStyle(fontSize: 18),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                decoration: InputDecoration(
                  labelText: "Рақами телефон",
                  prefix: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      '+992',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                  hintText: "921234567",
                  counterText: "", // Hide character counter
                ),
              ),
              const SizedBox(height: 30),

              // Тугма
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onSendPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Ирсоли СМС",
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
