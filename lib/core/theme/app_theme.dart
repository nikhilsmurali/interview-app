import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color brandBlack = Colors.black;
  static const Color brandWhite = Colors.white;
  static const Color brandLightGray = Color(0xFFF8FAFC);
  static const Color brandOrange = Color(0xFFFF5A00);
  static const Color brandDarkGray = Color(0xFF121212); // Slightly lighter black for surfaces

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: brandBlack,
    primaryColor: brandOrange,
    colorScheme: const ColorScheme.dark(
      primary: brandOrange,
      secondary: brandOrange,
      surface: brandDarkGray,
      onSurface: brandWhite,
      onPrimary: brandWhite,
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: brandBlack,
      foregroundColor: brandWhite,
      elevation: 0,
    ),
    useMaterial3: true,
  );

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: brandWhite,
    primaryColor: brandOrange,
    colorScheme: const ColorScheme.light(
      primary: brandOrange,
      secondary: brandOrange,
      surface: brandLightGray,
      onSurface: brandBlack,
      onPrimary: brandWhite,
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: brandWhite,
      foregroundColor: brandBlack,
      elevation: 0,
    ),
    useMaterial3: true,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [brandOrange, Color(0xFFFF8A00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
