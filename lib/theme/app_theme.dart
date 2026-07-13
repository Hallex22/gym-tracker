import 'package:flutter/material.dart';

class AppTheme {
  static const Color _backgroundColor = Color(0xFF0F0E17);
  static const Color _cardColor = Color(0xFF161424);

  static const Color _purplePrimary = Color(0xFF9D4EDD);
  static const Color _purpleContainer = Color(0xFF5A189A);
  static const Color _purpleSecondary = Color(0xFFE0AAFF);

  static const Color _textMain = Color(0xFFFFFFFE);
  static const Color _textMuted = Color(0xFF94A1B2);
  static const Color _textOnPrimary = Color(0xFFFFFFFF);

  static const String _fontFamily = 'Inter';

  static ThemeData get darkTheme {
    // 💡 1. Definim TextTheme-ul de bază cu culorile tale custom
    const baseTextTheme = TextTheme(
      headlineMedium: TextStyle(color: _textMain, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(
          color: _textMain, fontWeight: FontWeight.bold, fontSize: 18),
      bodyLarge: TextStyle(color: _textMain, fontSize: 15),
      bodyMedium: TextStyle(color: _textMuted, fontSize: 13),
    );

    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
    ).copyWith(
      scaffoldBackgroundColor: _backgroundColor,
      cardColor: _cardColor,

      colorScheme: const ColorScheme.dark(
        primary: _purplePrimary,
        primaryContainer: _purpleContainer,
        secondary: _purpleSecondary,
        surface: _cardColor,
        error: Colors.redAccent,
        onSurface: _textMain,
        onSurfaceVariant: _textMuted,
        onPrimary: _textOnPrimary,
      ),

      // 💡 2. MAGIA REPARĂRII: Folosim .apply pe TextTheme-ul implicit al temei dark.
      // Asta asigură că absolut toate stilurile interne (labelLarge pentru butoane, display, etc.)
      // primesc fontul tău, nu doar cele 4 pe care le-ai definit manual.
      textTheme: ThemeData.dark().textTheme.merge(baseTextTheme).apply(
            fontFamily: _fontFamily,
            displayColor: _textMain,
            bodyColor: _textMain,
          ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _textMain,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: _fontFamily, // Sigur rămâne pe AppBar
        ),
        iconTheme: IconThemeData(color: _textMain),
      ),

      // 💡 3. Ne asigurăm că și butoanele mari (Elevated) ascultă de temă
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _purplePrimary,
          foregroundColor: _textOnPrimary,
          elevation: 2,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            fontFamily: _fontFamily, // Forțat direct pe textul butonului
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),

      // 💡 4. Forțăm fontul și în ferestrele pop-up / dialoguri de confirmare (dacă ai)
      dialogTheme: const DialogThemeData(
        titleTextStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _textMain),
        contentTextStyle: TextStyle(fontFamily: _fontFamily, color: _textMuted),
      ),

      cardTheme: CardThemeData(
        color: _cardColor,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        // Forțăm fontul Oswald și în etichetele sau textele ajutătoare din Inputs
        labelStyle: const TextStyle(fontFamily: _fontFamily),
        hintStyle: const TextStyle(fontFamily: _fontFamily),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _purplePrimary.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _purplePrimary, width: 1.5),
        ),
      ),
    );
  }
}
