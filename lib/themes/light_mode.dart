import 'package:flutter/material.dart';
import 'app_colors.dart';

// ============================================
// CAMPUS LINK LIGHT MODE THEME
// ============================================

final ThemeData lightMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,

  // --- COLOR SCHEME ---
  colorScheme: const ColorScheme.light(
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightOnPrimary,
    secondary: AppColors.lightSecondary,
    onSecondary: AppColors.lightOnSecondary,
    tertiary: AppColors.lightTertiary,
    surface: AppColors.lightSurface,
    error: AppColors.lightError,
  ),

  // --- SCAFFOLD ---
  scaffoldBackgroundColor: AppColors.lightSurface,

  // --- APP BAR ---
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.lightPrimary,
    foregroundColor: AppColors.lightOnPrimary,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.lightOnPrimary,
    ),
    iconTheme: IconThemeData(color: AppColors.lightOnPrimary),
  ),

  // --- CARDS ---
  cardTheme: CardThemeData(
    color: AppColors.lightSurfaceContainer,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  ),

  // --- INPUT FIELDS ---
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.lightSurfaceContainer,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightPrimary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.lightError),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: const TextStyle(color: AppColors.lightTextTertiary),
  ),

  // --- BUTTONS ---
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.lightPrimary,
      foregroundColor: AppColors.lightOnPrimary,
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.lightPrimary,
      side: const BorderSide(color: AppColors.lightPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.lightPrimary,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  ),

  // --- FLOATING ACTION BUTTON ---
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.lightSecondary,
    foregroundColor: AppColors.lightOnSecondary,
    elevation: 4,
  ),

  // --- BOTTOM NAVIGATION ---
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.lightSurfaceContainer,
    selectedItemColor: AppColors.lightPrimary,
    unselectedItemColor: AppColors.lightTextTertiary,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),

  // --- NAVIGATION BAR (MATERIAL 3) ---
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: AppColors.lightSurfaceContainer,
    indicatorColor: AppColors.lightPrimary.withValues(alpha: 0.2),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.lightPrimary,
        );
      }
      return const TextStyle(
        fontSize: 12,
        color: AppColors.lightTextTertiary,
      );
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: AppColors.lightPrimary);
      }
      return const IconThemeData(color: AppColors.lightTextTertiary);
    }),
  ),

  // --- CHIPS ---
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.lightSurfaceContainer,
    selectedColor: AppColors.lightTertiary,
    labelStyle: const TextStyle(fontSize: 12),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.lightBorder),
    ),
  ),

  // --- DIVIDERS ---
  dividerTheme: const DividerThemeData(
    color: AppColors.lightBorder,
    thickness: 1,
  ),

  // --- TEXT THEME ---
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: AppColors.lightTextPrimary,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.lightTextPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.lightTextPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.lightTextPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.lightTextPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.lightTextPrimary,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: AppColors.lightTextPrimary),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.lightTextSecondary),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.lightTextTertiary),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.lightTextPrimary,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.lightTextSecondary,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppColors.lightTextTertiary,
    ),
  ),

  // --- ICONS ---
  iconTheme: const IconThemeData(color: AppColors.lightTextSecondary),

  // --- SNACKBAR ---
  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.lightTextPrimary,
    contentTextStyle: const TextStyle(color: Colors.white),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    behavior: SnackBarBehavior.floating,
  ),

  // --- DIALOG ---
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.lightSurfaceContainer,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),

  // --- BOTTOM SHEET ---
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: AppColors.lightSurfaceContainer,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
  ),
);