import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kIndigo   = Color(0xFF1a1a3e);
const kGold     = Color(0xFFc9a84c);
const kLavender = Color(0xFFc8b8e8);
const kMoonWhite = Color(0xFFf5f0ff);
const kSurface  = Color(0xFF22193d);
const kDark     = Color(0xFF0e0b18);

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kDark,
    colorScheme: const ColorScheme.dark(
      primary: kGold,
      secondary: kLavender,
      surface: kSurface,
      onSurface: kMoonWhite,
      onPrimary: kDark,
    ),
    textTheme: GoogleFonts.playfairDisplayTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: kMoonWhite, displayColor: kGold),
    appBarTheme: const AppBarTheme(
      backgroundColor: kIndigo,
      foregroundColor: kGold,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kLavender, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kLavender, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kGold, width: 1.5),
      ),
      labelStyle: const TextStyle(color: kLavender),
      hintStyle: TextStyle(color: kLavender.withOpacity(0.5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kGold,
        foregroundColor: kDark,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kGold,
      foregroundColor: kDark,
    ),
  );
}
