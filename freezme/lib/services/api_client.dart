import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.freezme.in',
);

const _kAccessTokenKey = 'access_token';
const _kRefreshTokenKey = 'refresh_token';

/// Token storage using FlutterSecureStorage (Keychain on iOS, Keystore on Android).
/// In debug mode only, falls back to SharedPreferences when SecureStorage fails
/// (iOS Simulator has no Keychain entitlements). Release builds fail hard on error.
class _TokenStorage {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> write(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
      final check = await _secure.read(key: key);
      if (check == value) return;
      // Write didn't stick — only tolerate in debug (simulator)
      if (!kDebugMode) throw Exception('SecureStorage write verification failed');
    } catch (_) {
      if (!kDebugMode) rethrow;
    }
    // Debug-only fallback for iOS Simulator
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> read(String key) async {
    try {
      final val = await _secure.read(key: key);
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {
      if (!kDebugMode) rethrow;
    }
    // Debug-only fallback
    if (!kDebugMode) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> delete(String key) async {
    try { await _secure.delete(key: key); } catch (_) {}
    if (kDebugMode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }

  Future<void> deleteAll() async {
    try { await _secure.deleteAll(); } catch (_) {}
    if (kDebugMode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccessTokenKey);
      await prefs.remove(_kRefreshTokenKey);
    }
  }
}

class ApiClient {
  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _authInterceptor = _AuthInterceptor(_storage, _dio);
    _dio.interceptors.add(_authInterceptor);
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  late final _AuthInterceptor _authInterceptor;
  final _TokenStorage _storage = _TokenStorage();

  Dio get dio => _dio;

  // ── Token management ────────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _authInterceptor.cacheToken(accessToken); // update in-memory cache immediately
    await Future.wait([
      _storage.write(_kAccessTokenKey, accessToken),
      _storage.write(_kRefreshTokenKey, refreshToken),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(_kAccessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(_kRefreshTokenKey);

  Future<void> clearTokens() async {
    _authInterceptor.clearCache(); // evict in-memory cache on logout
    await Future.wait([
      _storage.delete(_kAccessTokenKey),
      _storage.delete(_kRefreshTokenKey),
    ]);
  }

  Future<bool> get isLoggedIn async {
    final token = _authInterceptor._cachedAccessToken ?? await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage, this._dio);

  final _TokenStorage _storage;
  final Dio _dio;

  // In-memory cache — eliminates a secure storage read on every API call.
  String? _cachedAccessToken;

  /// Serializes concurrent 401 refresh attempts.
  /// While a refresh is in-flight, all other 401 callers await this same Future
  /// instead of each triggering their own refresh (which would cause token
  /// rotation conflicts and unnecessary /auth/refresh calls).
  Future<String?>? _refreshFuture;

  /// Call once after login/refresh to populate the cache.
  void cacheToken(String token) => _cachedAccessToken = token;
  void clearCache() => _cachedAccessToken = null;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Use cached token when available; only hit storage on first call.
    _cachedAccessToken ??= await _storage.read(_kAccessTokenKey);
    if (_cachedAccessToken != null) {
      options.headers['Authorization'] = 'Bearer $_cachedAccessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Don't retry the refresh endpoint itself — avoids infinite loop.
    if (err.requestOptions.path.contains('/auth/refresh')) {
      await _storage.deleteAll();
      clearCache();
      _refreshFuture = null;
      handler.next(err);
      return;
    }

    try {
      // All concurrent 401s share the same refresh Future — only one actually
      // calls /auth/refresh; the others await the result and retry with the
      // new token returned by the winning call.
      _refreshFuture ??= _doRefresh();
      final newToken = await _refreshFuture;
      _refreshFuture = null;

      if (newToken == null) {
        // Refresh failed (no refresh token or server rejected it) — propagate.
        handler.next(err);
        return;
      }

      // Retry original request with the new token.
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      final retried = await _dio.fetch(err.requestOptions);
      handler.resolve(retried);
    } catch (_) {
      _refreshFuture = null;
      handler.next(err);
    }
  }

  /// Performs one refresh exchange. Returns the new access token, or null if
  /// the refresh token is missing / invalid (caller should log out).
  Future<String?> _doRefresh() async {
    clearCache();
    try {
      final refreshToken = await _storage.read(_kRefreshTokenKey);
      if (refreshToken == null) {
        await _storage.deleteAll();
        return null;
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
      cacheToken(newAccess);
      return newAccess;
    } catch (_) {
      await _storage.deleteAll();
      clearCache();
      return null;
    }
  }
}
