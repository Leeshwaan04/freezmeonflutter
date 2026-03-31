import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.freezme.in',
);

const _kAccessTokenKey = 'access_token';
const _kRefreshTokenKey = 'refresh_token';

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
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Dio get dio => _dio;

  // ── Token management ────────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessTokenKey, value: accessToken),
      _storage.write(key: _kRefreshTokenKey, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _kAccessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshTokenKey);

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessTokenKey),
      _storage.delete(key: _kRefreshTokenKey),
    ]);
  }

  Future<bool> get isLoggedIn async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage, this._dio);

  final FlutterSecureStorage _storage;
  final Dio _dio;
  bool _refreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _storage.read(key: _kAccessTokenKey);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Keychain unavailable (e.g. iOS Simulator entitlement error) — proceed without token
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
        String? refreshToken;
        try {
          refreshToken = await _storage.read(key: _kRefreshTokenKey);
        } catch (_) {
          handler.next(err);
          _refreshing = false;
          return;
        }
        if (refreshToken == null) {
          try { await _storage.deleteAll(); } catch (_) {}
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
        await _storage.write(key: _kAccessTokenKey, value: newAccess);
        await _storage.write(key: _kRefreshTokenKey, value: newRefresh);

        // Retry original request
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retried = await _dio.fetch(err.requestOptions);
        handler.resolve(retried);
      } catch (_) {
        try { await _storage.deleteAll(); } catch (_) {}
        handler.next(err);
      } finally {
        _refreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}
