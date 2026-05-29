import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/storefront_api.dart';

class AppTheme {
  static const Color fallbackPrimary = Color(0xFF061008);
  static const Color fallbackBackground = Color(0xFFF8FAF5);
  static const Color fallbackPrimaryContainer = Color(0xFF1B261D);
  static const Color fallbackOnPrimaryContainer = Color(0xFF818E82);
  static const Color fallbackSecondary = Color(0xFF5E5E5B);
  static const Color fallbackAccent = Color(0xFFE9E2D0);
  static const Color fallbackBorder = Color(0xFFC4C8C1);
  static const Color fallbackSuccess = Color(0xFF556156);

  static Color primary = fallbackPrimary;
  static Color background = fallbackBackground;
  static Color surface = fallbackBackground;
  static Color primaryContainer = fallbackPrimaryContainer;
  static Color onPrimaryContainer = fallbackOnPrimaryContainer;
  static Color secondary = fallbackSecondary;
  static Color accent = fallbackAccent;
  static Color border = fallbackBorder;
  static Color success = fallbackSuccess;

  static ThemeData get lightTheme => lightThemeFor();

  static ThemeData lightThemeFor([StoreBranding? branding]) {
    final primaryColor = _colorFromHex(branding?.primaryColor, fallbackPrimary);
    final secondaryColor =
        _colorFromHex(branding?.secondaryColor, fallbackSecondary);
    final accentColor = _colorFromHex(branding?.accentColor, fallbackAccent);
    final textColor = _colorFromHex(branding?.textColor, primaryColor);
    final backgroundColor =
        _colorFromHex(branding?.backgroundColor, fallbackBackground);
    final borderColor = _soften(secondaryColor);
    final successColor = _colorFromHex(null, fallbackSuccess);
    final primaryContainerColor = _darken(primaryColor);
    final onPrimaryContainerColor = _soften(accentColor);

    primary = primaryColor;
    secondary = secondaryColor;
    accent = accentColor;
    background = backgroundColor;
    surface = backgroundColor;
    primaryContainer = primaryContainerColor;
    onPrimaryContainer = onPrimaryContainerColor;
    border = borderColor;
    success = successColor;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: backgroundColor,
        onSurface: textColor,
        onPrimary: Colors.white,
        primaryContainer: primaryContainerColor,
        onPrimaryContainer: onPrimaryContainerColor,
        outlineVariant: borderColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: GoogleFonts.ebGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: primaryColor,
          letterSpacing: 1.5,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.ebGaramond(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        titleLarge: GoogleFonts.ebGaramond(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        bodyLarge: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 13,
          color: secondaryColor,
        ),
        labelLarge: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 1.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: borderColor, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: borderColor, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: primaryColor, width: 1.2),
        ),
        hintStyle: GoogleFonts.manrope(
          color: secondaryColor.withValues(alpha: 0.6),
          fontSize: 13,
        ),
      ),
    );
  }

  static Color _colorFromHex(String? value, Color fallback) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    final hex = value.trim().replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }

  static Color _darken(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * 0.72).clamp(0.0, 1.0)).toColor();
  }

  static Color _soften(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 0.45).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0))
        .toColor();
  }
}
