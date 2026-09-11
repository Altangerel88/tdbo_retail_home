import 'package:flutter/material.dart';

/// Design tokens for the TDBO "A · Retail" home — Figma TDBO 2.0 mobile
/// (FVPs4KhiqJbNNbAsqIDBn6), node 74444:14342, the yellow/black recolor.
class T {
  // Figma variables
  static const yellow = Color(0xFFFCC006); // ui/Accent/Yellow/Primary
  static const ink = Color(0xFF242424); // Main/Black/Primary

  // Surfaces
  static const navy = Color(0xFF020E25); // original Figma header ground
  // Header ground: brand charcoal #242424 taken 40% toward black.
  static const inkDeep = Color(0xFF161616);
  static const surface = Color(0xFFFFFFFF);
  static const plate = Color(0xFFF7F7F7); // quick-action icon plates

  // Text
  static const black = Color(0xFF000000);
  static const muted = Color(0xFF75808A); // transaction dates
  static const label = Color(0x8C000000); // section label, black @ 55%

  // Transactions
  static const green = Color(0xFF28A745);
  static const greenBg = Color(0xFFF4FBF6);
  static const outBg = Color(0x80E1E1E1); // #E1E1E1 @ 50%

  static const font = 'Manrope';
}

/// Manrope text style. Weights map to the bundled TTFs:
/// 400 Regular · 500 Medium · 600 SemiBold · 700 Bold · 800 ExtraBold
TextStyle mr(
  double size,
  FontWeight weight,
  Color color, {
  double? ls,
  double? height,
}) => TextStyle(
  fontFamily: T.font,
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: ls,
  height: height,
);
