import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _backgroundColor = Color(0xFF0F0E17);
  static const Color _cardColor = Color(0xFF161424);

  static const Color _purplePrimary = Color(0xFF9D4EDD);
  static const Color _purpleContainer = Color(0xFF5A189A);
  static const Color _purpleSecondary = Color(0xFFE0AAFF);

  // --- CULORILE DE TEXT PROPUSE DE TINE ---
  static const Color _textMain = Color(0xFFFFFFFE); // Alb strălucitor
  static const Color _textMuted = Color(0xFF94A1B2); // Gri-albăstrui discret
  static const Color _textOnPrimary = Color(0xFFFFFFFF); // Textul de peste mov

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
        onSurface: _textMain, 
        onSurfaceVariant: _textMuted, 
        onPrimary: _textOnPrimary, 
      ),

      // 💡 MODIFICAT AICI: Pachetul GoogleFonts preia stilurile tale și le injectează fontul Inter!
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          headlineMedium: TextStyle(color: _textMain, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 18),
          bodyLarge: TextStyle(color: _textMain, fontSize: 15),
          bodyMedium: TextStyle(color: _textMuted, fontSize: 13),
        ),
      ),

      // 💡 PENTRU APPBAR: Ca să aibă și titlul de sus tot fontul Inter, aplicăm Inter direct pe TextStyle-ul lui
      appBarTheme: AppBarTheme(
        backgroundColor: _backgroundColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          textStyle: const TextStyle(
            color: _textMain,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: _textMain),
      ),

      // 💡 PENTRU BUTOANE ELEVATED: Aplicăm Inter și pe textul din butoane ca să fie totul unitar
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _purplePrimary,
          foregroundColor: _textOnPrimary, 
          elevation: 2,
          textStyle: GoogleFonts.inter(
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

      inputDecorationTheme: InputDecorationTheme(
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