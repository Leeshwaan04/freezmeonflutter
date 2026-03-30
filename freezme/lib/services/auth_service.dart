import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'api_client.dart';

/// Holds the signed-in user's basic info derived from the JWT.
class AuthUser {
  const AuthUser({required this.uid, this.email, this.displayName});

  final String uid;
  final String? email;
  final String? displayName;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        uid: json['id'] as String,
        email: json['email'] as String?,
        displayName: json['displayName'] as String?,
      );
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
    final google = GoogleSignIn.instance;
    await google.initialize();
    final googleUser = await google.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) throw Exception('Google auth: no idToken');

    final response = await _client.dio.post(
      '/auth/google',
      data: {'idToken': idToken},
    );

    return _handleAuthResponse(response.data as Map<String, dynamic>);
  }

  // ── Apple Sign-In ───────────────────────────────────────────────────────────

  Future<AuthUser> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );

    final response = await _client.dio.post(
      '/auth/apple',
      data: {'identityToken': credential.identityToken},
    );

    return _handleAuthResponse(response.data as Map<String, dynamic>);
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
