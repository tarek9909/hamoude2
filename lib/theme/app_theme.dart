import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/storefront_api.dart';

class AppTheme {
  static const Color _emergencyPrimary = Color(0xFF2E4A3F);

  static Color primary = _emergencyPrimary;
  static Color background = _surfaceFrom(_emergencyPrimary);
  static Color surface = _surfaceFrom(_emergencyPrimary);
  static Color primaryContainer = _darken(_emergencyPrimary);
  static Color onPrimaryContainer = _soften(_accentFrom(_emergencyPrimary));
  static Color secondary = _soften(_emergencyPrimary);
  static Color accent = _accentFrom(_emergencyPrimary);
  static Color border = _soften(_emergencyPrimary);
  static Color success = _successFrom(_emergencyPrimary);

  static ThemeData get lightTheme => lightThemeFor();

  static ThemeData lightThemeFor([StoreBranding? branding]) {
    final primaryColor =
        _colorFromHex(branding?.primaryColor) ?? _emergencyPrimary;
    final secondaryColor =
        _colorFromHex(branding?.secondaryColor) ?? _soften(primaryColor);
    final accentColor =
        _colorFromHex(branding?.accentColor) ?? _accentFrom(primaryColor);
    final textColor = _colorFromHex(branding?.textColor) ?? primaryColor;
    final backgroundColor =
        _colorFromHex(branding?.backgroundColor) ?? _surfaceFrom(primaryColor);
    final borderColor = _soften(secondaryColor);
    final successColor = _successFrom(primaryColor);
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryColor,
        contentTextStyle: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1),
        ),
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

  static Color? _colorFromHex(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final hex = value.trim().replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? null : Color(parsed);
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

  static Color _accentFrom(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withHue((hsl.hue + 42) % 360)
        .withSaturation((hsl.saturation * 0.32).clamp(0.08, 0.3))
        .withLightness(0.88)
        .toColor();
  }

  static Color _surfaceFrom(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 0.18).clamp(0.02, 0.14))
        .withLightness(0.97)
        .toColor();
  }

  static Color _successFrom(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 0.7).clamp(0.18, 0.5))
        .withLightness((hsl.lightness * 0.88).clamp(0.28, 0.48))
        .toColor();
  }
}
