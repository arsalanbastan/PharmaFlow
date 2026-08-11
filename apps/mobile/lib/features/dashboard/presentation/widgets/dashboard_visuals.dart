import 'package:flutter/material.dart';

class DashboardAmountThresholds {
  const DashboardAmountThresholds({
    required this.green,
    required this.orange,
    required this.red,
  });

  final int green;
  final int orange;
  final int red;
}

const DashboardAmountThresholds defaultDashboardAmountThresholds =
    DashboardAmountThresholds(
      green: 600000000,
      orange: 700000000,
      red: 800000000,
    );

class DashboardThemeColors {
  DashboardThemeColors._();

  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0x120F172A);
  static const Color shadow = Color(0x120F172A);
  static const Color surface = Colors.white;

  static const Color green = Color(0xFF1B8A4B);
  static const Color greenSoft = Color(0xFFEAF7EE);
  static const Color greenSoftAlt = Color(0xFFDFF4E6);

  static const Color orange = Color(0xFFC77710);
  static const Color orangeSoft = Color(0xFFFFF0DB);
  static const Color orangeSoftAlt = Color(0xFFFFE3B8);

  static const Color red = Color(0xFFB42318);
  static const Color redSoft = Color(0xFFFFE8E6);
  static const Color redSoftAlt = Color(0xFFFED9D5);

  static const Color headerGreen = Color(0xFF2F8F4E);
  static const Color headerGreenDark = Color(0xFF1C6E3A);
  static const Color headerHighlight = Color(0x26FFFFFF);
}

DashboardAmountTone dashboardAmountTone(
  int amount, {
  required DashboardAmountThresholds thresholds,
}) {
  if (amount < thresholds.green) {
    return DashboardAmountTone.green;
  }

  if (amount < thresholds.orange) {
    return DashboardAmountTone.orange;
  }

  if (amount < thresholds.red) {
    return DashboardAmountTone.red;
  }

  return DashboardAmountTone.red;
}

Color dashboardAmountColor(
  int amount, {
  required DashboardAmountThresholds thresholds,
}) {
  switch (dashboardAmountTone(amount, thresholds: thresholds)) {
    case DashboardAmountTone.green:
      return DashboardThemeColors.green;
    case DashboardAmountTone.orange:
      return DashboardThemeColors.orange;
    case DashboardAmountTone.red:
      return DashboardThemeColors.red;
  }
}

Color dashboardSoftAmountColor(
  int amount, {
  required DashboardAmountThresholds thresholds,
}) {
  switch (dashboardAmountTone(amount, thresholds: thresholds)) {
    case DashboardAmountTone.green:
      return DashboardThemeColors.greenSoft;
    case DashboardAmountTone.orange:
      return DashboardThemeColors.orangeSoft;
    case DashboardAmountTone.red:
      return DashboardThemeColors.redSoft;
  }
}

Color dashboardSoftAmountBorderColor(
  int amount, {
  required DashboardAmountThresholds thresholds,
}) {
  switch (dashboardAmountTone(amount, thresholds: thresholds)) {
    case DashboardAmountTone.green:
      return DashboardThemeColors.greenSoftAlt;
    case DashboardAmountTone.orange:
      return DashboardThemeColors.orangeSoftAlt;
    case DashboardAmountTone.red:
      return DashboardThemeColors.redSoftAlt;
  }
}

enum DashboardAmountTone { green, orange, red }
