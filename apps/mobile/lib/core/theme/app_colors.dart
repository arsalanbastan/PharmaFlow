import 'package:flutter/material.dart';

/// =======================================================
/// PharmaFlow Color System
/// =======================================================

abstract final class AppColors {
  AppColors._();

  // =========================
  // Brand
  // =========================

  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFFE8F5E9);
  static const Color primaryDark = Color(0xFF1B5E20);

  // =========================
  // Secondary
  // =========================

  static const Color secondary = Color(0xFF2962FF);
  static const Color secondaryLight = Color(0xFFEAF1FF);

  // =========================
  // Background
  // =========================

  static const Color scaffold = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color card = Colors.white;

  // =========================
  // Text
  // =========================

  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textDisabled = Color(0xFFADB5BD);

  // =========================
  // Border
  // =========================

  static const Color border = Color(0xFFE9ECEF);
  static const Color divider = Color(0xFFF1F3F5);

  // =========================
  // Status
  // =========================

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFE53935);
  static const Color info = Color(0xFF1976D2);

  // =========================
  // Cards
  // =========================

  static const Color bankRefah = Color(0xFFE91E63);
  static const Color bankSaman = Color(0xFF1976D2);
  static const Color bankMellat = Color(0xFF43A047);
  static const Color bankTejarat = Color(0xFF00897B);

  // =========================
  // Icons
  // =========================

  static const Color icon = Color(0xFF495057);
  static const Color iconLight = Color(0xFF868E96);

  // =========================
  // Shadow
  // =========================

  static const Color shadow = Color(0x14000000);
}