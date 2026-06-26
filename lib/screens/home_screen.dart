import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/router_api.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/device_card.dart';
import '../widgets/status_card.dart';
import 'settings_screen.dart';
import 'device_picker_screen.dart';

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
  bool _paused = false;
  int _tab = 0; // 0=在线 1=离线
  int _offlinePage = 0;
  static const _pageSize = 5;

  // 临时切换显示状态，离开本页（去设置）就复原
  bool _lockShowDuration = false;
  final Set<String> _exactTimeMacs = {};

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
      setState(() {
        _error = '首次登录失败：$e';
        _loading = false; // 之前这里漏了，会一直卡在转圈
      });
    }
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_paused) return;
    _timer = Timer.periodic(
        Duration(seconds: widget.config.refreshSeconds), (_) => _refresh());
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _startTimer();
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
        setState(() => _error = null);
      } catch (e2) {
        setState(() {
          _error = '会话过期，重新登录失败：$e2\n'
              '（如果路由器提示"登录用户数已超过限制"，是路由器自身并发会话上限，'
              '等几分钟让旧会话自动过期，或重启一下路由器即可）';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '获取数据失败：$e';
        _loading = false;
      });
    }
  }

  CustomMacEntry? _customEntry(String mac) {
    final e = widget.config.customNames.where((c) => c.mac == mac);
    return e.isEmpty ? null : e.first;
  }

  String _displayName(Device d) => _customEntry(d.mac)?.name ?? d.rawDisplayName;

  void _toggleFavorite(Device d) {
    setState(() {
      if (widget.config.favoriteMacs.contains(d.mac)) {
        widget.config.favoriteMacs.remove(d.mac);
      } else {
        widget.config.favoriteMacs.add(d.mac);
      }
    });
    widget.onConfigChanged(widget.config);
    StorageService.save(widget.config);
  }

  void _openRenameDialog(Device d) {
    final ctrl = TextEditingController(text: _customEntry(d.mac)?.name ?? '');
    String? selectedIcon = _customEntry(d.mac)?.iconKey;
    const iconOptions = {
      null: '默认（按品牌/类型自动）',
      'phone': '安卓手机',
      'iphone': 'iPhone',
      'tablet': '平板',
      'tv': '电视',
      'computer': '电脑',
      'speaker': '音箱',
      'router': '路由器',
      'lock': '门锁',
    };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(ctx2).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${d.mac}（原名：${d.rawDisplayName}）',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Colors.grey)),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(labelText: '自定义名称', hintText: '留空则用原名'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: selectedIcon,
                decoration: const InputDecoration(labelText: '图标（可选，覆盖自动识别）'),
                items: iconOptions.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setSheetState(() => selectedIcon = v),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          widget.config.customNames.removeWhere((c) => c.mac == d.mac);
                        });
                        widget.onConfigChanged(widget.config);
                        StorageService.save(widget.config);
                        Navigator.pop(ctx);
                      },
                      child: const Text('清除映射'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          widget.config.customNames.removeWhere((c) => c.mac == d.mac);
                          if (ctrl.text.trim().isNotEmpty || selectedIcon != null) {
                            widget.config.customNames.add(CustomMacEntry(
                                mac: d.mac, name: ctrl.text.trim(), iconKey: selectedIcon));
                          }
                        });
                        widget.onConfigChanged(widget.config);
                        StorageService.save(widget.config);
                        Navigator.pop(ctx);
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> raw, {String title = '原始设备信息（HostInfo）'}) {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          children: [
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
              defaultVerticalAlignment: TableCellVerticalAlignment.top,
              children: raw.entries
                  .map((e) => TableRow(children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 14, bottom: 10),
                          child: Text(e.key,
                              style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text('${e.value}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace')),
                        ),
                      ]))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _openLockMenu(Device? lockDevice) {
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
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('选择门锁设备'),
              onTap: () async {
                Navigator.pop(ctx);
                final mac = await Navigator.push<String?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DevicePickerScreen(
                      title: '选择门锁设备',
                      devices: _devices,
                      multi: false,
                      selected: {if (widget.config.lockMac != null) widget.config.lockMac!},
                      disabledMacs: {
                        if (widget.config.subRouterMac != null) widget.config.subRouterMac!
                      },
                      disabledHint: '已设为子路由，不可选择',
                    ),
                  ),
                );
                if (mac != null) {
                  setState(() => widget.config.lockMac = mac.isEmpty ? null : mac);
                  widget.onConfigChanged(widget.config);
                  StorageService.save(widget.config);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看原始详情'),
              enabled: lockDevice != null,
              onTap: lockDevice == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _showDetail(lockDevice.raw, title: '门锁原始信息');
                    },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openRouterMenu(Device? routerDevice) {
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
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('自定义命名'),
              enabled: routerDevice != null,
              onTap: routerDevice == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _openRenameDialog(routerDevice);
                    },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看原始详情'),
              enabled: routerDevice != null,
              onTap: routerDevice == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _showDetail(routerDevice.raw, title: '子路由原始信息');
                    },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _goSettings() async {
    // 离开本页前，临时显示态全部复原
    setState(() {
      _lockShowDuration = false;
      _exactTimeMacs.clear();
    });
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
  }

  void _showPersonalDetail(List<Device> onlineDevices) {
    final personal =
        onlineDevices.where((d) => !widget.config.permanentMacs.contains(d.mac)).toList();
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

  String _fmtShort(DateTime t) => formatExactTime(t);

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
    final offlineDevices = listDevices.where((d) => !d.active).toList();
    final personalOnlineCount =
        onlineDevices.where((d) => !widget.config.permanentMacs.contains(d.mac)).length;

    // 离线列表：全部展示，关注设备置顶，组内按最后时间倒序
    DateTime t(Device d) => d.accessTime ?? DateTime(2000);
    offlineDevices.sort((a, b) {
      final af = widget.config.favoriteMacs.contains(a.mac);
      final bf = widget.config.favoriteMacs.contains(b.mac);
      if (af != bf) return af ? -1 : 1;
      return t(b).compareTo(t(a));
    });

    final online5g = onlineDevices.where((d) => d.is5g).toList()
      ..sort((a, b) => t(b).compareTo(t(a)));
    final online24g = onlineDevices.where((d) => d.is24g).toList()
      ..sort((a, b) => t(b).compareTo(t(a)));

    final totalOfflinePages = (offlineDevices.length / _pageSize).ceil().clamp(1, 999);
    final pageStart = _offlinePage * _pageSize;
    final pageItems = offlineDevices.skip(pageStart).take(_pageSize).toList();

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
                                fontSize: 22, fontWeight: FontWeight.bold, color: scheme.onSurface),
                            children: [
                              const TextSpan(text: '家'),
                              TextSpan(text: '络', style: TextStyle(color: scheme.primary)),
                              const TextSpan(text: '看板'),
                            ],
                          ),
                        ),
                        Row(children: [
                          IconButton(
                            tooltip: _paused ? '继续自动刷新' : '暂停自动刷新',
                            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                            onPressed: _togglePause,
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _refresh,
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: _goSettings,
                          ),
                        ]),
                      ],
                    ),
                    Text(
                        '更新于 ${_lastUpdate.hour.toString().padLeft(2, '0')}:'
                        '${_lastUpdate.minute.toString().padLeft(2, '0')}:'
                        '${_lastUpdate.second.toString().padLeft(2, '0')}'
                        '${_paused ? " · 已暂停" : " · 自动刷新中"}',
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
                          subText: lockDevice == null
                              ? '请长按选择门锁'
                              : (_lockShowDuration
                                  ? (lockDevice.accessTime == null
                                      ? '未知时长'
                                      : '${formatDuration(DateTime.now().difference(lockDevice.accessTime!))}'
                                          '${lockDevice.active ? "前上线" : "前离线"}')
                                  : (lockDevice.accessTime == null
                                      ? '暂无记录'
                                      : '最后动作 ${_fmtShort(lockDevice.accessTime!)}')),
                          onTap: lockDevice == null
                              ? null
                              : () => setState(() => _lockShowDuration = !_lockShowDuration),
                          onLongPress: () => _openLockMenu(lockDevice),
                        ),
                        const SizedBox(width: 10),
                        StatusCard(
                          icon: Icons.smartphone,
                          iconColor: scheme.primary,
                          label: '个人设备',
                          mainText: '$personalOnlineCount 台在线',
                          subText: '已排除常驻设备',
                          // 按要求：个人设备卡片不可点击
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
                        upTraffic: subRouter == null ? '--' : formatTrafficKB(subRouter.txKB),
                        downTraffic: subRouter == null ? '--' : formatTrafficKB(subRouter.rxKB),
                        rssi: subRouter?.rssi ?? 0,
                        rssiColor: StatusColors.rssi(context, subRouter?.rssi ?? 0),
                        negotiatedRate: subRouter?.rate ?? 0,
                        durationText: subRouter?.accessTime == null
                            ? '--'
                            : formatDuration(DateTime.now().difference(subRouter!.accessTime!)),
                        onLongPress: () => _openRouterMenu(subRouter),
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
                          text: '离线 · ${offlineDevices.length}',
                          active: _tab == 1,
                          onTap: () => setState(() => _tab = 1)),
                    ]),
                    const SizedBox(height: 8),
                    if (_tab == 0) ...[
                      if (online5g.isNotEmpty) _sectionTitle(context, '5G'),
                      ...online5g.map((d) => _buildOnlineCard(d)),
                      if (online24g.isNotEmpty) _sectionTitle(context, '2.4G'),
                      ...online24g.map((d) => _buildOnlineCard(d)),
                      if (onlineDevices.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(child: Text('暂无在线设备', style: TextStyle(color: Colors.grey))),
                        ),
                    ] else ...[
                      if (pageItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(30),
                          child: Center(child: Text('暂无离线设备', style: TextStyle(color: Colors.grey))),
                        ),
                      ...pageItems.map((d) => _buildOfflineCard(d)),
                      if (offlineDevices.length > _pageSize)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed:
                                    _offlinePage > 0 ? () => setState(() => _offlinePage--) : null,
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

  Widget _buildOnlineCard(Device d) {
    final entry = _customEntry(d.mac);
    return DeviceCard(
      device: d,
      customName: entry?.name,
      customIconKey: entry?.iconKey,
      isFavorite: widget.config.favoriteMacs.contains(d.mac),
      isPermanent: widget.config.permanentMacs.contains(d.mac),
      online: true,
      onlineDurationText: d.accessTime == null
          ? '在线中'
          : '在线${formatDuration(DateTime.now().difference(d.accessTime!))}',
      onFavoriteToggle: () => _toggleFavorite(d),
      onShowDetail: () => _showDetail(d.raw),
      onRename: () => _openRenameDialog(d),
    );
  }

  Widget _buildOfflineCard(Device d) {
    final entry = _customEntry(d.mac);
    final showExact = _exactTimeMacs.contains(d.mac);
    final text = d.accessTime == null
        ? '未知'
        : (showExact
            ? formatExactTime(d.accessTime!)
            : '${formatDuration(DateTime.now().difference(d.accessTime!))}前离线');
    return DeviceCard(
      device: d,
      customName: entry?.name,
      customIconKey: entry?.iconKey,
      isFavorite: widget.config.favoriteMacs.contains(d.mac),
      isPermanent: widget.config.permanentMacs.contains(d.mac),
      online: false,
      offlineText: text,
      onToggleOfflineTime: () {
        setState(() {
          if (showExact) {
            _exactTimeMacs.remove(d.mac);
          } else {
            _exactTimeMacs.add(d.mac);
          }
        });
      },
      onFavoriteToggle: () => _toggleFavorite(d),
      onShowDetail: () => _showDetail(d.raw),
      onRename: () => _openRenameDialog(d),
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
