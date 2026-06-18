import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeOption {
  final String name;
  final Color color;
  final List<Color> gradient;
  
  const AppThemeOption({
    required this.name,
    required this.color,
    required this.gradient,
  });
}

const List<AppThemeOption> appThemeOptions = [
  // Tonos Cálidos
  AppThemeOption(
    name: 'Terracota (Default)',
    color: Color(0xFFD84315),
    gradient: [Color(0xFFD84315), Color(0xFFBF360C), Color(0xFF9E2A0B)],
  ),
  AppThemeOption(
    name: 'Rojo',
    color: Color(0xFFE11D48),
    gradient: [Color(0xFFE11D48), Color(0xFFBE123C), Color(0xFF9F1239)],
  ),
  AppThemeOption(
    name: 'Naranja',
    color: Color(0xFFF97316),
    gradient: [Color(0xFFF97316), Color(0xFFEA580C), Color(0xFFC2410C)],
  ),
  AppThemeOption(
    name: 'Amarillo',
    color: Color(0xFFEAB308),
    gradient: [Color(0xFFEAB308), Color(0xFFCA8A04), Color(0xFFA16207)],
  ),
  // Tonos Fríos
  AppThemeOption(
    name: 'Esmeralda',
    color: Color(0xFF059669),
    gradient: [Color(0xFF059669), Color(0xFF047857), Color(0xFF065F46)],
  ),
  AppThemeOption(
    name: 'Cian',
    color: Color(0xFF0891B2),
    gradient: [Color(0xFF0891B2), Color(0xFF0E7490), Color(0xFF155E75)],
  ),
  AppThemeOption(
    name: 'Azul',
    color: Color(0xFF3B82F6),
    gradient: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8)],
  ),
  AppThemeOption(
    name: 'Violeta',
    color: Color(0xFF8B5CF6),
    gradient: [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF6D28D9)],
  ),
  // Tonos Neutros
  AppThemeOption(
    name: 'Rosa',
    color: Color(0xFFEC4899),
    gradient: [Color(0xFFEC4899), Color(0xFFDB2777), Color(0xFFBE185D)],
  ),
  AppThemeOption(
    name: 'Negro',
    color: Color(0xFF334155),
    gradient: [Color(0xFF334155), Color(0xFF1E293B), Color(0xFF0F172A)],
  ),
];

class AppTheme {
  // Semantic / Status Colors
  static const Color errorColor = Color(0xFFEF4444); // Red - errors, delete, danger
  static const Color successColor = Color(0xFF10B981); // Green - success, active, completed
  static const Color warningColor = Color(0xFFF59E0B); // Amber - pending, warning
  static const Color infoColor = Color(0xFF3B82F6); // Blue - info, processing

  // Semantic Dark Variants
  static const Color errorDarkColor = Color(0xFF991B1B);
  static const Color successDarkColor = Color(0xFF065F46);
  static const Color infoDarkColor = Color(0xFF1E40AF);
  static const Color warningDarkColor = Color(0xFFB45309);

  // Semantic Light Background Variants
  static const Color errorLightBg = Color(0xFFFEE2E2);
  static const Color successLightBg = Color(0xFFD1FAE5);
  static const Color infoLightBg = Color(0xFFDBEAFE);
  static const Color warningLightBg = Color(0xFFFEF3C7);

  // Additional Palette
  static const Color nearBlackColor = Color(0xFF111111); // Alternative dark surface
  static const Color gray500Color = Color(0xFF6B7280); // Gray 500 - alternative secondary
  static const Color gray700Color = Color(0xFF374151); // Gray 700 - borders/dividers
  static const Color purpleColor = Color(0xFF8B5CF6); // Purple - extras
  static const Color lightRedColor = Color(0xFFFCA5A5); // Light red
  static const Color darkSurfaceAltColor = Color(0xFF27272A); // Alternative dark surface

  // Status Dark Variants (for dark mode foreground)
  static const Color successLightFg = Color(0xFF6EE7B7); // Light green
  static const Color infoLightFg = Color(0xFF93C5FD); // Light blue

  // Brand Colors
  static const Color primaryColor = Color(0xFFD84315); // Deep Warm Orange / Terracotta
  static const Color secondaryColor = Color(0xFFFFB300); // Warm Amber
  static const Color accentColor = Color(0xFFFF7043); // Lighter Coral

  // Dark Mode Palette
  static const Color darkBgColor = Color(0xFF0F0F10); // Ultra Dark Charcoal
  static const Color darkSurfaceColor = Color(0xFF18181A); // Card background
  static const Color darkBorderColor = Color(0xFF262629); // Borders and dividers
  static const Color darkTextPrimary = Color(0xFFF3F4F6); // White/Gray 100
  static const Color darkTextSecondary = Color(0xFF9CA3AF); // Gray 400

  // Light Mode Palette
  static const Color lightBgColor = Color(0xFFF9FAFB); // Gray 50
  static const Color lightSurfaceColor = Color(0xFFFFFFFF);
  static const Color lightBorderColor = Color(0xFFE5E7EB);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF4B5563);

  // Common Button Style Helper
  static ButtonStyle getPrimaryButtonStyle(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // Dynamic Theme Generator
  static ThemeData getTheme(Brightness brightness, Color customPrimaryColor) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? darkBgColor : lightBgColor;
    final surface = isDark ? darkSurfaceColor : lightSurfaceColor;
    final textPrimary = isDark ? darkTextPrimary : lightTextPrimary;
    final textSecondary = isDark ? darkTextSecondary : lightTextSecondary;
    final border = isDark ? darkBorderColor : lightBorderColor;
    final errorColor = isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: customPrimaryColor,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: customPrimaryColor,
        onPrimary: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        error: errorColor,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        tertiary: accentColor,
      ),
      dividerColor: border,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, color: textSecondary),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: textSecondary.withValues(alpha: 0.5), fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: customPrimaryColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: errorColor, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: errorColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Backward compatibility getters
  static ThemeData get darkTheme => getTheme(Brightness.dark, primaryColor);
  static ThemeData get lightTheme => getTheme(Brightness.light, primaryColor);
}

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

// Accent Color Provider with SharedPreferences Persistence
final accentColorProvider = StateNotifierProvider<AccentColorNotifier, AppThemeOption>((ref) {
  return AccentColorNotifier();
});

class AccentColorNotifier extends StateNotifier<AppThemeOption> {
  AccentColorNotifier() : super(appThemeOptions[0]) {
    _loadAccentColor();
  }

  Future<void> _loadAccentColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorHex = prefs.getString('user_accent_color');
      if (colorHex != null) {
        final option = appThemeOptions.firstWhere(
          (opt) {
            final hexVal = '#${opt.color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
            return hexVal == colorHex.toUpperCase();
          },
          orElse: () => appThemeOptions[0],
        );
        state = option;
      }
    } catch (_) {}
  }

  Future<void> setAccentColor(AppThemeOption option) async {
    state = option;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hex = '#${option.color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      await prefs.setString('user_accent_color', hex);
    } catch (_) {}
  }
}
