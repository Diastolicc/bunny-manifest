import 'package:flutter/material.dart';

class AppTheme {
  // ===== CHANGE THIS ONE LINE TO SWITCH THEMES =====
  static const ThemeMode _currentTheme = ThemeMode.blue;
  // =================================================

  // Theme definitions
  static const Map<ThemeMode, AppColorScheme> _themes = {
    ThemeMode.blue: AppColorScheme(
      primary: Color(0xFF8d58b5), // Violet Purple
      secondary: Color(0xFFA78BFA), // Light Purple
      accent: Color(0xFFC4B5FD), // Lighter Purple
      background: Color(0xFFF8FAFC), // Clean white background
      surface: Colors.white,
      text: Color(0xFF1E293B), // Dark text for contrast
      textSecondary: Color(0xFF64748B), // Medium gray secondary text
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      error: Color(0xFFEF4444),
      card: Colors.white,
      cardBorder: Color(0xFFE2E8F0), // Subtle border
      shadow: Color(0x1A000000),
      overlay: Color(0x80000000),
    ),
    ThemeMode.pink: AppColorScheme(
      primary: Color(0xFFEC4899),
      secondary: Color(0xFFF472B6),
      accent: Color(0xFFF9A8D4),
      background: Color(0xFFFDF2F8),
      surface: Colors.white,
      text: Color(0xFF581C87),
      textSecondary: Color(0xFFA855F7),
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      error: Color(0xFFEF4444),
      card: Colors.white,
      cardBorder: Color(0xFFFCE7F3),
      shadow: Color(0x1A000000),
      overlay: Color(0x80000000),
    ),
    ThemeMode.red: AppColorScheme(
      primary: Color(0xFFDC2626),
      secondary: Color(0xFFEF4444),
      accent: Color(0xFFF87171),
      background: Color(0xFFFEF2F2),
      surface: Colors.white,
      text: Color(0xFF7F1D1D),
      textSecondary: Color(0xFFB91C1C),
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      error: Color(0xFFDC2626),
      card: Colors.white,
      cardBorder: Color(0xFFFEE2E2),
      shadow: Color(0x1A000000),
      overlay: Color(0x80000000),
    ),
    ThemeMode.green: AppColorScheme(
      primary: Color(0xFF059669),
      secondary: Color(0xFF10B981),
      accent: Color(0xFF34D399),
      background: Color(0xFFF0FDF4),
      surface: Colors.white,
      text: Color(0xFF064E3B),
      textSecondary: Color(0xFF047857),
      success: Color(0xFF059669),
      warning: Color(0xFFF59E0B),
      error: Color(0xFFEF4444),
      card: Colors.white,
      cardBorder: Color(0xFFD1FAE5),
      shadow: Color(0x1A000000),
      overlay: Color(0x80000000),
    ),
    ThemeMode.purple: AppColorScheme(
      primary: Color(0xFF7C3AED),
      secondary: Color(0xFF8B5CF6),
      accent: Color(0xFFA78BFA),
      background: Color(0xFFFAF5FF),
      surface: Colors.white,
      text: Color(0xFF4C1D95),
      textSecondary: Color(0xFF7C3AED),
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      error: Color(0xFFEF4444),
      card: Colors.white,
      cardBorder: Color(0xFFEDE9FE),
      shadow: Color(0x1A000000),
      overlay: Color(0x80000000),
    ),
    ThemeMode.orange: AppColorScheme(
      primary: Color(0xFFEA580C),
      secondary: Color(0xFFF97316),
      accent: Color(0xFFFB923C),
      background: Color(0xFFFEFEFE),
      surface: Colors.white,
      text: Color(0xFF7C2D12),
      textSecondary: Color(0xFFC2410C),
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      error: Color(0xFFEF4444),
      card: Colors.white,
      cardBorder: Color(0xFFFED7AA),
      shadow: Color(0x1A000000),
      overlay: Color(0x80000000),
    ),
    ThemeMode.modern: AppColorScheme(
      primary: Color(0xFF6B7280), // Light gray (dominant 60%)
      secondary: Color(0xFF3B82F6), // Blue (secondary 30%)
      accent: Color(0xFFEC4899), // High-contrast pink (accent 10%)
      background: Color(0xFFF9FAFB), // Very light gray (dominant)
      surface: Colors.white, // White (dominant)
      text: Color(0xFF374151), // Dark gray text
      textSecondary: Color(0xFF6B7280), // Medium gray secondary text
      success: Color(0xFF10B981),
      warning: Color(0xFFF59E0B),
      error: Color(0xFFEF4444),
      card: Colors.white,
      cardBorder: Color(0xFFE5E7EB), // Light gray borders
      shadow: Color(0x1A000000),
      overlay: Color(0x80000000),
    ),
  };

  // Get current theme colors
  static AppColorScheme get colors => _themes[_currentTheme]!;

  // Get current theme mode
  static ThemeMode get currentTheme => _currentTheme;

  // Get all available themes
  static List<ThemeMode> get availableThemes => _themes.keys.toList();

  // Check if current theme is a specific theme
  static bool get isBlue => _currentTheme == ThemeMode.blue;
  static bool get isPink => _currentTheme == ThemeMode.pink;
  static bool get isRed => _currentTheme == ThemeMode.red;
  static bool get isGreen => _currentTheme == ThemeMode.green;
  static bool get isPurple => _currentTheme == ThemeMode.purple;
  static bool get isOrange => _currentTheme == ThemeMode.orange;
}

// Theme modes enum
enum ThemeMode {
  blue,
  pink,
  red,
  green,
  purple,
  orange,
  modern,
}

// Color scheme class
class AppColorScheme {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color text;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color error;
  final Color card;
  final Color cardBorder;
  final Color shadow;
  final Color overlay;

  const AppColorScheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.error,
    required this.card,
    required this.cardBorder,
    required this.shadow,
    required this.overlay,
  });

  // Convenience getters for common color combinations
  Color get primaryLight => primary.withValues(alpha: 0.8);
  Color get primaryDark => primary.withValues(alpha: 0.8);
  Color get secondaryLight => secondary.withValues(alpha: 0.8);
  Color get secondaryDark => secondary.withValues(alpha: 0.8);
  Color get accentLight => accent.withValues(alpha: 0.8);
  Color get accentDark => accent.withValues(alpha: 0.8);

  // Text color variations
  Color get textLight => text.withValues(alpha: 0.7);
  Color get textLighter => text.withValues(alpha: 0.5);
  Color get textDark => text.withValues(alpha: 0.9);

  // Background variations
  Color get backgroundLight => background.withValues(alpha: 0.95);
  Color get backgroundDark => background.withValues(alpha: 0.98);

  // Card variations
  Color get cardLight => card.withValues(alpha: 0.95);
  Color get cardDark => card.withValues(alpha: 0.98);

  // Shadow variations
  Color get shadowLight => shadow.withValues(alpha: 0.1);
  Color get shadowMedium => shadow.withValues(alpha: 0.2);
  Color get shadowDark => shadow.withValues(alpha: 0.3);
}
