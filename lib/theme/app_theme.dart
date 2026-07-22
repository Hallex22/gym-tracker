import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter_theme show Theme, ThemeData;

/// Tokenii de design pentru Dark Mode
class AppDarkColors {
  static const Color bgDark = Color(0xFF0F0E17);
  static const Color bg = Color(0xFF161424);
  static const Color bgLight = Color(0xFF1F1C33);

  static const Color primary = Color(0xFF9D4EDD);
  static const Color primaryContainer = Color(0xFF5A189A);
  static const Color secondary = Color(0xFFE0AAFF);

  static const Color border = Color(0xFF322E4D);
  static const Color borderMuted = Color(0xFF232036);

  static const Color text = Color(0xFFFFFFFE);
  static const Color textMuted = Color(0xFF94A1B2);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color error = Colors.redAccent;
}

/// Tokenii de design pentru Light Mode
class AppLightColors {
  static const Color bgDark = Color(0xFFF9F9FB);
  static const Color bg = Color(0xFFFFFFFF);
  static const Color bgLight = Color(0xFFF0EDF6);

  static const Color primary = Color(0xFF7B2CBF);
  static const Color primaryContainer = Color(0xFFE0AAFF);
  static const Color secondary = Color(0xFF5A189A);

  static const Color border = Color(0xFFD6CDE6);
  static const Color borderMuted = Color(0xFFECE7F2);

  static const Color text = Color(0xFF161424);
  static const Color textMuted = Color(0xFF6F6A8A);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD93838);
}

class AppTheme {
  static const String _fontFamily = 'Inter';

