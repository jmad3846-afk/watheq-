import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette (Sleek Deep Navy & Warm Gold)
  static const Color primary = Color(0xFF1E293B);      // Deep Slate Navy
  static const Color primaryDark = Color(0xFF0F172A);  // Dark Navy
  static const Color primaryLight = Color(0xFF334155); // Muted Navy

  static const Color accent = Color(0xFFD97706);       // Warm Amber Gold
  static const Color accentLight = Color(0xFFF59E0B);  // Bright Gold

  // Background & Surfaces
  static const Color background = Color(0xFFF8FAFC);  // Soft Grayish White
  static const Color surface = Color(0xFFFFFFFF);     // Pure White Card
  static const Color sidebarBackground = Color(0xFF0F172A); // Dark Sidebar

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status & Financial Indicators
  static const Color receivables = Color(0xFF10B981); // "لنا" - Emerald Green
  static const Color payables = Color(0xFFEF4444);    // "علينا" - Rose Red
  static const Color warning = Color(0xFFF59E0B);     // Alert / Low stock - Amber
  static const Color info = Color(0xFF3B82F6);        // Blue

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  // Shadows & Glassmorphism
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
