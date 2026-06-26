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
    // 简体中文字体回退链：Windows/Android/其他平台都优先用简中字体，
    // 避免系统按 Unicode 统一码默认挑到繁体字形（比如"关"/"门"显示成台标）。
    const fontFallback = [
      'Microsoft YaHei', // Windows
      'PingFang SC', // macOS/iOS（万一之后做了）
      'Noto Sans SC', // Android / Linux 通用简中字体
      'Heiti SC',
      'sans-serif',
    ];
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamilyFallback: fontFallback,
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: base.textTheme.apply(fontFamilyFallback: fontFallback),
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
