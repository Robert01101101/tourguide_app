import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TourguideTheme {
  //Themes
  static final ThemeData lightTheme = _buildTheme(
    brightness: Brightness.light,
    primaryColor: TourguideColors.primaryColor,
    backgroundColor: Colors.white,
    textColor: TourguideColors.textColor,
  );

  static final ThemeData darkTheme = _buildTheme(
    brightness: Brightness.dark,
    primaryColor: Color(0xFF37474F),
    backgroundColor: Color(0xFF121212),
    textColor: Colors.white,
  );

  //Theme builder
  static ThemeData _buildTheme({
      required Brightness brightness,
      required Color primaryColor,
      required Color backgroundColor,
      required Color textColor,
    }) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
      ),
    );

    final textTheme = baseTheme.textTheme;

    return baseTheme.copyWith(
      scaffoldBackgroundColor: backgroundColor,
      textTheme: GoogleFonts.latoTextTheme(textTheme).copyWith(
        // Titles are GoogleFonts Lato with bold styling
        titleLarge: GoogleFonts.lato(textStyle: textTheme.titleLarge,
            color: textColor,
            fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.lato(textStyle: textTheme.titleMedium,
            color: textColor,
            fontWeight: FontWeight.bold),
        titleSmall: GoogleFonts.lato(textStyle: textTheme.titleSmall,
            color: textColor,
            fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.lato(textStyle: textTheme.headlineLarge,
            color: textColor,
            fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.lato(textStyle: textTheme.headlineMedium,
            color: textColor,
            fontWeight: FontWeight.bold),
        headlineSmall: GoogleFonts.lato(textStyle: textTheme.headlineSmall,
            color: textColor,
            fontWeight: FontWeight.bold),
        displayLarge: GoogleFonts.vollkorn(textStyle: textTheme.displayLarge,
            color: textColor,
            fontWeight: FontWeight.w400),
        displayMedium: GoogleFonts.vollkorn(textStyle: textTheme.displayMedium,
            color: textColor,
            fontWeight: FontWeight.w400),
        displaySmall: GoogleFonts.vollkorn(textStyle: textTheme.displaySmall,
            color: textColor,
            fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class TourguideColors {
  //Colors
  static const Color primaryColor = Color(0xff6fece4);
  static const Color textColor = Color(0xff3b4948);
}