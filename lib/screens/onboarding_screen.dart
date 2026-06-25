import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/router_api.dart';
import '../services/storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  final AppConfig config;
  final void Function(AppConfig) onFinished;

  const OnboardingScreen({super.key, required this.config, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  final _urlCtrl = TextEditingController(text: 'http://192.168.3.1');
  final _userCtrl = TextEditingController(text: 'admin');
  final _pwdCtrl = TextEditingController();

  bool _testing = false;
  String? _testError;
  List<Device> _devices = [];

  String? _subRouterMac;
  String? _lockMac;
  final Set<String> _permanentMacs = {};
  final Set<String> _favoriteMacs = {};

  Future<void> _testAndFetch() async {
    setState(() {
      _testing = true;
      _testError = null;
    });
    try {
      final api = RouterApi(
        baseUrl: _urlCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        password: _pwdCtrl.text,
      );
      await api.login();
      final raw = await api.getHostInfo();
      _devices = raw
          .whereType<Map>()
          .map((e) => Device.fromJson(e.cast<String, dynamic>()))
          .toList();
      api.dispose();
      setState(() => _testing = false);
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
    } catch (e) {
      setState(() {
        _testing = false;
        _testError = '连接失败：$e\n请检查地址、密码是否正确，以及手机/电脑是否在同一局域网。';
      });
    }
  }

  void _finish() {
    widget.config.routerUrl = _urlCtrl.text.trim();
    widget.config.username = _userCtrl.text.trim();
    widget.config.password = _pwdCtrl.text;
    widget.config.subRouterMac = _subRouterMac;
    widget.config.lockMac = _lockMac;
    widget.config.permanentMacs = _permanentMacs;
    widget.config.favoriteMacs = _favoriteMacs;
    StorageService.save(widget.config);
    widget.onFinished(widget.config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _page = i),
        children: [
          _page1(),
          _page2(),
        ],
      ),
    );
  }

  Widget _page1() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Icon(Icons.router, size: 48, color: scheme.primary),
            const SizedBox(height: 16),
            const Text('欢迎使用家络看板', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('先填写路由器后台地址和管理员密码', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 28),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(labelText: '路由器地址', hintText: 'http://192.168.3.1', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(labelText: '用户名', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '管理员密码', border: OutlineInputBorder()),
            ),
            if (_testError != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(_testError!, style: TextStyle(color: scheme.error, fontSize: 12.5)),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _testing ? null : _testAndFetch,
                child: _testing
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('测试连接并继续'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page2() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('初步设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('已抓取到 ${_devices.length} 台设备，按需选择以下分类（都可以不选，之后在设置中再改）',
                style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _pickerTile('子路由设备（全局置顶，最多1台）', _subRouterMac, (mac) {
                    setState(() => _subRouterMac = mac);
                  }, multi: false),
                  const Divider(),
                  _pickerTile('门锁设备', _lockMac, (mac) {
                    setState(() => _lockMac = mac);
                  }, multi: false),
                  const Divider(),
                  _multiPickerSection('常驻设备（统计个人在线数时排除）', _permanentMacs),
                  const Divider(),
                  _multiPickerSection('关注设备（用于离线提醒列表）', _favoriteMacs),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _finish, child: const Text('完成，进入看板')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerTile(String title, String? value, ValueChanged<String?> onChanged,
      {required bool multi}) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(value == null ? '未选择' : _nameOf(value), style: const TextStyle(fontSize: 12)),
      children: [
        RadioListTile<String?>(
          value: null,
          groupValue: value,
          title: const Text('不选择'),
          onChanged: onChanged,
        ),
        ..._devices.map((d) => RadioListTile<String?>(
              value: d.mac,
              groupValue: value,
              title: Text(d.rawDisplayName),
              subtitle: Text(d.mac, style: const TextStyle(fontSize: 11)),
              onChanged: onChanged,
            )),
      ],
    );
  }

  Widget _multiPickerSection(String title, Set<String> set) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text('${set.length} 台已选', style: const TextStyle(fontSize: 12)),
      children: _devices
          .map((d) => CheckboxListTile(
                value: set.contains(d.mac),
                title: Text(d.rawDisplayName),
                subtitle: Text(d.mac, style: const TextStyle(fontSize: 11)),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      set.add(d.mac);
                    } else {
                      set.remove(d.mac);
                    }
                  });
                },
              ))
          .toList(),
    );
  }

  String _nameOf(String mac) {
    final d = _devices.where((d) => d.mac == mac);
    return d.isEmpty ? mac : d.first.rawDisplayName;
  }
}
