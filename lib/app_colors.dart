import 'package:flutter/material.dart';

class AppColors {
  static bool isLight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light;
  }

  static Color background(BuildContext context) {
    return isLight(context)
        ? const Color(0xFFF7F1EA)
        : const Color(0xFF0B0B0F);
  }

  static Color surface(BuildContext context) {
    return isLight(context)
        ? const Color(0xFFFFFBF5)
        : const Color(0xFF17171C);
  }

  static Color surfaceSoft(BuildContext context) {
    return isLight(context)
        ? const Color(0xFFF0E4D8)
        : const Color(0xFF202633);
  }

  static Color card(BuildContext context) {
    return isLight(context)
        ? const Color(0xFFFFF7EF)
        : const Color(0xFF17171C);
  }

  static Color chip(BuildContext context) {
    return isLight(context)
        ? const Color(0xFFEAD7C5)
        : const Color(0xFF2A2A33);
  }

  static Color primaryText(BuildContext context) {
    return isLight(context)
        ? const Color(0xFF241B18)
        : Colors.white;
  }

  static Color secondaryText(BuildContext context) {
    return isLight(context)
        ? const Color(0xFF665650)
        : Colors.white70;
  }

  static Color mutedText(BuildContext context) {
    return isLight(context)
        ? const Color(0xFF9A8177)
        : Colors.white54;
  }

  static Color subtleText(BuildContext context) {
    return isLight(context)
        ? const Color(0xFFB0978C)
        : Colors.white38;
  }

  static Color border(BuildContext context) {
    return isLight(context)
        ? const Color(0xFFE1CBBE)
        : Colors.white.withValues(alpha: 0.08);
  }

  static Color accent(BuildContext context) {
    return isLight(context)
        ? const Color(0xFF9C6BFF)
        : const Color(0xFFB8D3FF);
  }

  static Color avatarGlow(Color moodColor, BuildContext context) {
    return isLight(context)
        ? moodColor.withValues(alpha: 0.62)
        : moodColor.withValues(alpha: 0.38);
  }

  static Color avatarGlowSoft(Color moodColor, BuildContext context) {
    return isLight(context)
        ? moodColor.withValues(alpha: 0.26)
        : moodColor.withValues(alpha: 0.12);
  }
}