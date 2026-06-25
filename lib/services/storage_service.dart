import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 自定义命名映射的一条记录
class CustomMacEntry {
  String mac;
  String name;
  String? iconKey; // DeviceIcon 里 _byKey 支持的 key，可为空表示不覆盖图标
  CustomMacEntry({required this.mac, required this.name, this.iconKey});

  Map<String, dynamic> toJson() => {'mac': mac, 'name': name, 'icon': iconKey};
  factory CustomMacEntry.fromJson(Map<String, dynamic> j) => CustomMacEntry(
        mac: j['mac'],
        name: j['name'],
        iconKey: j['icon'],
      );
}

class AppConfig {
  String routerUrl;
  String username;
  String password;
  String? subRouterMac;
  String? lockMac;
  Set<String> permanentMacs; // 常驻设备，统计个人在线数时排除
  Set<String> favoriteMacs; // 关注设备
  List<CustomMacEntry> customNames;
  String themeMode; // system/light/dark
  int refreshSeconds;

  AppConfig({
    this.routerUrl = 'http://192.168.3.1',
    this.username = 'admin',
    this.password = '',
    this.subRouterMac,
    this.lockMac,
    Set<String>? permanentMacs,
    Set<String>? favoriteMacs,
    List<CustomMacEntry>? customNames,
    this.themeMode = 'system',
    this.refreshSeconds = 5,
  })  : permanentMacs = permanentMacs ?? {},
        favoriteMacs = favoriteMacs ?? {},
        customNames = customNames ?? [];

  bool get isConfigured => routerUrl.isNotEmpty && password.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'routerUrl': routerUrl,
        'username': username,
        'password': password,
        'subRouterMac': subRouterMac,
        'lockMac': lockMac,
        'permanentMacs': permanentMacs.toList(),
        'favoriteMacs': favoriteMacs.toList(),
        'customNames': customNames.map((e) => e.toJson()).toList(),
        'themeMode': themeMode,
        'refreshSeconds': refreshSeconds,
      };

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        routerUrl: j['routerUrl'] ?? 'http://192.168.3.1',
        username: j['username'] ?? 'admin',
        password: j['password'] ?? '',
        subRouterMac: j['subRouterMac'],
        lockMac: j['lockMac'],
        permanentMacs: {...(j['permanentMacs'] ?? []).cast<String>()},
        favoriteMacs: {...(j['favoriteMacs'] ?? []).cast<String>()},
        customNames: ((j['customNames'] ?? []) as List)
            .map((e) => CustomMacEntry.fromJson(e))
            .toList(),
        themeMode: j['themeMode'] ?? 'system',
        refreshSeconds: j['refreshSeconds'] ?? 5,
      );
}

/// 简单封装 SharedPreferences，整个配置存成一个 JSON 字符串
class StorageService {
  static const _key = 'app_config_v1';

  static Future<AppConfig> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null) return AppConfig();
    try {
      return AppConfig.fromJson(jsonDecode(raw));
    } catch (_) {
      return AppConfig();
    }
  }

  static Future<void> save(AppConfig config) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(config.toJson()));
  }
}
