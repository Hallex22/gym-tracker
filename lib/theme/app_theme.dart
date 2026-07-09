import 'package:flutter/material.dart';

class AppTheme {
  static const Color _backgroundColor = Color(0xFF0F0E17);
  static const Color _cardColor = Color(0xFF161424);

  static const Color _purplePrimary = Color(0xFF9D4EDD);
  static const Color _purpleContainer = Color(0xFF5A189A);
  static const Color _purpleSecondary = Color(0xFFE0AAFF);

  // --- CULORILE DE TEXT PROPUSE DE TINE ---
  static const Color _textMain =
      Color(0xFFFFFFFE); // Alb strălucitor (Text principal)
  static const Color _textMuted =
      Color(0xFF94A1B2); // Gri-albăstrui discret (Text secundar / muted)
  static const Color _textOnPrimary =
      Color(0xFFFFFFFF); // Textul care stă peste movul aprins

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: _backgroundColor,
      cardColor: _cardColor,

      colorScheme: const ColorScheme.dark(
        primary: _purplePrimary,
        primaryContainer: _purpleContainer,
        secondary: _purpleSecondary,
        surface: _cardColor,
        error: Colors.redAccent,

        // Mapăm culorile de text în schema de culori standard Flutter:
        onSurface: _textMain, // Textul implicit de pe ecran/carduri
        onSurfaceVariant:
            _textMuted, // Varianta "muted" pentru detalii/subtitluri
        onPrimary: _textOnPrimary, // Textul de peste butoanele primary (mov)
      ),

      // CONFIGURAREA TEXTULUI GLOBAL (Scapi de TextStyle manual în pagini!)
      textTheme: const TextTheme(
        // Pentru Titluri mari
        headlineMedium:
            TextStyle(color: _textMain, fontWeight: FontWeight.bold),
        // Pentru titluri de Carduri sau secțiuni
        titleLarge: TextStyle(
            color: _textMain, fontWeight: FontWeight.bold, fontSize: 18),
        // Pentru text normal (Main Text)
        bodyLarge: TextStyle(color: _textMain, fontSize: 15),
        // Pentru textul discret (Text Muted)
        bodyMedium: TextStyle(color: _textMuted, fontSize: 13),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: _textMain, // Folosește albul principal
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: _textMain),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _purplePrimary,
          foregroundColor:
              _textOnPrimary, // Textul de peste buton va fi alb pur
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
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
    );
  }
}
