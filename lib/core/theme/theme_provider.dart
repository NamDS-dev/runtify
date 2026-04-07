import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeKey = 'runtify_theme_mode';

// 테마 모드 상태 관리 (라이트 / 다크 / 기기 설정)
// 앱 재시작 시 SharedPreferences에서 마지막 설정을 복원
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(super.initial);

  // 테마 변경 + SharedPreferences 저장
  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  // main.dart에서 override로 초기값(저장된 테마)을 주입
  return ThemeNotifier(ThemeMode.system);
});

// SharedPreferences에서 저장된 테마 로드 (main.dart에서 호출)
Future<ThemeMode> loadSavedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_themeKey);
  return ThemeMode.values.firstWhere(
    (e) => e.name == value,
    orElse: () => ThemeMode.system,
  );
}
