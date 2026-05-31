import 'package:dio/dio.dart';

/// Converts any thrown error into a short, user-friendly message. Never leak
/// raw exception/stacktrace text (e.g. "DioException [connectTimeout]") into UI.
String humanizeError(Object? error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The connection timed out. Check your internet and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode ?? 0;
        // Prefer a server-provided human message when present.
        final data = error.response?.data;
        if (data is Map && data['error'] is String) {
          final msg = data['error'] as String;
          // Guard against the server echoing internal detail.
          if (msg.length < 160 && !msg.contains('Exception') && !msg.contains('at ')) {
            return msg;
          }
        }
        if (code == 401) return 'Your session expired. Please sign in again.';
        if (code == 403) return "You don't have permission to do that.";
        if (code == 404) return 'Not found.';
        if (code == 409) return 'That action conflicts with the current state.';
        if (code == 429) return "You're doing that too fast. Please wait a moment.";
        if (code >= 500) return 'Our servers had a hiccup. Please try again shortly.';
        return fallback;
      case DioExceptionType.cancel:
        return fallback;
      default:
        return fallback;
    }
  }
  return fallback;
}
