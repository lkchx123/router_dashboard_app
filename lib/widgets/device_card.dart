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
  final VoidCallback onPermanentToggle;
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
    required this.onPermanentToggle,
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
                  color: const Color(0xFFFFC107)),
              title: Text(isFavorite ? '取消关注' : '关注此设备'),
              onTap: () {
                Navigator.pop(ctx);
                onFavoriteToggle();
              },
            ),
            ListTile(
              leading: Icon(isPermanent ? Icons.push_pin : Icons.push_pin_outlined,
                  color: isPermanent ? Theme.of(ctx).colorScheme.primary : null),
              title: Text(isPermanent ? '取消常驻设备' : '标为常驻设备'),
              onTap: () {
                Navigator.pop(ctx);
                onPermanentToggle();
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
    final fullShownName = hasCustom ? customName! : device.rawDisplayName;
    final fullOriginalName = device.rawDisplayName;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // 离线卡片整卡可点，切换"相对时长 / 精确时间点"显示
        onTap: online ? null : onToggleOfflineTime,
        onLongPress: () => _openMenu(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ConstrainedBox(
            // 固定最小高度，避免不同设备因标签数量不同导致卡片高度参差、翻页按钮跳动
            constraints: const BoxConstraints(minHeight: 78),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 名字区域大致占可用宽度的一半，按比例截断，而不是写死字符数
                final nameAreaWidth = (constraints.maxWidth - 46 - 13 - 6 - 60) * 0.62;
                final shownName = truncateName(fullShownName,
                    maxLen: (nameAreaWidth / 9).floor().clamp(4, 40));
                final originalName = truncateName(fullOriginalName,
                    maxLen: (nameAreaWidth / 18).floor().clamp(3, 20));

                return Row(
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (isPermanent)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(Icons.push_pin, size: 13, color: Color(0xFF6E8B7A)),
                                ),
                              if (isFavorite)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(Icons.star, size: 14, color: Color(0xFFFFC107)),
                                ),
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
                              onlineDurationText ?? '',
                              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                            )
                          else
                            Text(offlineText ?? '',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSurfaceVariant)),
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
                                decoration: BoxDecoration(
                                    color: rssiColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text('${device.rssi}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      color: scheme.onSurfaceVariant)),
                              const SizedBox(width: 6),
                              Text('🔗${device.rate}Mbps',
                                  style: TextStyle(
                                      fontSize: 10, color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
