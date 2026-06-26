import 'package:flutter/material.dart';
import '../models/device.dart';

class DevicePickerScreen extends StatefulWidget {
  final String title;
  final List<Device> devices;
  final bool multi;
  final Set<String> selected;
  final Set<String> disabledMacs; // 已被用作门锁/子路由等，不可选，但仍展示
  final String disabledHint;
  final bool allowManualAdd; // 是否允许手动输入MAC添加（用于关注设备等场景）

  const DevicePickerScreen({
    super.key,
    required this.title,
    required this.devices,
    required this.multi,
    required this.selected,
    this.disabledMacs = const {},
    this.disabledHint = '已用于其他分类，不可选择',
    this.allowManualAdd = false,
  });

  @override
  State<DevicePickerScreen> createState() => _DevicePickerScreenState();
}

class _DevicePickerScreenState extends State<DevicePickerScreen> {
  late Set<String> _selected;
  String _query = '';
  // 已选中但当前抓不到的MAC（比如关注设备很久没出现，或手动添加的）
  final Set<String> _manualMacs = {};

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selected};
    final knownMacs = widget.devices.map((d) => d.mac).toSet();
    _manualMacs.addAll(widget.selected.where((m) => !knownMacs.contains(m)));
  }

  List<Device> get _filteredKnown {
    final list = [...widget.devices];
    if (_query.trim().isEmpty) return list;
    final q = _query.trim().toLowerCase();
    return list
        .where((d) =>
            d.rawDisplayName.toLowerCase().contains(q) ||
            d.mac.toLowerCase().contains(q))
        .toList();
  }

  void _addManualMac() {
    final macCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动添加设备'),
        content: TextField(
          controller: macCtrl,
          decoration: const InputDecoration(hintText: '输入 MAC 地址，例如 AA:BB:CC:DD:EE:FF'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final mac = macCtrl.text.trim().toUpperCase();
              Navigator.pop(ctx);
              if (mac.isEmpty) return;
              setState(() {
                if (!widget.multi) _selected.clear();
                _selected.add(mac);
                if (!widget.devices.any((d) => d.mac == mac)) {
                  _manualMacs.add(mac);
                }
              });
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final knownMacs = widget.devices.map((d) => d.mac).toSet();

    // 已选中但当前抓不到信息的设备（关注设备消失场景），永远置顶展示
    final missingSelected = _selected.where((m) => !knownMacs.contains(m)).toList();

    final known = _filteredKnown;
    final online = known.where((d) => d.active).toList()
      ..sort((a, b) => (b.accessTime ?? DateTime(2000)).compareTo(a.accessTime ?? DateTime(2000)));
    final offline = known.where((d) => !d.active).toList()
      ..sort((a, b) => (b.accessTime ?? DateTime(2000)).compareTo(a.accessTime ?? DateTime(2000)));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.allowManualAdd)
            IconButton(onPressed: _addManualMac, icon: const Icon(Icons.add)),
          TextButton(
            onPressed: () {
              if (widget.multi) {
                Navigator.pop(context, _selected);
              } else {
                Navigator.pop(context, _selected.isEmpty ? '' : _selected.first);
              }
            },
            child: const Text('完成'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: '搜索设备名或MAC',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (missingSelected.isNotEmpty) ...[
                  _header('已设置但当前未抓到（不会丢失）', scheme),
                  ...missingSelected.map((mac) => CheckboxListTile(
                        value: true,
                        title: Text(mac, style: const TextStyle(fontFamily: 'monospace')),
                        subtitle: const Text('当前不在设备列表中', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                        onChanged: (v) {
                          if (v == false) setState(() => _selected.remove(mac));
                        },
                      )),
                  Divider(height: 1, color: scheme.outlineVariant),
                ],
                if (online.isNotEmpty) _header('在线设备', scheme),
                ...online.map(_buildTile),
                if (offline.isNotEmpty) ...[
                  Divider(height: 1, color: scheme.outlineVariant),
                  _header('离线设备', scheme),
                ],
                ...offline.map(_buildTile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String text, ColorScheme scheme) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
      );

  Widget _buildTile(Device d) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = widget.disabledMacs.contains(d.mac);
    final checked = _selected.contains(d.mac);
    final timeText = d.accessTime == null ? '未知时间' : formatExactTime(d.accessTime!);
    return CheckboxListTile(
      value: checked,
      enabled: !disabled,
      title: Text(d.rawDisplayName,
          style: TextStyle(color: disabled ? scheme.outline : null)),
      subtitle: Text(
        disabled
            ? '${d.mac} · ${widget.disabledHint}'
            : '${d.mac} · ${d.active ? "在线" : "离线"} · $timeText',
        style: TextStyle(
            fontSize: 11.5,
            color: disabled ? scheme.outline : scheme.onSurfaceVariant),
      ),
      onChanged: disabled
          ? null
          : (v) {
              setState(() {
                if (!widget.multi) _selected.clear();
                if (v == true) {
                  _selected.add(d.mac);
                } else {
                  _selected.remove(d.mac);
                }
              });
            },
    );
  }
}
