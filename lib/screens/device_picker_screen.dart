import 'package:flutter/material.dart';
import '../models/device.dart';

class DevicePickerScreen extends StatefulWidget {
  final String title;
  final List<Device> devices;
  final bool multi;
  final Set<String> selected;
  final Set<String> disabledMacs; // 已被用作门锁/子路由等，不可选，但仍展示
  final String disabledHint;

  const DevicePickerScreen({
    super.key,
    required this.title,
    required this.devices,
    required this.multi,
    required this.selected,
    this.disabledMacs = const {},
    this.disabledHint = '已用于其他分类，不可选择',
  });

  @override
  State<DevicePickerScreen> createState() => _DevicePickerScreenState();
}

class _DevicePickerScreenState extends State<DevicePickerScreen> {
  late Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selected};
  }

  List<Device> get _sorted {
    final list = [...widget.devices];
    // 按最近活动时间倒序：在线设备 AccessRecord 也代表最近上线时间，
    // 离线设备代表最后离线时间，统一按这个时间倒序，最新的排前面。
    list.sort((a, b) {
      final ta = a.accessTime ?? DateTime(2000);
      final tb = b.accessTime ?? DateTime(2000);
      return tb.compareTo(ta);
    });
    if (_query.trim().isEmpty) return list;
    final q = _query.trim().toLowerCase();
    return list
        .where((d) =>
            d.rawDisplayName.toLowerCase().contains(q) ||
            d.mac.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
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
            child: ListView.builder(
              itemCount: _sorted.length,
              itemBuilder: (ctx, i) {
                final d = _sorted[i];
                final disabled = widget.disabledMacs.contains(d.mac);
                final checked = _selected.contains(d.mac);
                return CheckboxListTile(
                  value: checked,
                  enabled: !disabled,
                  title: Text(d.rawDisplayName,
                      style: TextStyle(color: disabled ? scheme.outline : null)),
                  subtitle: Text(
                    disabled
                        ? '${d.mac} · ${widget.disabledHint}'
                        : '${d.mac} · ${d.active ? "在线" : "离线"}',
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
