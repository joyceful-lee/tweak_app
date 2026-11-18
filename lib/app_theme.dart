import 'package:flutter/material.dart';

/// ------------------------------
/// Fonts
/// ------------------------------
const String kTitleFont = 'Noot';
const String kHeadingFont = 'Baloo';
const String kBodyFont = 'Nunito';

/// ------------------------------
/// Color Scheme 1 (lighter)
/// ------------------------------
final ColorScheme earthyLightScheme = ColorScheme(
  primary: Color(0xFFB08D57),
  onPrimary: Color(0xFFF1EFEA), // parchment
  secondary: Color(0xFF6B8E4E),
  onSecondary: Color(0xFFF1EFEA), // parchment
  tertiary: Color(0xFFD6C3A1), // 0xFFD6C3A1
  onTertiary: Color(0xFF1F2421), // carbon black
  onTertiaryFixedVariant: Color(0xFFDFDCD6),
  surface: Colors.white,
  onSurface: Color(0xFF1F2421), // carbon black
  inverseSurface: Color(0xFF2A2F2B),
  onInverseSurface: Color(0xFFF1EFEA), // parchment
  error: Colors.red,
  onError: Colors.white,
  brightness: Brightness.light,
);

/// ------------------------------
/// Color Scheme 2 (darker)
/// ------------------------------
final ColorScheme earthyDarkScheme = ColorScheme(
  primary: Color(0xFFB08D57),
  onPrimary: Color(0xFFF1EFEA), // parchment
  secondary: Color(0xFF6B8E4E),
  onSecondary: Color(0xFFF1EFEA), // parchment
  tertiary: Color(0xFFD6C3A1),
  onTertiary: Color(0xFF1F2421), // carbon black
  onTertiaryFixedVariant: Color(0xFFF6F3EC),
  surface: Color(0xFF2A2F2B),
  onSurface: Color(0xFFF1EFEA),
  inverseSurface: Colors.white,
  onInverseSurface: Color(0xFF1F2421), // carbon black
  error: Colors.red,
  onError: Colors.white,
  brightness: Brightness.dark,
);
