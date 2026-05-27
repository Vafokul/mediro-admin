import 'package:flutter/material.dart';

class AppColors {
  // ── Primary Emerald ─────────────────────────────────────
  static const Color primary = Color(0xFF198754);          // Emerald Green
  static const Color primaryDark = Color(0xFF0D6B43);      // Pressed/hover
  static const Color primaryLight = Color(0xFFD1F2E3);     // Chip / badge bg
  static const Color primarySurface = Color(0xFFF0FAF5);   // Page tint bg

  // Alias: eski kod bilan moslik
  static const Color healixGreen = primary;

  // ── Neutrals ────────────────────────────────────────────
  static const Color surface = Color(0xFFF6F7FB);          // Scaffold bg
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEAEDF2);
  static const Color divider = Color(0xFFF0F2F5);

  // ── Text ────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // ── Semantic ─────────────────────────────────────────────
  static const Color error = Color(0xFFDC3545);
  static const Color warning = Color(0xFFFF9800);
  static const Color discount = Color(0xFFE53935);

  // ── Shadow helper ────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}
