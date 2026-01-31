import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_service.dart';
import '../models/user_model.dart';

class ManualPaymentScreen extends StatefulWidget {
  const ManualPaymentScreen({super.key});

  @override
  State<ManualPaymentScreen> createState() => _ManualPaymentScreenState();
}

class _ManualPaymentScreenState extends State<ManualPaymentScreen> {
  final String phoneNumber = '927203002';
  final String whatsappNumber = '+992927203002';
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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

  void _copyPhoneNumber() {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Рақам нусхабардорӣ шуд"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _openBankApp(String appUrl, String storeUrl) async {
    try {
      final uri = Uri.parse(appUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // If app is not installed, open Play Store
        final storeUri = Uri.parse(storeUrl);
        if (await canLaunchUrl(storeUri)) {
          await launchUrl(storeUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Хатогӣ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleBankButton(String bankName, String appUrl, String storeUrl) {
    _copyPhoneNumber();
    _openBankApp(appUrl, storeUrl);
  }

  Future<void> _openWhatsApp() async {
    final userId = _user?.id ?? 0;
    final message = Uri.encodeComponent(
      'Салом, ман ба ҳисоби шумо маблағ гузаронидам. ID ман: $userId',
    );
    final whatsappUrl = 'https://wa.me/$whatsappNumber?text=$message';
    
    try {
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp насб нашудааст'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Хатогӣ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Пардохт (Корти бонкӣ)"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // Instructions
                  Text(
                    "Барои пур кардани баланси барномаи ҳуқуқи ронанда, лутфан ба рақами зерин маблағ гузаронед ва дар шарҳ (комментария) 'Az Vakil' нависед.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Phone Number Display
                  GestureDetector(
                    onTap: _copyPhoneNumber,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue[200]!,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Рақами ҳамён",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            phoneNumber,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.copy,
                                size: 16,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Зарб кардан барои нусхабардорӣ",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Bank Buttons
                  const Text(
                    "Бонкҳо",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // DC Bank
                  _buildBankCard(
                    'DC Bank',
                    Colors.yellow[700]!,
                    Icons.account_balance,
                    onTap: () => _handleBankButton(
                      'DC Bank',
                      'dushanbecity://',
                      'https://play.google.com/store/apps/details?id=com.dushanbecity',
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Alif Mobi
                  _buildBankCard(
                    'Alif Mobi',
                    Colors.green,
                    Icons.phone_android,
                    onTap: () => _handleBankButton(
                      'Alif Mobi',
                      'alifmobi://',
                      'https://play.google.com/store/apps/details?id=com.alifmobi',
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Eskhata
                  _buildBankCard(
                    'Eskhata',
                    Colors.blue[800]!,
                    Icons.savings,
                    onTap: () => _handleBankButton(
                      'Eskhata',
                      'eskhata://',
                      'https://play.google.com/store/apps/details?id=com.eskhata',
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Verification Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.chat),
                      label: const Text(
                        "Ман пардохт кардам (Ирсоли Чек)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildBankCard(
    String bankName,
    Color color,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          bankName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text("Зарб кардан барои кушодани барнома"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

