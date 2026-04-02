import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.freezme.in',
);

const _kAccessTokenKey = 'access_token';
const _kRefreshTokenKey = 'refresh_token';

/// Token storage that tries SecureStorage first, falls back to SharedPreferences.
/// SecureStorage silently fails on iOS Simulator (no Keychain entitlements).
class _TokenStorage {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> write(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
      // Verify the write actually stuck (simulator keychain bug)
      final check = await _secure.read(key: key);
      if (check == value) return;
    } catch (_) {}
    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> read(String key) async {
    try {
      final val = await _secure.read(key: key);
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}
    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> delete(String key) async {
    try { await _secure.delete(key: key); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> deleteAll() async {
    try { await _secure.deleteAll(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessTokenKey);
    await prefs.remove(_kRefreshTokenKey);
  }
}

class ApiClient {
  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(_AuthInterceptor(_storage, _dio));
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  final _TokenStorage _storage = _TokenStorage();

  Dio get dio => _dio;

  // ── Token management ────────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(_kAccessTokenKey, accessToken),
      _storage.write(_kRefreshTokenKey, refreshToken),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(_kAccessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(_kRefreshTokenKey);

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(_kAccessTokenKey),
      _storage.delete(_kRefreshTokenKey),
    ]);
  }

  Future<bool> get isLoggedIn async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage, this._dio);

  final _TokenStorage _storage;
  final Dio _dio;
  bool _refreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(_kAccessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_refreshing) {
      _refreshing = true;
      try {
        final refreshToken = await _storage.read(_kRefreshTokenKey);
        if (refreshToken == null) {
          await _storage.deleteAll();
          handler.next(err);
          return;
        }

        final response = await _dio.post(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
          options: Options(headers: {'Authorization': null}),
        );

        final newAccess = response.data['accessToken'] as String;
        final newRefresh = response.data['refreshToken'] as String;
        await _storage.write(_kAccessTokenKey, newAccess);
        await _storage.write(_kRefreshTokenKey, newRefresh);

        // Retry original request
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retried = await _dio.fetch(err.requestOptions);
        handler.resolve(retried);
      } catch (_) {
        await _storage.deleteAll();
        handler.next(err);
      } finally {
        _refreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}
