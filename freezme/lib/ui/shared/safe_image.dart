import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Fallback avatar used when a profile has no usable image URL.
const String kFallbackAvatarUrl =
    'https://images.unsplash.com/photo-1546961329-78bef0414d7c?fit=crop&w=320';

/// Returns a safe image URL, substituting the fallback when [url] is null OR
/// empty. `CachedNetworkImageProvider('')` throws at runtime, so an empty
/// string from the server must never reach it (DI2).
String safeImageUrl(String? url, {String fallback = kFallbackAvatarUrl}) {
  if (url == null) return fallback;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return fallback;
  return trimmed;
}

/// An [ImageProvider] that never throws on empty/null input.
ImageProvider safeImageProvider(String? url, {String fallback = kFallbackAvatarUrl}) {
  return CachedNetworkImageProvider(safeImageUrl(url, fallback: fallback));
}

/// Convenience widget for a circular avatar with fade-in and graceful fallback.
class SafeAvatar extends StatelessWidget {
  const SafeAvatar({
    super.key,
    required this.url,
    this.radius = 22,
    this.backgroundColor,
    this.fallback = kFallbackAvatarUrl,
  });

  final String? url;
  final double radius;
  final Color? backgroundColor;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: safeImageProvider(url, fallback: fallback),
    );
  }
}
