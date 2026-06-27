import 'dart:ui';
import 'package:flutter/material.dart';
import 'sparkline.dart';

/// MD3 风格半透明玻璃卡片底座，三张首屏状态卡统一用这个背景
class GlassCard extends StatelessWidget {
  final Widget child;
  final Color tint;
  final EdgeInsets padding;

  const GlassCard({
    super.key,
    required this.child,
    required this.tint,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withOpacity(0.16),
                scheme.surface.withOpacity(0.55),
              ],
            ),
            border: Border.all(color: scheme.outlineVariant.withOpacity(0.5), width: 1),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 简单状态卡（门锁 / 个人设备），固定宽度图标对齐
class StatusCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String mainText;
  final Color? mainTextColor;
  final String subText;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const StatusCard({
    super.key,
    required this.icon,
    required this.label,
    required this.mainText,
    required this.subText,
    this.iconColor,
    this.mainTextColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = iconColor ?? scheme.primary;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          onLongPress: onLongPress,
          child: GlassCard(
            tint: tint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Icon(icon, size: 16, color: tint),
                    ),
                    const SizedBox(width: 4),
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.3,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(mainText,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: mainTextColor ?? scheme.onSurface)),
                const SizedBox(height: 4),
                Text(subText,
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 子路由状态卡：信息更全，IP/实时速率/累计流量/RSSI/连接时长/协商速率
class RouterStatusCard extends StatelessWidget {
  final String name;
  final String band; // "5GHz" / "2.4GHz"
  final bool online;
  final String ip;
  final String upRate;
  final String downRate;
  final String upTraffic;
  final String downTraffic;
  final int rssi;
  final Color rssiColor;
  final String durationText;
  final int negotiatedRate; // 协商速率 Mbps
  final List<double> rateHistory; // 用于迷你折线图的下载速率历史
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const RouterStatusCard({
    super.key,
    required this.name,
    required this.band,
    required this.online,
    required this.ip,
    required this.upRate,
    required this.downRate,
    required this.upTraffic,
    required this.downTraffic,
    required this.rssi,
    required this.rssiColor,
    required this.durationText,
    required this.negotiatedRate,
    this.rateHistory = const [],
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(String label, Widget value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              value,
            ],
          ),
        );
    final valueStyle = TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        fontFamily: 'monospace',
        color: scheme.onSurface);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: GlassCard(
          tint: scheme.tertiary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.router, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Expanded(
                  child: Text('$name · $band',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 8),
              Text(online ? '在线 · $ip' : '离线',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text('实时速率',
                            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                        const SizedBox(width: 6),
                        if (online && rateHistory.length >= 2)
                          Sparkline(values: rateHistory, color: scheme.tertiary),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('↓$downRate ↑$upRate', style: valueStyle),
              const SizedBox(height: 10),
              Row(children: [
                item('累计流量', Text('↓$downTraffic ↑$upTraffic', style: valueStyle)),
                item(
                  '信号 / 协商速率',
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(color: rssiColor, shape: BoxShape.circle),
                    ),
                    Text('$rssi', style: valueStyle),
                    const SizedBox(width: 6),
                    Text('${negotiatedRate}Mbps',
                        style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              item('连接时长', Text(durationText, style: valueStyle)),
            ],
          ),
        ),
      ),
    );
  }
}
