import 'package:flutter/material.dart';

/// 应用主题：对应预览图里的绿色 MD3 风格
class AppTheme {
  static const _seed = Color(0xFF3D6E54);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    return _build(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surface,
        elevation: 0,
      ),
    );
  }
}

/// 信号/状态等级颜色：与预览图里的红黄绿灯一致
class StatusColors {
  static Color rssi(BuildContext context, int rssi) {
    if (rssi >= 35) return const Color(0xFF2E7D4F); // 绿
    if (rssi >= 25) return const Color(0xFFB8860B); // 黄
    return const Color(0xFFC5402F); // 红
  }
}

enum AppThemeMode { system, light, dark }
