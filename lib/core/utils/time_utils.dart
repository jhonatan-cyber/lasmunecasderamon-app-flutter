import 'package:intl/intl.dart';

/// Time-related utility functions.
///
/// Mirrors Expo's `utils/timeUtils.ts` — provides date parsing, formatting,
/// and countdown calculations for timers and schedules.
class TimeUtils {
  /// Attempts to parse a date string safely, returning `null` on failure.
  ///
  /// Handles ISO 8601, `yyyy-MM-dd`, `dd/MM/yyyy`, and `yyyy-MM-ddTHH:mm:ss`
  /// formats commonly returned by the backend.
  static DateTime? parseDateSafe(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;

    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      // Try common formats
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

  /// Calculates the remaining time in seconds between [deadline] and now.
  ///
  /// Returns 0 if the deadline has already passed.
  static int calculateRemainingTime(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inSeconds;
  }

  /// Returns the remaining time as a human-readable string.
  ///
  /// Examples:
  /// - `45 min` — less than 1 hour
  /// - `1h 23min` — more than 1 hour
  /// - `0 min` — expired
  static String formatRemaining(int seconds) {
    if (seconds <= 0) return '0 min';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '$minutes min';
  }

  /// Formats a [DateTime] to a localized string.
  ///
  /// Pattern examples:
  /// - `EEEE d 'de' MMMM` → "lunes 17 de junio"
  /// - `HH:mm` → "14:30"
  /// - `d/M/yy` → "17/6/26"
  static String formatDate(DateTime date, {String pattern = 'd/M/yy'}) {
    return DateFormat(pattern, 'es').format(date);
  }

  /// Formats a [DateTime] as a relative time string.
  ///
  /// Examples: "hace 5 min", "hace 2h", "hace 3 días"
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return formatDate(date);
  }

  /// Formats a time-of-day to `HH:mm` string.
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// Returns `true` if [date] is today.
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Returns `true` if [date] is yesterday.
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }
}
