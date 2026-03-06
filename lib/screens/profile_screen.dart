import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../models/user_model.dart';
import '../utils/formatters.dart';
import 'login_screen.dart';
import 'balance_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Controllers for editable fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _openTelegramContact() async {
    final uri = Uri.parse('https://t.me/group1week');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Telegram кушода нашуд.")),
        );
      }
    }
  }

  void _showIOSContactAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Обуна ва пардохт"),
        content: const Text(
          "Дар версияи iOS пардохтҳо дар дохили барнома ғайрифаъоланд.\n\n"
          "Барои пайваст кардани бобҳои иловагӣ ё пур кардани дастрасӣ, "
          "лутфан ба администратор дар Telegram муроҷиат намоед.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Бекор"),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openTelegramContact();
            },
            icon: const Icon(Icons.send),
            label: const Text("Telegram"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    final user = await ApiService.getUserProfile();
    if (mounted) {
      setState(() {
        _user = user;
        if (user != null) {
          _firstNameController.text = user.firstName;
          _lastNameController.text = user.lastName;
          if (user.birthDate != null && user.birthDate!.isNotEmpty) {
            try {
              _selectedDate = DateTime.parse(user.birthDate!);
              _birthDateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);
            } catch (e) {
              print("Error parsing birth date: $e");
              _selectedDate = null;
              _birthDateController.text = '';
            }
          } else {
            _selectedDate = null;
            _birthDateController.text = '';
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ru', 'RU'), // Можно изменить на нужную локаль
    );
    if (picked != null) {
      // Format the date immediately to "yyyy-MM-dd" string
      final String formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _selectedDate = picked;
        _birthDateController.text = formattedDate;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_firstNameController.text.trim().isEmpty || 
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Лутфан ном ва насабро пур кунед"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Construct the data map with first_name and last_name
    final data = <String, dynamic>{
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
    };

    // Handle birth_date: format as "yyyy-MM-dd" string (NOT ISO string with time)
    if (_selectedDate != null) {
      // Format the date to "yyyy-MM-dd" string (e.g., "1999-05-25")
      // Do NOT send ISO string with time
      data['birth_date'] = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    }
    // If _selectedDate is null, don't include birth_date in the request

    print("📤 Sending profile update data: $data");

    final result = await ApiService.updateProfile(data);

    setState(() => _isSaving = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Маълумот бомуваффақият нав карда шуд"),
            backgroundColor: Colors.green,
          ),
        );
        await _loadUserProfile();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? "Хатогӣ"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleLogout() async {
    // Диалоги тасдиқ
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Баромадан"),
        content: const Text("Шумо мутмаин ҳастед, ки мехоҳед аз система баромада шавед?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Не"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Бале"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Пок кардани токен ва маълумоти корбар
      var box = Hive.box('settings');
      await box.delete('token');
      await box.delete('login_date');
      await box.delete('phone');
      await box.delete('is_guest');
      
      // Гузариш ба саҳифаи воридшавӣ
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  bool get _isGuest {
    try {
      return Hive.box('settings').get('is_guest', defaultValue: false) == true;
    } catch (_) {
      return false;
    }
  }

  Widget _buildGuestOrErrorContent() {
    if (_isGuest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                "Шумо ҳамчун меҳмон сӯҳбат мекунед",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                "Барои таҳрир кардани профил ё дастрасӣ ба мундариҷаи пулакӣ ворид шавед.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Hive.box('settings').delete('is_guest');
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Ворид шудан",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const Center(
      child: Text(
        "Маълумоти корбар ёфт нашуд",
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Future<String> _getDeviceId() async {
    try {
      // First try to get from Hive (saved device ID)
      var box = Hive.box('settings');
      String? savedDeviceId = box.get('device_id');
      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        return savedDeviceId;
      }

      // If not in Hive, get current device ID using ApiService
      return await ApiService.getDeviceId();
    } catch (e) {
      return 'error-getting-device-id';
    }
  }

  void _handleDeleteAccount() async {
    // Диалоги тасдиқ
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Нест кардани ҳисоб"),
        content: const Text(
          "Шумо мутмаин ҳастед? Ин амал бекор карда намешавад.",
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Бекор кардан"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Нест кардан"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ApiService.deleteAccount();
      
      if (result['success'] == true) {
        // Пок кардани токен ва маълумоти корбар
        var box = Hive.box('settings');
        await box.delete('token');
        await box.delete('login_date');
        await box.delete('phone');
        
        // Гузариш ба саҳифаи воридшавӣ
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? "Хатогӣ"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Профили ман"),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? _buildGuestOrErrorContent()
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // User Avatar
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.blue[100],
                          child: Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // First Name (Editable)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Ном",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _firstNameController,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Last Name (Editable)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Насаб",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _lastNameController,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Phone Number (Read-only)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Рақами телефон",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Formatters.formatPhoneNumber(_user!.phone),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Balance (Prominently displayed, Navigable)
                        InkWell(
                          onTap: () {
                            if (Platform.isIOS) {
                              _showIOSContactAdminDialog();
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const BalanceScreen()),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[400]!, Colors.blue[600]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "Баланс",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "${_user!.balance} сомонӣ",
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Зарб кардан барои тафсилот",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Date of Birth (Editable with DatePicker)
                        InkWell(
                          onTap: _selectDate,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Санаи таваллуд",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _birthDateController.text.isNotEmpty
                                      ? _birthDateController.text
                                      : "Маълумот нест (Зарб кардан барои интихоб)",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: _birthDateController.text.isNotEmpty ? Colors.black87 : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Device Info (Read-only)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "ID-и дастгоҳ",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<String>(
                                future: _getDeviceId(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Text(
                                      "Боргирӣ...",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    );
                                  }
                                  final deviceId = snapshot.data ?? 'Маълумот нест';
                                  return SelectableText(
                                    deviceId,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'monospace',
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Save Changes Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Сабт кардани тағйирот",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _handleLogout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Баромадан",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Delete Account Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _handleDeleteAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[900],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Нест кардани ҳисоб",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
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
