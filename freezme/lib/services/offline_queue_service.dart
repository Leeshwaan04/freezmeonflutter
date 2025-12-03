import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline queue service for queuing operations when network is unavailable
class OfflineQueueService {
  OfflineQueueService(this._prefs);
  
  final SharedPreferences? _prefs;
  static const _kQueueKey = 'offline_queue';
  
  /// Queue an operation for later execution
  Future<void> queueOperation({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final queue = await _getQueue();
    queue.add({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    await _saveQueue(queue);
  }
  
  /// Get all queued operations
  Future<List<Map<String, dynamic>>> getQueuedOperations() async {
    return await _getQueue();
  }
  
  /// Remove operation from queue
  Future<void> removeOperation(String id) async {
    final queue = await _getQueue();
    queue.removeWhere((op) => op['id'] == id);
    await _saveQueue(queue);
  }
  
  /// Clear all queued operations
  Future<void> clearQueue() async {
    await _prefs?.remove(_kQueueKey);
  }
  
  /// Get queue count
  Future<int> get queueCount async {
    final queue = await _getQueue();
    return queue.length;
  }
  
  // Private helpers
  Future<List<Map<String, dynamic>>> _getQueue() async {
    final json = _prefs?.getString(_kQueueKey);
    if (json == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(json);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error decoding queue: $e');
      return [];
    }
  }
  
  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    await _prefs?.setString(_kQueueKey, jsonEncode(queue));
  }
}

/// Image quality optimization based on network conditions
enum ImageQuality {
  low(maxSize: 200, quality: 60),
  medium(maxSize: 500, quality: 75),
  high(maxSize: 1000, quality: 85),
  original(maxSize: null, quality: 95);

  const ImageQuality({required this.maxSize, required this.quality});
  
  final int? maxSize;
  final int quality;
}

class SmartImageLoader {
  /// Get optimal image quality based on network speed
  static ImageQuality getOptimalQuality({bool isSlowNetwork = false}) {
    // For now, use medium quality by default
    // In production, detect actual network speed
    if (isSlowNetwork) {
      return ImageQuality.low;
    }
    return ImageQuality.medium;
  }
  
  /// Get cache size for image type
  static int? getCacheSize(String imageType) {
    switch (imageType) {
      case 'thumbnail':
        return 150;
      case 'avatar':
        return 200;
      case 'profile':
        return 500;
      case 'post':
        return 800;
      default:
        return 500;
    }
  }
}
