import 'package:flutter/material.dart';

/// 对应路由器 HostInfo 接口返回的一条设备记录
class Device {
  final String mac;
  final String ip;
  final bool active;
  final String iconType; // 原始 IconType 字段
  final String devBrand; // DevBrands 字段，比 IconType 更可靠
  final String hostName;
  final String actualName;
  final String interfaceType; // "5GHz" / "2.4GHz"
  final String accessRecord; // "yyyy-MM-dd HH:mm:ss#1#1"
  final int rate; // 协商速率 Mbps
  final int rssi;
  final bool isWifi6; // Feature == 1
  final double upRateKBs; // 实时上传 KB/s（来自 UpRate）
  final double downRateKBs; // 实时下载 KB/s（来自 DownRate）
  final double rxKB; // 累计接收 KB
  final double txKB; // 累计发送 KB
  final Map<String, dynamic> raw; // 原始字段，详情弹窗直接展示

  Device({
    required this.mac,
    required this.ip,
    required this.active,
    required this.iconType,
    required this.devBrand,
    required this.hostName,
    required this.actualName,
    required this.interfaceType,
    required this.accessRecord,
    required this.rate,
    required this.rssi,
    required this.isWifi6,
    required this.upRateKBs,
    required this.downRateKBs,
    required this.rxKB,
    required this.txKB,
    required this.raw,
  });

  factory Device.fromJson(Map<String, dynamic> j) {
    double toD(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    int toI(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

    return Device(
      mac: (j['MACAddress'] ?? '').toString().toUpperCase(),
      ip: j['IPAddress']?.toString() ?? '',
      active: j['Active'] == true,
      iconType: j['IconType']?.toString() ?? '',
      devBrand: j['DevBrands']?.toString() ?? '',
      hostName: j['HostName']?.toString() ?? '',
      actualName: j['ActualName']?.toString() ?? '',
      interfaceType: j['InterfaceType']?.toString() ?? '',
      accessRecord: j['AccessRecord']?.toString() ?? '',
      rate: toI(j['rate']),
      rssi: toI(j['rssi']),
      isWifi6: toI(j['Feature']) == 1,
      // 路由器上报的是 KB/s
      upRateKBs: toD(j['UpRate']),
      downRateKBs: toD(j['DownRate']),
      rxKB: toD(j['RxKBytes']),
      txKB: toD(j['TxKBytes']),
      raw: j,
    );
  }

  bool get is5g => interfaceType.contains('5G');
  bool get is24g => interfaceType.contains('2.4G');

  /// 优先用 ActualName，再 HostName，最后兜底 MAC
  String get rawDisplayName {
    if (actualName.trim().isNotEmpty) return actualName;
    if (hostName.trim().isNotEmpty && hostName != '*') return hostName;
    return mac;
  }

  /// AccessRecord 格式："yyyy-MM-dd HH:mm:ss#1#1"
  DateTime? get accessTime {
    final part = accessRecord.split('#').first;
    try {
      return DateTime.parse(part.replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }
}

/// 图标判断：方案 B —— 自定义图标 > DevBrands(品牌) > IconType > 默认
class DeviceIcon {
  static IconData resolve(Device d, {String? customIconKey}) {
    if (customIconKey != null) {
      return _byKey(customIconKey);
    }
    final brand = d.devBrand.toLowerCase();
    if (brand.contains('apple')) return Icons.phone_iphone;
    if (brand.isNotEmpty) return Icons.smartphone; // 安卓品牌机统一用手机图标

    switch (d.iconType) {
      case 'mobile':
        return Icons.smartphone;
      case 'Android':
        return Icons.android;
      case 'television':
        return Icons.tv;
      case 'computer':
        return Icons.computer;
      case 'WiFi Loudspeaker Box':
        return Icons.speaker;
      default:
        return Icons.help_outline; // 未知设备，对应预览图里的 📦
    }
  }

  static IconData _byKey(String key) {
    switch (key) {
      case 'phone':
        return Icons.smartphone;
      case 'iphone':
        return Icons.phone_iphone;
      case 'tv':
        return Icons.tv;
      case 'computer':
        return Icons.computer;
      case 'speaker':
        return Icons.speaker;
      case 'router':
        return Icons.router;
      case 'lock':
        return Icons.lock;
      case 'tablet':
        return Icons.tablet_mac;
      default:
        return Icons.devices_other;
    }
  }
}

/// 速率格式化：原始单位 KB/s -> 自动换算 B/s / KB/s / MB/s；0 显示 "--"
String formatRateKBs(double kbs) {
  if (kbs <= 0) return '--';
  if (kbs < 1) return '${(kbs * 1024).round()}B/s';
  if (kbs < 1024) return '${kbs.toStringAsFixed(kbs < 10 ? 1 : 0)}KB/s';
  return '${(kbs / 1024).toStringAsFixed(1)}MB/s';
}

/// 累计流量格式化：原始单位 KB -> GB（保留1位小数）+ "GB" 单位
String formatTrafficKB(double kb) {
  final gb = kb / 1024 / 1024;
  if (gb < 0.01) {
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)}MB';
  }
  return '${gb.toStringAsFixed(1)}GB';
}

/// 离线/在线时长格式化，对齐 python 版 format_duration 逻辑
String formatDuration(Duration d) {
  if (d.isNegative || d.inSeconds <= 0) return '刚刚';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  if (days > 0) return '$days天$hours时$minutes分';
  if (hours > 0) return '$hours时$minutes分';
  return '$minutes分';
}
