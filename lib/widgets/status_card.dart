import 'package:flutter/material.dart';

/// 简单状态卡（门锁 / 个人设备），固定宽度图标对齐
class StatusCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String mainText;
  final Color? mainTextColor;
  final String subText;
  final VoidCallback? onTap;

  const StatusCard({
    super.key,
    required this.icon,
    required this.label,
    required this.mainText,
    required this.subText,
    this.iconColor,
    this.mainTextColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: Icon(icon, size: 14, color: iconColor ?? scheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    Text(label,
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(mainText,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: mainTextColor)),
                const SizedBox(height: 4),
                Text(subText,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 子路由状态卡：信息更全，IP/实时速率/累计流量/RSSI/连接时长
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
  final VoidCallback? onTap;

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
    this.onTap,
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

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(children: [
                item('实时速率', Text('↓$downRate ↑$upRate', style: valueStyle)),
                item('累计流量', Text('↓$downTraffic ↑$upTraffic', style: valueStyle)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                item(
                  '信号 RSSI',
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(color: rssiColor, shape: BoxShape.circle),
                    ),
                    Text('$rssi', style: valueStyle),
                  ]),
                ),
                item('连接时长', Text(durationText, style: valueStyle)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
