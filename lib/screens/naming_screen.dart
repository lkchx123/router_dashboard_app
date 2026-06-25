import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/storage_service.dart';

class NamingScreen extends StatefulWidget {
  final AppConfig config;
  final List<Device> devices;
  final void Function(AppConfig) onSaved;

  const NamingScreen({
    super.key,
    required this.config,
    required this.devices,
    required this.onSaved,
  });

  @override
  State<NamingScreen> createState() => _NamingScreenState();
}

const _iconOptions = {
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

class _NamingScreenState extends State<NamingScreen> {
  String _customName(String mac) {
    final e = widget.config.customNames.where((c) => c.mac == mac);
    return e.isEmpty ? '' : e.first.name;
  }

  void _edit(String mac, String suggested) {
    final ctrl = TextEditingController(text: _customName(mac).isEmpty ? '' : _customName(mac));
    String? selectedIcon = widget.config.customNames
        .where((c) => c.mac == mac)
        .map((c) => c.iconKey)
        .firstOrNull;

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
              Text(mac, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(labelText: '自定义名称', hintText: suggested),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: selectedIcon,
                decoration: const InputDecoration(labelText: '图标（可选，覆盖自动识别）'),
                items: _iconOptions.entries
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
                          widget.config.customNames.removeWhere((c) => c.mac == mac);
                        });
                        widget.onSaved(widget.config);
                        Navigator.pop(ctx);
                      },
                      child: const Text('删除映射'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          widget.config.customNames.removeWhere((c) => c.mac == mac);
                          if (ctrl.text.trim().isNotEmpty) {
                            widget.config.customNames.add(CustomMacEntry(
                                mac: mac, name: ctrl.text.trim(), iconKey: selectedIcon));
                          }
                        });
                        widget.onSaved(widget.config);
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

  void _addByManualMac() {
    final macCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动添加MAC映射'),
        content: TextField(
          controller: macCtrl,
          decoration: const InputDecoration(hintText: '例如 AA:BB:CC:DD:EE:FF'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final mac = macCtrl.text.trim().toUpperCase();
              Navigator.pop(ctx);
              if (mac.isNotEmpty) _edit(mac, mac);
            },
            child: const Text('下一步'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = widget.devices
        .where((d) => widget.config.favoriteMacs.contains(d.mac))
        .toList();
    final others = widget.devices
        .where((d) => !widget.config.favoriteMacs.contains(d.mac))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义命名'),
        actions: [
          IconButton(onPressed: _addByManualMac, icon: const Icon(Icons.add)),
        ],
      ),
      body: ListView(
        children: [
          if (favorites.isNotEmpty) _header('⭐ 关注设备'),
          ...favorites.map(_row),
          _header('其他设备'),
          ...others.map(_row),
        ],
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
      );

  Widget _row(Device d) {
    final custom = _customName(d.mac);
    return ListTile(
      title: Text(custom.isEmpty ? d.rawDisplayName : custom),
      subtitle: Text('${d.mac} · ${d.active ? "在线" : "离线"}'),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => _edit(d.mac, d.rawDisplayName),
    );
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
