import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/storage_service.dart';
import 'device_picker_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppConfig config;
  final List<Device> devices;
  final void Function(AppConfig) onSaved;
  final void Function(String) onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.config,
    required this.devices,
    required this.onSaved,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _pwdCtrl;
  late TextEditingController _refreshCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.config.routerUrl);
    _pwdCtrl = TextEditingController(text: widget.config.password);
    _refreshCtrl =
        TextEditingController(text: widget.config.refreshSeconds.toString());
  }

  void _persist() {
    widget.config.routerUrl = _urlCtrl.text.trim();
    widget.config.password = _pwdCtrl.text;
    widget.onSaved(widget.config);
    StorageService.save(widget.config);
  }

  /// 刷新间隔最低5秒，输入框失焦或提交时校正
  void _commitRefreshSeconds() {
    var v = int.tryParse(_refreshCtrl.text) ?? widget.config.refreshSeconds;
    if (v < 5) v = 5;
    _refreshCtrl.text = v.toString();
    widget.config.refreshSeconds = v;
    _persist();
  }

  String _nameOf(String? mac) {
    if (mac == null) return '未设置';
    final d = widget.devices.where((d) => d.mac == mac);
    if (d.isEmpty) return mac;
    return d.first.rawDisplayName;
  }

  Set<String> get _excludedMacs => {
        if (widget.config.lockMac != null) widget.config.lockMac!,
        if (widget.config.subRouterMac != null) widget.config.subRouterMac!,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _group([
            _textRow('路由器地址', _urlCtrl, onChanged: (_) => _persist()),
            _textRow('管理员密码', _pwdCtrl, obscure: true, onChanged: (_) => _persist()),
            _textRow('刷新间隔（秒，最低5秒）', _refreshCtrl,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _commitRefreshSeconds(),
                onChanged: (_) {}),
          ]),
          _group([
            ListTile(
              title: const Text('外观主题'),
              subtitle: _ThemeSelector(
                value: widget.config.themeMode,
                onChanged: (v) {
                  setState(() => widget.config.themeMode = v);
                  widget.onThemeModeChanged(v);
                  _persist();
                },
              ),
            ),
          ]),
          _group([
            _navRow('子路由设备', _nameOf(widget.config.subRouterMac), () async {
              final mac = await Navigator.push<String?>(
                context,
                MaterialPageRoute(
                  builder: (_) => DevicePickerScreen(
                    title: '选择子路由设备',
                    devices: widget.devices,
                    multi: false,
                    selected: {
                      if (widget.config.subRouterMac != null)
                        widget.config.subRouterMac!
                    },
                    disabledMacs: {
                      if (widget.config.lockMac != null) widget.config.lockMac!
                    },
                    disabledHint: '已设为门锁，不可选择',
                  ),
                ),
              );
              if (mac != null) {
                setState(() {
                  widget.config.subRouterMac = mac.isEmpty ? null : mac;
                  widget.config.favoriteMacs.remove(mac);
                  widget.config.permanentMacs.remove(mac);
                });
                _persist();
              }
            }),
            _navRow('门锁设备', _nameOf(widget.config.lockMac), () async {
              final mac = await Navigator.push<String?>(
                context,
                MaterialPageRoute(
                  builder: (_) => DevicePickerScreen(
                    title: '选择门锁设备',
                    devices: widget.devices,
                    multi: false,
                    selected: {
                      if (widget.config.lockMac != null) widget.config.lockMac!
                    },
                    disabledMacs: {
                      if (widget.config.subRouterMac != null)
                        widget.config.subRouterMac!
                    },
                    disabledHint: '已设为子路由，不可选择',
                  ),
                ),
              );
              if (mac != null) {
                setState(() {
                  widget.config.lockMac = mac.isEmpty ? null : mac;
                  widget.config.favoriteMacs.remove(mac);
                  widget.config.permanentMacs.remove(mac);
                });
                _persist();
              }
            }),
            _navRow('常驻设备', '${widget.config.permanentMacs.length} 台', () async {
              final macs = await Navigator.push<Set<String>>(
                context,
                MaterialPageRoute(
                  builder: (_) => DevicePickerScreen(
                    title: '选择常驻设备',
                    devices: widget.devices,
                    multi: true,
                    selected: widget.config.permanentMacs,
                    disabledMacs: _excludedMacs,
                    disabledHint: '已设为门锁/子路由，不可选择',
                  ),
                ),
              );
              if (macs != null) {
                setState(() => widget.config.permanentMacs = macs);
                _persist();
              }
            }),
            _navRow('关注设备', '${widget.config.favoriteMacs.length} 台', () async {
              final macs = await Navigator.push<Set<String>>(
                context,
                MaterialPageRoute(
                  builder: (_) => DevicePickerScreen(
                    title: '选择关注设备',
                    devices: widget.devices,
                    multi: true,
                    selected: widget.config.favoriteMacs,
                    disabledMacs: _excludedMacs,
                    disabledHint: '已设为门锁/子路由，不可选择',
                  ),
                ),
              );
              if (macs != null) {
                setState(() => widget.config.favoriteMacs = macs);
                _persist();
              }
            }),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '提示：设备的自定义改名不在这里设置了，长按首页或子路由卡片上的具体设备，'
              '选"自定义命名"就能改。',
              style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(children: children),
      );

  Widget _textRow(String label, TextEditingController ctrl,
          {bool obscure = false,
          TextInputType? keyboardType,
          ValueChanged<String>? onChanged,
          ValueChanged<String>? onSubmitted}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onEditingComplete: () => onSubmitted?.call(ctrl.text),
          decoration: InputDecoration(labelText: label, border: InputBorder.none),
        ),
      );

  Widget _navRow(String label, String value, VoidCallback onTap) => ListTile(
        title: Text(label),
        trailing: Text(value, style: const TextStyle(color: Colors.grey)),
        onTap: onTap,
      );
}

class _ThemeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ThemeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget opt(String key, String label) {
      final active = value == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(key),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: active ? scheme.primary : scheme.outlineVariant, width: 1.5),
              color: active ? scheme.primaryContainer : null,
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? scheme.primary : scheme.onSurfaceVariant)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        opt('system', '跟随系统'),
        opt('light', '浅色'),
        opt('dark', '深色'),
      ]),
    );
  }
}
