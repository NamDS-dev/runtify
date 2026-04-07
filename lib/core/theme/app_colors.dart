import 'package:flutter/material.dart';

// 테마별 색상 세트 (라이트/다크 공통 진입점)
// 사용법: context.colors.primary / context.colors.background 등
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color background;
  final Color surface;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;

  // Sunset Fire 라이트 팔레트
  static const AppColors light = AppColors(
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFF2F2F2),
    cardColor: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0D0D0D),
    textSecondary: Color(0xFF6B6B6B),
  );

  // Sunset Fire 다크 팔레트
  static const AppColors dark = AppColors(
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF1A1A1A),
    cardColor: Color(0xFF252525),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9E9E9E),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? cardColor,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      cardColor: cardColor ?? this.cardColor,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

// 편리하게 접근하는 BuildContext 확장
// 사용 예시: context.colors.cardColor
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
