import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'api_client.dart';
import 'push_notification_service.dart';

/// Holds the signed-in user's basic info derived from the JWT and /profiles/me.
class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.photoUrls = const [],
    this.age,
    this.bio,
    this.gender,
    this.interests = const [],
    this.intent,
    this.isPremium = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  /// Primary profile photo URL (first uploaded photo or imageUrl from server).
  final String? photoUrl;
  /// All uploaded photo URLs for populating photo slots.
  final List<String> photoUrls;
  final int? age;
  final String? bio;
  final String? gender;
  final List<String> interests;
  final String? intent;
  final bool isPremium;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    // The server may return photoUrls as an array or imageUrl as a single string.
    final rawPhotoUrls = json['photoUrls'];
    final List<String> photoUrls = rawPhotoUrls is List
        ? rawPhotoUrls.whereType<String>().toList()
        : const [];
    final String? imageUrl = json['imageUrl'] as String? ?? json['photoUrl'] as String?;
    final String? primaryPhoto =
        photoUrls.isNotEmpty ? photoUrls.first : imageUrl;

    // /profiles/me uses 'userId', auth response uses 'id'
    final uid = (json['userId'] as String?) ?? (json['id'] as String);

    final rawInterests = json['interests'];
    final List<String> interests = rawInterests is List
        ? rawInterests.whereType<String>().toList()
        : const [];

    return AuthUser(
      uid: uid,
      email: json['email'] as String?,
      displayName: (json['displayName'] as String?) ?? (json['name'] as String?),
      photoUrl: primaryPhoto,
      photoUrls: photoUrls,
      age: (json['age'] as num?)?.toInt(),
      bio: json['bio'] as String?,
      gender: json['gender'] as String?,
      interests: interests,
      intent: json['intent'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
    );
  }

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    List<String>? photoUrls,
    int? age,
    String? bio,
    String? gender,
    List<String>? interests,
    String? intent,
    bool? isPremium,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      age: age ?? this.age,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      interests: interests ?? this.interests,
      intent: intent ?? this.intent,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}

/// Replacement for FirebaseAuth — issues and stores JWTs via the EC2 API.
class AuthService {
  AuthService._() {
    // When ApiClient's refresh fails, drop the in-memory user so listeners
    // (FlowController._listenToAuth) route back to the auth gate.
    ApiClient.onSessionExpired = () {
      _setUser(null);
    };
  }

  static final AuthService instance = AuthService._();

  final _client = ApiClient.instance;
  final _authStateController = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  Stream<AuthUser?> get authStateChanges => _authStateController.stream;
  AuthUser? get currentUser => _currentUser;

  // ── One-time Google Sign-In initialisation ──────────────────────────────────

  static bool _googleInitialized = false;

  static Future<void> initGoogleSignIn() async {
    if (_googleInitialized) return;
    _googleInitialized = true;
    try {
      await GoogleSignIn.instance.initialize(
        // iOS OAuth client ID — the idToken audience will be this value.
        // The server's GOOGLE_IOS_CLIENT_ID must match.
        serverClientId: '542457497074-3uq4cfeimroq5v6d711ip0r52gdle7jn.apps.googleusercontent.com',
      );
    } catch (e) {
      debugPrint('[AuthService] GoogleSignIn.initialize error: $e');
      _googleInitialized = false; // allow retry
    }
  }

  // ── Initialise on app start ─────────────────────────────────────────────────

