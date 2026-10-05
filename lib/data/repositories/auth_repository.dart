import 'package:bilihear/core/api/api_exception.dart';
import 'package:bilihear/core/api/bili_client.dart';
import 'package:bilihear/core/api/bili_endpoints.dart';
import 'package:bilihear/core/models/bili_user.dart';
import 'package:bilihear/core/models/json_utils.dart';

/// A generated login QR code.
class QrSession {
  const QrSession({required this.url, required this.key});

  /// Content that must be rendered as a QR code.
  final String url;

  /// Opaque key used to poll the login state.
  final String key;
}

enum QrLoginStatus { waiting, scanned, expired, success, failed }

class QrPollResult {
  const QrPollResult(this.status, {this.message});

  final QrLoginStatus status;
  final String? message;
}

/// Handles QR-code login, session inspection and logout.
class AuthRepository {
  AuthRepository(this._client);

  final BiliClient _client;

  bool get isLoggedIn => _client.isLoggedIn;

  /// Requests a fresh login QR code.
  Future<QrSession> createQrSession() async {
    final response = await _client.getJson(
      BiliEndpoints.qrGenerate,
      baseUrl: BiliEndpoints.passportBase,
    );
    final data = JsonUtils.map(response['data']);
    final url = JsonUtils.string(data['url']);
    final key = JsonUtils.string(data['qrcode_key']);
    if (url.isEmpty || key.isEmpty) {
      throw const BiliApiException(
        code: -1,
        message: '无法获取登录二维码，请稍后重试',
        path: BiliEndpoints.qrGenerate,
      );
    }
    return QrSession(url: url, key: key);
  }

  /// Polls the state of a previously created QR session.
  Future<QrPollResult> pollQrSession(String key) async {
    final response = await _client.getJson(
      BiliEndpoints.qrPoll,
      baseUrl: BiliEndpoints.passportBase,
      query: {'qrcode_key': key},
    );
    final data = JsonUtils.map(response['data']);
    final code = JsonUtils.integer(data['code']);

    switch (code) {
      case 0:
        await _persistLoginCookies(data);
        return const QrPollResult(QrLoginStatus.success);
      case 86090:
        return const QrPollResult(QrLoginStatus.scanned);
      case 86038:
        return const QrPollResult(QrLoginStatus.expired);
      case 86101:
        return const QrPollResult(QrLoginStatus.waiting);
      default:
        return QrPollResult(
          QrLoginStatus.failed,
          message: JsonUtils.string(data['message'], fallback: '登录失败'),
        );
    }
  }

  /// Returns the signed-in account, or `null` when no session is active.
  Future<BiliUser?> fetchCurrentUser() async {
    final data = await _client.fetchNav();
    if (!JsonUtils.boolean(data['isLogin'])) return null;
    final user = BiliUser.fromNav(data);
    try {
      final stat = await _client.getJson(BiliEndpoints.navStat);
      final statData = JsonUtils.map(stat['data']);
      return user.copyWith(
        following: JsonUtils.integer(statData['following']),
        follower: JsonUtils.integer(statData['follower']),
      );
    } on BiliApiException {
      return user;
    }
  }

  /// Clears the session locally and invalidates it on the server.
  Future<void> logout() async {
    final csrf = _client.cookies.csrfToken;
    try {
      if (_client.isLoggedIn && csrf != null && csrf.isNotEmpty) {
        await _client.postForm(
          BiliEndpoints.exitLogin,
          {'biliCSRF': csrf},
          baseUrl: BiliEndpoints.passportBase,
        );
      }
    } on BiliApiException {
      // The remote session is best-effort; the local cookies are cleared below.
    } finally {
      await _client.cookies.clear();
    }
  }

  /// The web login flow returns the session cookies via `Set-Cookie`
  /// (already captured by the client) and again inside `data.url`. The latter
  /// is only used for cookies the response headers did not provide.
  ///
  /// Values are parsed from the raw query string without percent-decoding,
  /// because `SESSDATA` itself contains escaped characters.
  Future<void> _persistLoginCookies(Map<String, dynamic> data) async {
    final url = JsonUtils.string(data['url']);
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final rawQuery = uri.query;

    final missing = <String, String>{};
    for (final name in const [
      'SESSDATA',
      'bili_jct',
      'DedeUserID',
      'DedeUserID__ckMd5',
    ]) {
      final existing = _client.cookies[name];
      if (existing != null && existing.isNotEmpty) continue;
      final value = _rawQueryValue(rawQuery, name);
      if (value != null && value.isNotEmpty) missing[name] = value;
    }
    if (missing.isNotEmpty) {
      await _client.cookies.setAll(missing);
    }
  }

  static String? _rawQueryValue(String rawQuery, String name) {
    for (final pair in rawQuery.split('&')) {
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      if (pair.substring(0, separator) == name) {
        return pair.substring(separator + 1);
      }
    }
    return null;
  }
}
