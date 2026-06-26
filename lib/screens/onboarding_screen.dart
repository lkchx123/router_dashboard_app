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
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.celebration_outlined, size: 44, color: scheme.primary),
            const SizedBox(height: 16),
            const Text('连接成功！', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('已抓取到 ${_devices.length} 台设备，接下来按需把它们分一下类：',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            _stepTile(Icons.router_outlined, '子路由设备',
                '首页用一张更详细的卡片单独展示（在线状态/IP/速率/流量），不会出现在普通设备列表里。\n设置 → 子路由设备'),
            _stepTile(Icons.lock_outline, '门锁设备',
                '首页单独一张状态卡，显示在线/离线和上次动作时间，不出现在列表里。\n设置 → 门锁设备'),
            _stepTile(Icons.push_pin_outlined, '常驻设备',
                '比如路由器自己、智能音箱这类一直在线的，统计"个人设备在线数"时会被排除掉。\n设置 → 常驻设备'),
            _stepTile(Icons.star_outline, '关注设备',
                '会在设备名前加⭐标记，并在离线列表里置顶显示，方便你重点盯着。\n首页长按设备 或 设置 → 关注设备'),
            const Spacer(),
            Text('这些都可以先不选，随时去"设置"里改。', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _finish, child: const Text('完成，进入看板')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepTile(IconData icon, String title, String desc) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: scheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
