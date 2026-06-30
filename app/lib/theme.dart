import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Paper theme data ────────────────────────────────────────────────────────

class PaperTheme {
  final String id;
  final String name;
  final Color dot;       // picker circle colour
  final Color bg;        // outer shell background
  final Color paper;     // writing surface
  final Color card;      // card / entry background
  final Color ink;       // body text
  final Color heading;   // titles & headings
  final Color accent;    // primary accent (gold, rust, blue…)
  final Color muted;     // subdued / secondary text
  final Color border;    // subtle card borders
  final Color lines;     // ruled-paper line colour
  final Color appBarBg;
  final Color appBarFg;
  final Brightness brightness;

  const PaperTheme({
    required this.id,
    required this.name,
    required this.dot,
    required this.bg,
    required this.paper,
    required this.card,
    required this.ink,
    required this.heading,
    required this.accent,
    required this.muted,
    required this.border,
    required this.lines,
    required this.appBarBg,
    required this.appBarFg,
    required this.brightness,
  });
}

// ── Three presets ────────────────────────────────────────────────────────────

const paperThemeMidnight = PaperTheme(
  id: 'midnight',
  name: 'Midnight',
  dot: Color(0xFF9b72cf),
  bg: Color(0xFF0e0b18),
  paper: Color(0xFF181535),
  card: Color(0xFF1e1a40),
  ink: Color(0xFFede6ff),
  heading: Color(0xFFc9a84c),
  accent: Color(0xFFc9a84c),
  muted: Color(0xFF8878b8),
  border: Color(0xFF2d2460),
  lines: Color(0xFF23205a),
  appBarBg: Color(0xFF110e28),
  appBarFg: Color(0xFFc9a84c),
  brightness: Brightness.dark,
);

const paperThemeParchment = PaperTheme(
  id: 'parchment',
  name: 'Parchment',
  dot: Color(0xFFc4762a),
  bg: Color(0xFFb89660),
  paper: Color(0xFFfdf6e3),
  card: Color(0xFFf5ead0),
  ink: Color(0xFF2d1a0e),
  heading: Color(0xFF7a3a10),
  accent: Color(0xFFc4762a),
  muted: Color(0xFF8b6050),
  border: Color(0xFFd4b896),
  lines: Color(0xFFe8d8b8),
  appBarBg: Color(0xFF8b6040),
  appBarFg: Color(0xFFfdf6e3),
  brightness: Brightness.light,
);

const paperThemeMoonlit = PaperTheme(
  id: 'moonlit',
  name: 'Moonlit',
  dot: Color(0xFF5b9fc4),
  bg: Color(0xFF1a2a3f),
  paper: Color(0xFFeef2f8),
  card: Color(0xFFe4ecf4),
  ink: Color(0xFF1a2535),
  heading: Color(0xFF2c6b9a),
  accent: Color(0xFF5b9fc4),
  muted: Color(0xFF6b8a9f),
  border: Color(0xFFc5d8e8),
  lines: Color(0xFFd8e6f0),
  appBarBg: Color(0xFF1a2a3f),
  appBarFg: Color(0xFFa8d4f0),
  brightness: Brightness.light,
);

const paperThemeDawn = PaperTheme(
  id: 'dawn',
  name: 'Dawn',
  dot: Color(0xFFe87a8c),
  bg: Color(0xFFf9edf1),
  paper: Color(0xFFfdf5f7),
  card: Color(0xFFf5dfe8),
  ink: Color(0xFF3a1a26),
  heading: Color(0xFFb5385a),
  accent: Color(0xFFd45c7a),
  muted: Color(0xFFb890a0),
  border: Color(0xFFe8c0cc),
  lines: Color(0xFFf0d5de),
  appBarBg: Color(0xFFc45070),
  appBarFg: Color(0xFFfdf5f7),
  brightness: Brightness.light,
);

const paperThemeForest = PaperTheme(
  id: 'forest',
  name: 'Forest',
  dot: Color(0xFF5aaa6e),
  bg: Color(0xFF0d1a0f),
  paper: Color(0xFF141f16),
  card: Color(0xFF1a2a1c),
  ink: Color(0xFFd0f0d8),
  heading: Color(0xFF7dcc90),
  accent: Color(0xFF5aaa6e),
  muted: Color(0xFF5a8064),
  border: Color(0xFF243828),
  lines: Color(0xFF1e2e20),
  appBarBg: Color(0xFF0d1a0f),
  appBarFg: Color(0xFF7dcc90),
  brightness: Brightness.dark,
);

const List<PaperTheme> allPaperThemes = [
  paperThemeMidnight,
  paperThemeParchment,
  paperThemeMoonlit,
  paperThemeDawn,
  paperThemeForest,
];

PaperTheme paperThemeById(String id) =>
    allPaperThemes.firstWhere((t) => t.id == id, orElse: () => paperThemeMidnight);

// ── Material ThemeData from a PaperTheme ─────────────────────────────────────

ThemeData buildMaterialTheme(PaperTheme p) {
  final isDark = p.brightness == Brightness.dark;
  final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: p.accent,
      secondary: p.muted,
      surface: p.card,
      onSurface: p.ink,
      onPrimary: isDark ? p.bg : Colors.white,
    ),
    textTheme: GoogleFonts.cormorantTextTheme(base.textTheme).apply(
      bodyColor: p.ink,
      displayColor: p.heading,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.appBarBg,
      foregroundColor: p.appBarFg,
      elevation: 0,
      titleTextStyle: GoogleFonts.cinzelDecorative(
        color: p.appBarFg,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.border, width: 0.8),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: isDark ? p.bg : Colors.white,
      elevation: 4,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      hintStyle: TextStyle(color: p.muted),
      labelStyle: TextStyle(color: p.muted),
    ),
    dividerColor: p.border,
    iconTheme: IconThemeData(color: p.muted),
  );
}
