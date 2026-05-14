import 'package:flutter/material.dart';

// ============================================
// CAMPUS LINK COLOR PALETTE
// Shared colors for both light and dark modes
// ============================================

class AppColors {
  // --- BACKWARD-COMPATIBLE ALIASES (for code still using old names) ---
  static const Color primary = lightPrimary;
  static const Color primaryDark = lightOnPrimary;
  static const Color divider = lightBorder;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color instructorPurple = Color(0xFF7B1FA2); // Purple for instructor badges
  static const Color drawerHeader = lightPrimary; // Drawer header background
  static const Color unreadBadge = urgentRed; // Unread notification badge

  // --- PRIMARY COLORS ---
  //
  // Light Mode Primary
  static const Color lightPrimary = Color(0xFF3BB77E); // Green Forest
  static const Color lightOnPrimary = Color(
    0xFFFFFFFF,
  ); // White text on primary

  // Dark Mode Primary
  static const Color darkPrimary = Color(0xFFCF6679); // Lighter maroon for dark
  static const Color darkOnPrimary = Color(
    0xFF690003,
  ); // Dark text on light primary

  // --- SECONDARY COLORS ---

  // Light Mode Secondary
  static const Color lightSecondary = Color(0xFF8FBC8F); // Soft Sage
  static const Color lightOnSecondary = Color(
    0xFFFFFFFF,
  ); // White text on secondary

  // Dark Mode Secondary
  static const Color darkSecondary = Color(0xFF90CAF9); // Light blue
  static const Color darkOnSecondary = Color(
    0xFF002244,
  ); // Dark text on light secondary

  // --- TERTIARY/ACCENT COLORS ---

  static const Color lightTertiary = Color(
    0xFFF5F5DC,
  ); // Warm Beige (Light mode)
  static const Color darkTertiary = Color(
    0xFFFFD54F,
  ); // Brighter gold (Dark mode)

  // --- SURFACE COLORS ---

  static const Color lightSurface = Color(0xFFFAFAFA); // Light background
  static const Color lightSurfaceContainer = Color(
    0xFFFFFFFF,
  ); // Card background 

  static const Color darkSurface = Color(0xFF121212); // Dark background
  static const Color darkSurfaceContainer = Color(
    0xFF1E1E1E,
  ); // Card background

  // --- ERROR COLORS ---

  static const Color lightError = Color(0xFFBA1A1A); // Error red (Light mode)
  static const Color darkError = Color(0xFFCF6679); // Error red (Dark mode)

  // --- PRIORITY/STATUS COLORS ---

  static const Color urgentRed = Color(0xFFD32F2F); // Urgent priority / overdue
  static const Color priorityOrange = Color(0xFFF57C00); // Medium priority
  static const Color standardBlue = Color(0xFF1976D2); // Standard priority
  static const Color successGreen = Color(0xFF388E3C); // Success/Submitted
  static const Color doneGreen = Color(0xFF4CAF50); // Task completed
  static const Color pendingYellow = Color(0xFFFFA000); // Task nearing deadline

  // --- TEXT COLORS ---

  static const Color lightTextPrimary = Color(0xFF1A1A1A); // Main text (Light)
  static const Color lightTextSecondary = Color(
    0xFF555555,
  ); // Secondary text (Light)
  static const Color lightTextTertiary = Color(
    0xFF777777,
  ); // Tertiary text (Light)

  static const Color darkTextPrimary = Color(0xFFE0E0E0); // Main text (Dark)
  static const Color darkTextSecondary = Color(
    0xFFBBBBBB,
  ); // Secondary text (Dark)
  static const Color darkTextTertiary = Color(
    0xFF999999,
  ); // Tertiary text (Dark)

  // --- BORDER/DIVIDER COLORS ---

  static const Color lightBorder = Color(0xFFE0E0E0); // Light mode borders
  static const Color darkBorder = Color(0xFF333333); // Dark mode borders
}
