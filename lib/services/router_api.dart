import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class AuthExpiredError implements Exception {
  final String message;
  AuthExpiredError(this.message);
  @override
  String toString() => 'AuthExpiredError: $message';
}

/// PBKDF2-HMAC-SHA256，对应 python 的 hashlib.pbkdf2_hmac("sha256", ...)
Uint8List pbkdf2HmacSha256(
    List<int> password, List<int> salt, int iterations, int dkLen) {
  final hmac = Hmac(sha256, password);
  const hLen = 32;
  final l = (dkLen / hLen).ceil();
  final out = BytesBuilder();

  for (var i = 1; i <= l; i++) {
    final intBlock = Uint8List(4)
      ..buffer.asByteData().setUint32(0, i, Endian.big);
    var u = hmac.convert([...salt, ...intBlock]).bytes;
    final t = Uint8List.fromList(u);
    for (var j = 1; j < iterations; j++) {
      u = hmac.convert(u).bytes;
      for (var k = 0; k < t.length; k++) {
        t[k] ^= u[k];
      }
    }
    out.add(t);
  }
  return Uint8List.fromList(out.toBytes().sublist(0, dkLen));
}

String _bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> _hexToBytes(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}

class RouterApi {
  final String baseUrl;
  final String username;
  final String password;
  final http.Client _client = http.Client();

  String _csrfParam = '';
  String _csrfToken = '';
  final Map<String, String> _cookies = {};

  RouterApi({required this.baseUrl, required this.username, required this.password});

  void _saveCookies(http.Response resp) {
    final raw = resp.headers['set-cookie'];
    if (raw == null) return;
    for (final part in raw.split(',')) {
      final kv = part.split(';').first.trim();
      final idx = kv.indexOf('=');
      if (idx > 0) _cookies[kv.substring(0, idx)] = kv.substring(idx + 1);
    }
  }

  String get _cookieHeader =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        '_ResponseFormat': 'JSON',
        if (_cookies.isNotEmpty) 'Cookie': _cookieHeader,
      };

  /// 登录：获取 csrf token -> nonce -> proof，流程对应 python 版 login()
  Future<void> login() async {
    final indexResp = await _client
        .get(Uri.parse('$baseUrl/html/index.html'))
        .timeout(const Duration(seconds: 8));
    _saveCookies(indexResp);
    final body = indexResp.body;
    final paramMatch =
        RegExp(r'name="csrf_param"\s+content="([^"]+)"').firstMatch(body);
    final tokenMatch =
        RegExp(r'name="csrf_token"\s+content="([^"]+)"').firstMatch(body);
    if (paramMatch == null || tokenMatch == null) {
      throw Exception('获取Token失败，请检查路由器地址是否正确');
    }
    _csrfParam = paramMatch.group(1)!;
    _csrfToken = tokenMatch.group(1)!;

    final rand = Random.secure();
    final clientNonceBytes =
        List<int>.generate(32, (_) => rand.nextInt(256));
    final clientNonce = _bytesToHex(clientNonceBytes);

    final nonceResp = await _apiPost('system/user_login_nonce', {
      'username': username,
      'firstnonce': clientNonce,
    });

    final serverNonce = nonceResp['servernonce'] as String;
    final salt = nonceResp['salt'] as String;
    final iterations = int.parse(nonceResp['iterations'].toString());

    final authMessage = '$clientNonce,$serverNonce,$serverNonce';
    final saltedPwd = pbkdf2HmacSha256(
        utf8.encode(password), _hexToBytes(salt), iterations, 32);
    final clientKey =
        Hmac(sha256, utf8.encode('Client Key')).convert(saltedPwd).bytes;
    final storedDigest = sha256.convert(clientKey).bytes;
    final clientSignature =
        Hmac(sha256, utf8.encode(authMessage)).convert(storedDigest).bytes;

    final clientProof = Uint8List(clientKey.length);
    for (var i = 0; i < clientKey.length; i++) {
      clientProof[i] = clientKey[i] ^ clientSignature[i];
    }

    await _apiPost('system/user_login_proof', {
      'clientproof': _bytesToHex(clientProof),
      'finalnonce': serverNonce,
    });
  }

  Future<Map<String, dynamic>> _apiPost(
      String name, Map<String, dynamic> data) async {
    final body = jsonEncode({
      'data': data,
      'csrf': {'csrf_param': _csrfParam, 'csrf_token': _csrfToken},
    });
    final resp = await _client
        .post(
          Uri.parse('$baseUrl/api/$name'),
          headers: _headers,
          body: body,
        )
        .timeout(const Duration(seconds: 8));
    _saveCookies(resp);
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    if (j['csrf_param'] != null) {
      _csrfParam = j['csrf_param'];
      _csrfToken = j['csrf_token'];
    }
    return j;
  }

  /// 获取设备列表，对应 python 版 api_get("system/HostInfo")
  /// 状态码异常 / 空响应 / 非 JSON / 格式不对 都视为会话过期
  Future<List<dynamic>> getHostInfo() async {
    try {
      final resp = await _client
          .get(
            Uri.parse('$baseUrl/api/system/HostInfo'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200 || resp.body.trim().isEmpty) {
        throw AuthExpiredError('状态码 ${resp.statusCode} 或响应为空');
      }
      dynamic data;
      try {
        data = jsonDecode(resp.body);
      } catch (_) {
        throw AuthExpiredError('响应不是有效JSON');
      }
      if (data is List) return data;
      if (data is Map && data['HostInfo'] is List) {
        return data['HostInfo'] as List;
      }
      throw AuthExpiredError('HostInfo 格式异常');
    } on AuthExpiredError {
      rethrow;
    } catch (e) {
      throw AuthExpiredError('请求异常: $e');
    }
  }

  /// 尽力而为地登出，释放路由器的并发登录名额。
  /// 路由器固件没有在python脚本里出现这个接口，名字是猜的，
  /// 如果你这台路由器接口名不一样，把这里改成实际接口名即可；
  /// 就算失败也不抛错，不影响主流程。
  Future<void> logout() async {
    try {
      await _apiPost('system/user_logout', {}).timeout(const Duration(seconds: 4));
    } catch (_) {
      // 忽略：登出本身是锦上添花，不应该影响其他流程
    }
  }

  void dispose() => _client.close();
}
