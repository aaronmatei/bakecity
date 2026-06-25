import 'package:shared_preferences/shared_preferences.dart';

/// Thin async wrapper around [SharedPreferences] for auth token persistence.
///
/// NOTE: `shared_preferences` is not encrypted storage. For production,
/// swap the implementation for `flutter_secure_storage` while keeping this
/// interface stable.
class TokenStorage {
  TokenStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _accessTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';

  /// Creates a [TokenStorage] backed by the platform shared preferences.
  static Future<TokenStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return TokenStorage(prefs);
  }

  Future<String?> readAccessToken() async => _prefs.getString(_accessTokenKey);

  Future<String?> readRefreshToken() async =>
      _prefs.getString(_refreshTokenKey);

  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _prefs.setString(_accessTokenKey, accessToken);
    if (refreshToken != null) {
      await _prefs.setString(_refreshTokenKey, refreshToken);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_accessTokenKey);
    await _prefs.remove(_refreshTokenKey);
  }

  Future<bool> get hasToken async {
    final token = await readAccessToken();
    return token != null && token.isNotEmpty;
  }
}
