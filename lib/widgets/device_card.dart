import 'package:flutter/material.dart';
import '../models/device.dart';
import '../theme.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final String? customName; // 用户自定义名，为空表示没设置
  final bool isFavorite;
  final bool isPermanent;
  final String? customIconKey;
  final bool online; // true=在线列表样式，false=离线列表样式
  final String? offlineText; // 离线时显示的文字（相对时长 或 精确时间点，由外部控制）
  final String? onlineDurationText; // 在线时长
  final VoidCallback onFavoriteToggle;
  final VoidCallback onShowDetail;
  final VoidCallback onRename;
  final VoidCallback? onToggleOfflineTime;

  const DeviceCard({
    super.key,
    required this.device,
    required this.isFavorite,
    required this.isPermanent,
    required this.online,
    required this.onFavoriteToggle,
    required this.onShowDetail,
    required this.onRename,
    this.customName,
    this.customIconKey,
    this.offlineText,
    this.onlineDurationText,
    this.onToggleOfflineTime,
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
              leading: const Icon(Icons.edit_outlined),
              title: const Text('自定义命名'),
              onTap: () {
                Navigator.pop(ctx);
                onRename();
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

    final hasCustom = customName != null && customName!.trim().isNotEmpty;
    final shownName = truncateName(hasCustom ? customName! : device.rawDisplayName, maxLen: 12);
    final originalName = truncateName(device.rawDisplayName, maxLen: 10);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () => _openMenu(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: scheme.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isPermanent) const Text('📌 ', style: TextStyle(fontSize: 13)),
                        if (isFavorite) const Text('⭐ ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: shownName,
                                  style: const TextStyle(
                                      fontSize: 15.5, fontWeight: FontWeight.w700)),
                              if (hasCustom)
                                TextSpan(
                                    text: ' ($originalName)',
                                    style: TextStyle(
                                        fontSize: 12, color: scheme.onSurfaceVariant)),
                            ]),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(device.mac,
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    if (online)
                      Text(
                        '${onlineDurationText ?? ''}　🔗${device.rate}Mbps',
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                      )
                    else
                      GestureDetector(
                        onTap: onToggleOfflineTime,
                        child: Text(offlineText ?? '',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurfaceVariant)),
                      ),
                    if (online)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '↓${formatRateKBs(device.downRateKBs)} ↑${formatRateKBs(device.upRateKBs)}',
                          style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (online)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (device.isWifi6)
                      Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('WiFi 6',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: scheme.onTertiaryContainer)),
                      ),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration:
                              BoxDecoration(color: rssiColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text('${device.rssi}',
                            style: TextStyle(
                                fontSize: 13,
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
}
