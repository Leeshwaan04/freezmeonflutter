import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'api_client.dart';

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
    );
  }
}

/// Replacement for FirebaseAuth — issues and stores JWTs via the EC2 API.
class AuthService {
  AuthService._();

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
        serverClientId: '542457497074-a16d48099255920f1e576b.apps.googleusercontent.com',
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
      // Try to fetch current user from /profiles/me to verify token still valid
      try {
        final response = await _client.dio.get('/profiles/me');
        final user = AuthUser.fromJson(response.data as Map<String, dynamic>);
        _setUser(user);
      } catch (_) {
        // Token invalid / expired → treat as logged out
        await _client.clearTokens();
        _setUser(null);
      }
    } else {
      _setUser(null);
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

    final response = await _client.dio.post(
      '/auth/apple',
      data: {'identityToken': identityToken},
    );

    return _handleAuthResponse(response.data as Map<String, dynamic>);
  }

  /// Returns true if [e] represents a user-initiated cancel (not an error to show).
  static bool isAppleCancelError(Object e) {
    if (e is SignInWithAppleAuthorizationException) {
      return e.code == AuthorizationErrorCode.canceled ||
          e.code == AuthorizationErrorCode.unknown;
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

  AuthUser _handleAuthResponse(Map<String, dynamic> data) {
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    final userJson = data['user'] as Map<String, dynamic>;

    _client.saveTokens(accessToken: accessToken, refreshToken: refreshToken);

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
