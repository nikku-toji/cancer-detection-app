import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF1565C0);
  static const _accentColor = Color(0xFF00ACC1);
  static const _errorColor = Color(0xFFD32F2F);
  static const _warningColor = Color(0xFFF57C00);
  static const _successColor = Color(0xFF388E3C);

  // Use system font — avoids macOS sandbox network block that google_fonts triggers
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        extensions: const [
          AppColors(
            accent: _accentColor,
            error: _errorColor,
            warning: _warningColor,
            success: _successColor,
          ),
        ],
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.dark,
        ),
      );
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color accent;
  final Color error;
  final Color warning;
  final Color success;

  const AppColors({
    required this.accent,
    required this.error,
    required this.warning,
    required this.success,
  });

  @override
  AppColors copyWith(
          {Color? accent, Color? error, Color? warning, Color? success}) =>
      AppColors(
        accent: accent ?? this.accent,
        error: error ?? this.error,
        warning: warning ?? this.warning,
        success: success ?? this.success,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}
