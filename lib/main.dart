import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(const RouterDashboardApp());
}

class RouterDashboardApp extends StatefulWidget {
  const RouterDashboardApp({super.key});

  @override
  State<RouterDashboardApp> createState() => _RouterDashboardAppState();
}

class _RouterDashboardAppState extends State<RouterDashboardApp> {
  AppConfig? _config;
  String _themeMode = 'system';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await StorageService.load();
    setState(() {
      _config = c;
      _themeMode = c.themeMode;
    });
  }

  ThemeMode get _flutterThemeMode {
    switch (_themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_config == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: '家络看板',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _flutterThemeMode,
      home: _config!.isConfigured
          ? HomeScreen(
              config: _config!,
              onConfigChanged: (c) {
                setState(() => _config = c);
                StorageService.save(c);
              },
              onThemeModeChanged: (mode) {
                setState(() => _themeMode = mode);
              },
            )
          : OnboardingScreen(
              config: _config!,
              onFinished: (c) {
                setState(() {
                  _config = c;
                  _themeMode = c.themeMode;
                });
              },
            ),
    );
  }
}
