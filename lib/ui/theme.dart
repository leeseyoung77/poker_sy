import 'package:flutter/material.dart';

/// Modern Minimal color palette. Low-contrast dark surfaces with a single
/// teal accent for primary action and amber for highlights (pot, timers,
/// winning indicators).
class AppColors {
  AppColors._();

  // Surfaces
  static const bg = Color(0xFF121418);
  static const bgElevated = Color(0xFF1e2126);
  static const bgSunken = Color(0xFF0b0c0f);
  static const bgPanel = Color(0xCC16181c);

  // Table felt (stadium shape)
  static const feltCenter = Color(0xFF2e8548);
  static const feltMid = Color(0xFF1e6234);
  static const feltEdge = Color(0xFF174726);
  static const feltRail = Color(0x40ffffff); // inner rail line
  static const tableRim = Color(0xFF0c0d0f); // outer leather rim
  static const tableHaloCenter = Color(0xFF12311e);
  static const tableHaloEdge = Color(0xFF070c08);
  // Backwards-compat aliases used elsewhere.
  static const feltPrimary = feltCenter;
  static const feltSecondary = feltMid;
  static const feltRim = tableRim;

  // Accents
  static const accent = Color(0xFF00bfa6); // teal — primary action
  static const accentMuted = Color(0xFF00897b);
  static const highlight = Color(0xFFffb300); // amber — pot/timer/winner
  static const highlightSoft = Color(0xFFffd180);
  static const danger = Color(0xFFe25858);
  static const info = Color(0xFF5e8ab8);
  static const success = Color(0xFF4caf7d);

  // Text
  static const textPrimary = Color(0xFFe8eaed);
  static const textSecondary = Color(0xFF9aa0a6);
  static const textMuted = Color(0xFF5f6368);

  // Borders
  static const border = Color(0x22ffffff);
  static const borderStrong = Color(0x44ffffff);

  // Card
  static const cardSurface = Color(0xFFf5f4ef);
  static const cardSurfaceEdge = Color(0xFFe8e6de);
  static const cardRed = Color(0xFFe25858);
  static const cardBlack = Color(0xFF2c2c2c);
  static const cardBackTop = Color(0xFF2b323b);
  static const cardBackBottom = Color(0xFF161a1f);
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  AppRadius._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;
}
