import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/router_api.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/device_card.dart';
import '../widgets/status_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppConfig config;
  final void Function(AppConfig) onConfigChanged;
  final void Function(String) onThemeModeChanged;

  const HomeScreen({
    super.key,
    required this.config,
    required this.onConfigChanged,
    required this.onThemeModeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late RouterApi _api;
  Timer? _timer;
  List<Device> _devices = [];
  DateTime _lastUpdate = DateTime.now();
  String? _error;
  bool _loading = true;
  int _tab = 0; // 0=在线 1=离线
  int _offlinePage = 0;
  static const _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _api = RouterApi(
      baseUrl: widget.config.routerUrl,
      username: widget.config.username,
      password: widget.config.password,
    );
    _bootstrap();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await _api.login();
      await _refresh();
    } catch (e) {
      setState(() => _error = '首次登录失败：$e');
    }
    _timer = Timer.periodic(
        Duration(seconds: widget.config.refreshSeconds), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final raw = await _api.getHostInfo();
      final devices = raw
          .whereType<Map>()
          .map((e) => Device.fromJson(e.cast<String, dynamic>()))
          .toList();
      setState(() {
        _devices = devices;
        _lastUpdate = DateTime.now();
        _error = null;
        _loading = false;
      });
    } on AuthExpiredError catch (e) {
      try {
        await _api.login();
      } catch (e2) {
        setState(() => _error = '会话过期，重新登录失败：$e2');
      }
    } catch (e) {
      setState(() => _error = '获取数据失败：$e');
    }
  }

  String _displayName(Device d) {
    final entry = widget.config.customNames
        .where((c) => c.mac == d.mac)
        .toList();
    if (entry.isNotEmpty) return entry.first.name;
    return d.rawDisplayName;
  }

  String? _customIcon(Device d) {
    final entry = widget.config.customNames.where((c) => c.mac == d.mac);
    if (entry.isEmpty) return null;
    return entry.first.iconKey;
  }

  void _toggleFavorite(Device d) {
    setState(() {
      if (widget.config.favoriteMacs.contains(d.mac)) {
        widget.config.favoriteMacs.remove(d.mac);
      } else {
        widget.config.favoriteMacs.add(d.mac);
      }
    });
    widget.onConfigChanged(widget.config);
  }

  void _showDetail(Device d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx2, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            const Text('原始设备信息（HostInfo）',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            ...d.raw.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 130,
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontSize: 12.5, color: Colors.grey))),
                      Expanded(
                          child: Text('${e.value}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12.5, fontFamily: 'monospace'))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _openLockDetail(Device? lock) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('门锁状态'),
        content: Text(lock == null
            ? '尚未识别到门锁设备，请在设置中选择。'
            : '当前：${lock.active ? '在线' : '离线'}\n'
                '最后动作：${lock.accessTime ?? '未知'}\n'
                '门锁触网规律因人而异，请结合自身情况判断在/离家。'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final lockDevice = widget.config.lockMac == null
        ? null
        : _devices.where((d) => d.mac == widget.config.lockMac).firstOrNull;
    final subRouter = widget.config.subRouterMac == null
        ? null
        : _devices.where((d) => d.mac == widget.config.subRouterMac).firstOrNull;

    final excludedMacs = {
      if (widget.config.lockMac != null) widget.config.lockMac!,
      if (widget.config.subRouterMac != null) widget.config.subRouterMac!,
    };

    final listDevices = _devices.where((d) => !excludedMacs.contains(d.mac)).toList();
    final onlineDevices = listDevices.where((d) => d.active).toList();
    final personalOnlineCount = onlineDevices
        .where((d) => !widget.config.permanentMacs.contains(d.mac))
        .length;

    final favoriteOfflineDevices = listDevices
        .where((d) => !d.active && widget.config.favoriteMacs.contains(d.mac))
        .toList()
      ..sort((a, b) {
        final ta = a.accessTime ?? DateTime(2000);
        final tb = b.accessTime ?? DateTime(2000);
        return tb.compareTo(ta); // 最后时间倒序
      });

    final online5g = onlineDevices.where((d) => d.is5g).toList()
      ..sort((a, b) =>
          (b.accessTime ?? DateTime(2000)).compareTo(a.accessTime ?? DateTime(2000)));
    final online24g = onlineDevices.where((d) => d.is24g).toList()
      ..sort((a, b) =>
          (b.accessTime ?? DateTime(2000)).compareTo(a.accessTime ?? DateTime(2000)));

    final totalOfflinePages =
        (favoriteOfflineDevices.length / _pageSize).ceil().clamp(1, 999);
    final pageStart = _offlinePage * _pageSize;
    final pageItems = favoriteOfflineDevices
        .skip(pageStart)
        .take(_pageSize)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface),
                            children: [
                              const TextSpan(text: '家'),
                              TextSpan(text: '络', style: TextStyle(color: scheme.primary)),
                              const TextSpan(text: '看板'),
                            ],
                          ),
                        ),
                        Row(children: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _refresh,
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SettingsScreen(
                                    config: widget.config,
                                    devices: _devices,
                                    onSaved: widget.onConfigChanged,
                                    onThemeModeChanged: widget.onThemeModeChanged,
                                  ),
                                ),
                              );
                              setState(() {});
                            },
                          ),
                        ]),
                      ],
                    ),
                    Text(
                        '更新于 ${_lastUpdate.hour.toString().padLeft(2, '0')}:'
                        '${_lastUpdate.minute.toString().padLeft(2, '0')}:'
                        '${_lastUpdate.second.toString().padLeft(2, '0')} · 自动刷新中',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 12)),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusCard(
                          icon: Icons.lock_outline,
                          label: '门锁状态',
                          mainText: widget.config.lockMac == null
                              ? '未设置'
                              : (lockDevice?.active == true ? '在线' : '离线'),
                          mainTextColor: lockDevice?.active == true
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          subText: lockDevice?.accessTime == null
                              ? '暂无记录'
                              : '最后动作 ${_fmtShort(lockDevice!.accessTime!)}',
                          onTap: () => _openLockDetail(lockDevice),
                        ),
                        const SizedBox(width: 10),
                        StatusCard(
                          icon: Icons.smartphone,
                          iconColor: scheme.primary,
                          label: '个人设备',
                          mainText: '$personalOnlineCount 台在线',
                          subText: '已排除常驻设备',
                          onTap: () => _showPersonalDetail(onlineDevices),
                        ),
                      ],
                    ),
                    if (widget.config.subRouterMac != null) ...[
                      const SizedBox(height: 10),
                      RouterStatusCard(
                        name: _displayName(subRouter ?? Device.fromJson({})),
                        band: subRouter?.is5g == true ? '5GHz' : '2.4GHz',
                        online: subRouter?.active == true,
                        ip: subRouter?.ip ?? '--',
                        upRate: formatRateKBs(subRouter?.upRateKBs ?? 0),
                        downRate: formatRateKBs(subRouter?.downRateKBs ?? 0),
                        upTraffic: subRouter == null
                            ? '--'
                            : formatTrafficKB(subRouter.txKB),
                        downTraffic: subRouter == null
                            ? '--'
                            : formatTrafficKB(subRouter.rxKB),
                        rssi: subRouter?.rssi ?? 0,
                        rssiColor: StatusColors.rssi(context, subRouter?.rssi ?? 0),
                        durationText: subRouter?.accessTime == null
                            ? '--'
                            : formatDuration(
                                DateTime.now().difference(subRouter!.accessTime!)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      _TabChip(
                          text: '在线 · ${onlineDevices.length}',
                          active: _tab == 0,
                          onTap: () => setState(() => _tab = 0)),
                      const SizedBox(width: 6),
                      _TabChip(
                          text: '离线 · ${favoriteOfflineDevices.length}',
                          active: _tab == 1,
                          onTap: () => setState(() => _tab = 1)),
                    ]),
                    const SizedBox(height: 8),
                    if (_tab == 0) ...[
                      if (online5g.isNotEmpty) _sectionTitle(context, '5G'),
                      ...online5g.map((d) => DeviceCard(
                            device: d,
                            displayName: _displayName(d),
                            isFavorite: widget.config.favoriteMacs.contains(d.mac),
                            customIconKey: _customIcon(d),
                            online: true,
                            onFavoriteToggle: () => _toggleFavorite(d),
                            onShowDetail: () => _showDetail(d),
                          )),
                      if (online24g.isNotEmpty) _sectionTitle(context, '2.4G'),
                      ...online24g.map((d) => DeviceCard(
                            device: d,
                            displayName: _displayName(d),
                            isFavorite: widget.config.favoriteMacs.contains(d.mac),
                            customIconKey: _customIcon(d),
                            online: true,
                            onFavoriteToggle: () => _toggleFavorite(d),
                            onShowDetail: () => _showDetail(d),
                          )),
                      if (onlineDevices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(child: Text('暂无在线设备', style: TextStyle(color: Colors.grey))),
                        ),
                    ] else ...[
                      if (pageItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(
                              child: Text('暂无关注的离线设备\n（请在设置中选择要关注的设备）',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey))),
                        ),
                      ...pageItems.map((d) => DeviceCard(
                            device: d,
                            displayName: _displayName(d),
                            isFavorite: true,
                            customIconKey: _customIcon(d),
                            online: false,
                            offlineDurationText: d.accessTime == null
                                ? '未知'
                                : '${formatDuration(DateTime.now().difference(d.accessTime!))}前离线',
                            onFavoriteToggle: () => _toggleFavorite(d),
                            onShowDetail: () => _showDetail(d),
                            onTapOfflineTime: () => _showExactOfflineTime(d),
                          )),
                      if (favoriteOfflineDevices.length > _pageSize)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _offlinePage > 0
                                    ? () => setState(() => _offlinePage--)
                                    : null,
                              ),
                              Text('${_offlinePage + 1} / $totalOfflinePages',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _offlinePage < totalOfflinePages - 1
                                    ? () => setState(() => _offlinePage++)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  String _fmtShort(DateTime t) =>
      '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showExactOfflineTime(Device d) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('精确离线时间'),
        content: Text('${d.accessTime}'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))],
      ),
    );
  }

  void _showPersonalDetail(List<Device> onlineDevices) {
    final personal = onlineDevices
        .where((d) => !widget.config.permanentMacs.contains(d.mac))
        .toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('个人设备在线详情'),
        content: Text(personal.isEmpty
            ? '当前无个人设备在线'
            : personal.map((d) => '· ${_displayName(d)} (${d.mac})').join('\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _TabChip extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  const _TabChip({required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? scheme.onPrimary : scheme.onSurfaceVariant)),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