  Future<void> init() async {
    final loggedIn = await _client.isLoggedIn;
    if (loggedIn) {
      try {
        final response = await _client.dio.get('/profiles/me');
        final user = AuthUser.fromJson(response.data as Map<String, dynamic>);
        _setUser(user);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 404) {
          // Token is valid but profile hasn't been created yet (new signup).
          // Stay logged in with a minimal user derived from the JWT uid stored
          // in the access token — the onboarding flow will create the profile.
          final uid = await _extractUidFromToken();
          if (uid != null) {
            _setUser(AuthUser(uid: uid));
          } else {
            await _client.clearTokens();
            _setUser(null);
          }
        } else if (status == 401) {
          // Genuine auth failure: access token invalid AND the interceptor's
          // refresh was rejected. Real session expiry → clear + route to auth.
          await _client.clearTokens();
          _setUser(null);
        } else {
          // Transient at launch (offline, timeout, 5xx, no response). Do NOT
          // log the user out or wipe tokens — restore a minimal session from
          // the cached token so they stay in the app; refreshProfile() hydrates
          // the full profile once connectivity returns. This prevents spurious
          // cold-start logouts on a flaky network.
          final uid = await _extractUidFromToken();
          if (uid != null) {
            _setUser(AuthUser(uid: uid));
          } else {
            _setUser(null); // can't read token, but don't nuke storage
          }
        }
      } catch (_) {
        // Unknown/transient error — preserve tokens; restore from cached token
        // if possible rather than forcing a logout.
        final uid = await _extractUidFromToken();
        _setUser(uid != null ? AuthUser(uid: uid) : null);
      }
    } else {
      _setUser(null);
    }
  }

  /// Decodes the stored access token to extract the uid without a network call.
  Future<String?> _extractUidFromToken() async {
    try {
      final token = await _client.getAccessToken();
      if (token == null) return null;
      // JWT is base64url: header.payload.signature — decode the payload part.
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // Base64url → base64 (pad to multiple of 4)
      String payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2: payload += '=='; break;
        case 3: payload += '='; break;
      }
      final decoded = String.fromCharCodes(
        base64Decode(payload),
      );
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return json['uid'] as String? ?? json['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────────

  Future<AuthUser> signInWithGoogle() async {
    await initGoogleSignIn();
    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) throw Exception('Google auth: no idToken');

    final response = await _client.dio.post(
      '/auth/google',
      data: {
        'idToken': idToken,
        'displayName': googleUser.displayName ?? '',
        'photoUrl': googleUser.photoUrl ?? '',
      },
    );

    return _handleAuthResponse(response.data as Map<String, dynamic>);
  }

  // ── Apple Sign-In ───────────────────────────────────────────────────────────

  Future<AuthUser> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const SignInWithAppleAuthorizationException(
        code: AuthorizationErrorCode.unknown,
        message: 'Apple credential missing identityToken',
      );
    }

    // Apple only provides name on FIRST authorization — capture it now
    final displayName = [credential.givenName, credential.familyName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');

    final response = await _client.dio.post(
      '/auth/apple',
      data: {
        'identityToken': identityToken,
        if (displayName.isNotEmpty) 'displayName': displayName,
      },
    );

    return _handleAuthResponse(response.data as Map<String, dynamic>);
  }

  /// Returns true if [e] represents a user-initiated cancel (not an error to show).
  static bool isAppleCancelError(Object e) {
    if (e is SignInWithAppleAuthorizationException) {
      return e.code == AuthorizationErrorCode.canceled;
    }
    if (e is PlatformException) {
      final code = e.code.toLowerCase();
      return code.contains('cancel') || code.contains('1001');
    }
    return false;
  }

  /// Returns true if [e] represents a user-initiated Google cancel.
  static bool isGoogleCancelError(Object e) {
    if (e is PlatformException) {
      return e.code == 'sign_in_canceled' || e.code == 'sign_in_failed';
    }
    final msg = e.toString().toLowerCase();
    return msg.contains('canceled') || msg.contains('cancelled') || msg.contains('cancel');
  }

  // ── Email Sign-In / Sign-Up ─────────────────────────────────────────────────

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.dio.post(
      '/auth/email',
      data: {'email': email, 'password': password, 'action': 'signin'},
    );
    return _handleAuthResponse(response.data as Map<String, dynamic>);
  }

  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.dio.post(
      '/auth/email',
      data: {'email': email, 'password': password, 'action': 'signup'},
    );
    return _handleAuthResponse(response.data as Map<String, dynamic>);
  }

  Future<void> sendPasswordReset({required String email}) async {
    await _client.dio.post(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  Future<void> sendEmailVerification() async {
    await _client.dio.post('/auth/send-verification');
  }

  // ── Refresh profile data from server ───────────────────────────────────────

  Future<void> refreshProfile() async {
    if (_currentUser == null) return;
    try {
      final response = await _client.dio.get('/profiles/me');
      final updated = AuthUser.fromJson(response.data as Map<String, dynamic>);
      _setUser(updated);
    } catch (e) {
      debugPrint('[AuthService] refreshProfile error: $e');
    }
  }

  // ── Sign-Out ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      // Clear the FCM token server-side FIRST so the next user on this device
      // doesn't receive push notifications meant for the current user (A9).
      try {
        await PushNotificationService().clearToken();
      } catch (_) { /* best-effort */ }

      final refreshToken = await _client.getRefreshToken();
      if (refreshToken != null) {
        await _client.dio.post(
          '/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (e) {
      debugPrint('[AuthService] logout error: $e');
    } finally {
      await _client.clearTokens();
      _setUser(null);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<AuthUser> _handleAuthResponse(Map<String, dynamic> data) async {
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    final userJson = data['user'] as Map<String, dynamic>;

    await _client.saveTokens(accessToken: accessToken, refreshToken: refreshToken);

    // If server says a profile exists, fetch the full profile immediately so
    // the flow controller gets displayName/age/gender in the first auth event.
    // This avoids an extra round-trip and makes onboarding skip instant for
    // returning users.
    final hasProfile = data['hasProfile'] as bool? ?? false;
    if (hasProfile) {
      try {
        final profileRes = await _client.dio.get('/profiles/me');
        final fullUser = AuthUser.fromJson(profileRes.data as Map<String, dynamic>);
        _setUser(fullUser);
        return fullUser;
      } catch (_) {
        // Fall through to basic user if profile fetch fails
      }
    }

    final user = AuthUser.fromJson(userJson);
    _setUser(user);
    return user;
  }

  void _setUser(AuthUser? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  void dispose() {
    _authStateController.close();
  }
}
