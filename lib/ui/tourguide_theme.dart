import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class TourguideTheme {
  //Colors
  static const Color tourguideColor = Color(0xff006a65);
  static const Color primaryColor = Color(0xff6fece4);
  static const Color textColorDarkTheme = Colors.white;

  //Themes
  static final ThemeData lightTheme = _buildTheme(
    brightness: Brightness.light,
  );

  static final ThemeData darkTheme = _buildTheme(
    brightness: Brightness.dark,
  );

  //Theme builder
  static ThemeData _buildTheme({
      required Brightness brightness,
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
      //scaffoldBackgroundColor: backgroundColor,
      extensions: <ThemeExtension<dynamic>>[
        const TourguideColors(        //TODO - this is an example and not in use atm - check necessity and otherwise remove?
          brandColor: Color(0xFF006a65),
          danger: Color(0xFFE53935),
        ),
      ],
      textTheme: GoogleFonts.latoTextTheme(textTheme).copyWith(
        // Titles are GoogleFonts Lato with bold styling
        displayLarge: GoogleFonts.vollkorn(textStyle: textTheme.displayLarge,
            fontWeight: FontWeight.w400),
        displayMedium: GoogleFonts.vollkorn(textStyle: textTheme.displayMedium,
            fontWeight: FontWeight.w400),
        displaySmall: GoogleFonts.vollkorn(textStyle: textTheme.displaySmall,
            fontWeight: FontWeight.w400),
        headlineLarge: GoogleFonts.lato(textStyle: textTheme.headlineLarge,
            fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.lato(textStyle: textTheme.headlineMedium,
            fontWeight: FontWeight.bold),
        headlineSmall: GoogleFonts.lato(textStyle: textTheme.headlineSmall,
            fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.lato(textStyle: textTheme.titleLarge,
            fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.lato(textStyle: textTheme.titleMedium,
            fontWeight: FontWeight.bold),
        titleSmall: GoogleFonts.lato(textStyle: textTheme.titleSmall,
            fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

//Custom Colors
@immutable
class TourguideColors extends ThemeExtension<TourguideColors> {
  const TourguideColors({
    required this.brandColor,
    required this.danger,
  });

  final Color? brandColor;
  final Color? danger;

  @override
  TourguideColors copyWith({Color? brandColor, Color? danger}) {
    return TourguideColors(
      brandColor: brandColor ?? this.brandColor,
      danger: danger ?? this.danger,
    );
  }

  @override
  TourguideColors lerp(TourguideColors? other, double t) {
    if (other is! TourguideColors) {
      return this;
    }
    return TourguideColors(
      brandColor: Color.lerp(brandColor, other.brandColor, t),
      danger: Color.lerp(danger, other.danger, t),
    );
  }

  // Optional
  @override
  String toString() => 'TourguideColors(brandColor: $brandColor, danger: $danger)';
}