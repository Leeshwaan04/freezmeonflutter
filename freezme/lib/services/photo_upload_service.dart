import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';

class UploadedPhoto {
  const UploadedPhoto({required this.url, this.localPath});

  final String url;
  final String? localPath;
}

enum PhotoSource { gallery, camera }

abstract class PhotoUploadService {
  Future<UploadedPhoto> pickAndUpload({
    required int slotIndex,
    PhotoSource source = PhotoSource.gallery,
  });
  Future<String> uploadPhoto(File file,
      {required String userId, required int photoIndex});
}

class PhotoUploadException implements Exception {
  const PhotoUploadException(this.message);

  final String message;

  @override
  String toString() => 'PhotoUploadException: $message';
}

/// S3-backed implementation — replaces FirebasePhotoUploadService.
/// Flow:
///   1. GET /storage/upload-url  → { uploadUrl, publicUrl }
///   2. PUT uploadUrl with image bytes directly to S3 (no auth header)
///   3. Return publicUrl for saving in profile
class S3PhotoUploadService implements PhotoUploadService {
  S3PhotoUploadService({ImagePicker? picker, Uuid? uuid})
      : _picker = picker ?? ImagePicker(),
        _uuid = uuid ?? const Uuid();

  final ImagePicker _picker;
  final Uuid _uuid;
  final _apiClient = ApiClient.instance;
  // Separate Dio instance for S3 — no JWT interceptor
  final _s3Dio = Dio();

  @override
  Future<UploadedPhoto> pickAndUpload({
    required int slotIndex,
    PhotoSource source = PhotoSource.gallery,
  }) async {
    final picked = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) throw const PhotoUploadException('picker_cancelled');

    final file = File(picked.path);
    final publicUrl = await _uploadFile(file);
    return UploadedPhoto(url: publicUrl, localPath: picked.path);
  }

  @override
  Future<String> uploadPhoto(File file,
      {required String userId, required int photoIndex}) async {
    return _uploadFile(file);
  }

  Future<String> _uploadFile(File file) async {
    try {
      final filename = '${_uuid.v4()}.jpg';
      final bytes = await file.readAsBytes();

      if (bytes.length > 8 * 1024 * 1024) {
        throw const PhotoUploadException('File too large. Maximum size is 8 MB.');
      }

      // Step 1: get presigned URL from EC2
      final urlResp = await _apiClient.dio.get<Map<String, dynamic>>(
        '/storage/upload-url',
        queryParameters: {
          'filename': filename,
          'contentType': 'image/jpeg',
          'fileSize': bytes.length.toString(),
        },
      );

      final urlData = urlResp.data;
      final uploadUrl = urlData?['uploadUrl'] as String?;
      final s3Key = urlData?['key'] as String?;
      if (uploadUrl == null || s3Key == null) {
        throw const PhotoUploadException('upload_url_missing');
      }

      // Step 2: PUT directly to S3 presigned URL (no JWT header)
      await _s3Dio.put<void>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': 'image/jpeg',
            'Content-Length': bytes.length.toString(),
          },
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      // Step 3: confirm upload — server validates magic bytes and returns CDN URL
      final confirmResp = await _apiClient.dio.post<Map<String, dynamic>>(
        '/storage/confirm',
        data: {'key': s3Key},
      );
      final cdnUrl = confirmResp.data?['cdnUrl'] as String?;
      if (cdnUrl == null) throw const PhotoUploadException('cdn_url_missing');

      return cdnUrl;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('[S3Upload] failed: ${e.message}');
      throw PhotoUploadException('upload_failed: ${e.message}');
    } catch (e) {
      if (kDebugMode) debugPrint('[S3Upload] error: $e');
      if (e is PhotoUploadException) rethrow;
      throw const PhotoUploadException('upload_failed');
    }
  }
}

class MockPhotoUploadService implements PhotoUploadService {
  MockPhotoUploadService({
    List<String>? demoUrls,
    this.delay = const Duration(milliseconds: 250),
  }) : _demoUrls = demoUrls ?? _fallback;

  final List<String> _demoUrls;
  final Duration delay;
  int _index = 0;

  static const List<String> _fallback = <String>[
    'https://images.unsplash.com/photo-1546961329-78bef0414d7c?fit=crop&w=512',
    'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?fit=crop&w=512',
    'https://images.unsplash.com/photo-1591969851586-adbbd4accf81?fit=crop&w=512',
    'https://images.unsplash.com/photo-1504593811423-6dd665756598?fit=crop&w=512',
  ];

  @override
  Future<UploadedPhoto> pickAndUpload({
    required int slotIndex,
    PhotoSource source = PhotoSource.gallery,
  }) async {
    await Future<void>.delayed(delay);
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) {
        return UploadedPhoto(url: picked.path, localPath: picked.path);
      }
    } catch (_) {}
    final url = _demoUrls[_index % _demoUrls.length];
    _index++;
    return UploadedPhoto(url: url);
  }

  @override
  Future<String> uploadPhoto(File file,
      {required String userId, required int photoIndex}) async {
    await Future<void>.delayed(delay);
    final url = _demoUrls[_index % _demoUrls.length];
    _index++;
    return url;
  }
}
