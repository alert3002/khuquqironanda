class Formatters {
  static String formatPhoneNumber(String phone) {
    // Удаление всех нецифровых символов
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Если номер начинается с '992', убираем префикс
    if (cleaned.startsWith('992')) {
      cleaned = cleaned.substring(3); // Убираем '992'
    }
    // Если номер начинается с '9', оставляем как есть (префикс будет добавлен)
    
    // Убеждаемся, что финальный номер всегда начинается с +992
    // Форматирование для отображения
    if (cleaned.length == 9) {
      // Формат: +992 XX XXX XX XX
      return '+992 ${cleaned.substring(0, 2)} ${cleaned.substring(2, 5)} ${cleaned.substring(5, 7)} ${cleaned.substring(7)}';
    }
    
    // Если номер не 9 цифр, просто добавляем префикс
    return '+992 $cleaned';
  }
}

