import 'package:intl/intl.dart';





class TimeUtils {
  
  
  
  
  static DateTime? parseDateSafe(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;

    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      
      final formats = [
        'yyyy-MM-dd',
        'dd/MM/yyyy',
        'yyyy-MM-dd HH:mm:ss',
        'dd/MM/yyyy HH:mm:ss',
      ];

      for (final format in formats) {
        try {
          return DateFormat(format).parseStrict(dateStr);
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  
  
  
  static int calculateRemainingTime(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inSeconds;
  }

  
  
  
  
  
  
  static String formatRemaining(int seconds) {
    if (seconds <= 0) return '0 min';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '$minutes min';
  }

  
  
  
  
  
  
  static String formatDate(DateTime date, {String pattern = 'd/M/yy'}) {
    return DateFormat(pattern, 'es').format(date);
  }

  
  
  
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return formatDate(date);
  }

  
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }
}
