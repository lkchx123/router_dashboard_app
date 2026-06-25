import 'package:flutter/material.dart';
import '../models/device.dart';
import '../theme.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final String displayName;
  final bool isFavorite;
  final String? customIconKey;
  final bool online; // true=在线列表样式，false=离线列表样式
  final String? offlineDurationText; // 仅离线时使用
  final VoidCallback onFavoriteToggle;
  final VoidCallback onShowDetail;
  final VoidCallback? onTapOfflineTime;

  const DeviceCard({
    super.key,
    required this.device,
    required this.displayName,
    required this.isFavorite,
    required this.online,
    required this.onFavoriteToggle,
    required this.onShowDetail,
    this.customIconKey,
    this.offlineDurationText,
    this.onTapOfflineTime,
  });

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4)),
            ),
            ListTile(
              leading: Icon(isFavorite ? Icons.star : Icons.star_border,
                  color: Colors.amber),
              title: Text(isFavorite ? '取消关注' : '关注此设备'),
              onTap: () {
                Navigator.pop(ctx);
                onFavoriteToggle();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看原始详情'),
              onTap: () {
                Navigator.pop(ctx);
                onShowDetail();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = DeviceIcon.resolve(device, customIconKey: customIconKey);
    final rssiColor = StatusColors.rssi(context, device.rssi);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () => _openMenu(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isFavorite) ...[
                          const Text('⭐ ', style: TextStyle(fontSize: 12)),
                        ],
                        Expanded(
                          child: Text(displayName,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    Text(device.mac,
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 3),
                    if (online) ..._onlineMeta(scheme)
                    else
                      GestureDetector(
                        onTap: onTapOfflineTime,
                        child: Text(offlineDurationText ?? '',
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (online)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (device.isWifi6)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('WiFi 6',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary)),
                      ),
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration:
                              BoxDecoration(color: rssiColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text('${device.rssi}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _onlineMeta(ColorScheme scheme) {
    final metaStyle = TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant, fontFamily: 'monospace');
    return [
      Text('🔗${device.rate}Mbps  '
          '↓${formatRateKBs(device.downRateKBs)} '
          '↑${formatRateKBs(device.upRateKBs)}',
          style: metaStyle),
    ];
  }
}