  // ==========================================
  // 🌙 TEMA DARK
  // ==========================================
  static ThemeData get darkTheme {
    final baseTextTheme = const TextTheme(
      headlineMedium: TextStyle(color: AppDarkColors.text, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: AppDarkColors.text, fontWeight: FontWeight.bold, fontSize: 18),
      bodyLarge: TextStyle(color: AppDarkColors.text, fontSize: 15),
      bodyMedium: TextStyle(color: AppDarkColors.textMuted, fontSize: 13),
    ).apply(
      fontFamily: _fontFamily,
      displayColor: AppDarkColors.text,
      bodyColor: AppDarkColors.text,
    );

    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
    ).copyWith(
      scaffoldBackgroundColor: AppDarkColors.bgDark,
      cardColor: AppDarkColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppDarkColors.primary,
        primaryContainer: AppDarkColors.primaryContainer,
        secondary: AppDarkColors.secondary,
        surface: AppDarkColors.bg,
        surfaceContainerHighest: AppDarkColors.bgLight,
        error: AppDarkColors.error,
        onSurface: AppDarkColors.text,
        onSurfaceVariant: AppDarkColors.textMuted,
        onPrimary: AppDarkColors.textOnPrimary,
        outline: AppDarkColors.border,
        outlineVariant: AppDarkColors.borderMuted,
      ),
      textTheme: ThemeData.dark().textTheme.merge(baseTextTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppDarkColors.bgDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppDarkColors.text,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: _fontFamily,
        ),
        iconTheme: IconThemeData(color: AppDarkColors.text),
      ),
      cardTheme: CardThemeData(
        color: AppDarkColors.bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppDarkColors.borderMuted),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDarkColors.primary,
          foregroundColor: AppDarkColors.textOnPrimary,
          elevation: 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            fontFamily: _fontFamily,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppDarkColors.bg,
        elevation: 0,
        titleTextStyle:
            TextStyle(fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.bold, color: AppDarkColors.text),
        contentTextStyle: TextStyle(fontFamily: _fontFamily, color: AppDarkColors.textMuted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppDarkColors.bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(fontFamily: _fontFamily, color: AppDarkColors.textMuted),
        hintStyle: const TextStyle(fontFamily: _fontFamily, color: AppDarkColors.textMuted),
        fillColor: AppDarkColors.bgLight,
        filled: false,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppDarkColors.borderMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppDarkColors.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppDarkColors.borderMuted),
        ),
      ),
    );
  }

  // ==========================================
  // ☀️ TEMA LIGHT
  // ==========================================
  static ThemeData get lightTheme {
    final baseTextTheme = const TextTheme(
      headlineMedium: TextStyle(color: AppLightColors.text, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: AppLightColors.text, fontWeight: FontWeight.bold, fontSize: 18),
      bodyLarge: TextStyle(color: AppLightColors.text, fontSize: 15),
      bodyMedium: TextStyle(color: AppLightColors.textMuted, fontSize: 13),
    ).apply(
      fontFamily: _fontFamily,
      displayColor: AppLightColors.text,
      bodyColor: AppLightColors.text,
    );

    return ThemeData(
      brightness: Brightness.light,
      fontFamily: _fontFamily,
    ).copyWith(
      scaffoldBackgroundColor: AppLightColors.bgDark,
      cardColor: AppLightColors.bg,
      colorScheme: const ColorScheme.light(
        primary: AppLightColors.primary,
        primaryContainer: AppLightColors.primaryContainer,
        secondary: AppLightColors.secondary,
        surface: AppLightColors.bg,
        surfaceContainerHighest: AppLightColors.bgLight,
        error: AppLightColors.error,
        onSurface: AppLightColors.text,
        onSurfaceVariant: AppLightColors.textMuted,
        onPrimary: AppLightColors.textOnPrimary,
        outline: AppLightColors.border,
        outlineVariant: AppLightColors.borderMuted,
      ),
      textTheme: ThemeData.light().textTheme.merge(baseTextTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppLightColors.bgDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppLightColors.text,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: _fontFamily,
        ),
        iconTheme: IconThemeData(color: AppLightColors.text),
      ),
      cardTheme: CardThemeData(
        color: AppLightColors.bg,
        elevation: 2,
        shadowColor: AppLightColors.border.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppLightColors.borderMuted),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppLightColors.primary,
          foregroundColor: AppLightColors.textOnPrimary,
          elevation: 3,
          shadowColor: AppLightColors.primary.withOpacity(0.35),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            fontFamily: _fontFamily,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppLightColors.bg,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.12),
        titleTextStyle: const TextStyle(
            fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.bold, color: AppLightColors.text),
        contentTextStyle: const TextStyle(fontFamily: _fontFamily, color: AppLightColors.textMuted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppLightColors.bg,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(fontFamily: _fontFamily, color: AppLightColors.textMuted),
        hintStyle: const TextStyle(fontFamily: _fontFamily, color: AppLightColors.textMuted),
        fillColor: AppLightColors.bgLight,
        filled: false,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppLightColors.borderMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppLightColors.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppLightColors.borderMuted),
        ),
      ),
    );
  }
}

extension BuildContextThemeExtensions on BuildContext {
  flutter_theme.ThemeData get theme => flutter_theme.Theme.of(this);
  ColorScheme get colorScheme => flutter_theme.Theme.of(this).colorScheme;

  // --- TOKENI DE BAZĂ ---
  Color get bgDark => theme.scaffoldBackgroundColor;
  Color get bg => theme.cardColor;
  Color get bgLight => colorScheme.surfaceContainerHighest;

  Color get primary => colorScheme.primary;
  Color get secondary => colorScheme.secondary;

  Color get border => colorScheme.outline;
  Color get borderMuted => colorScheme.outlineVariant;

  Color get text => colorScheme.onSurface;
  Color get textMuted => colorScheme.onSurfaceVariant;
  Color get error => colorScheme.error;

  /// Helper util: adaugă umbră automată pentru `Container(decoration: ...)` doar pe Light Mode
  List<BoxShadow> get cardShadow {
    final isLight = theme.brightness == Brightness.light;
    if (!isLight) return const [];

    return [
      BoxShadow(
        color: AppLightColors.border.withOpacity(0.35),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ];
  }
}