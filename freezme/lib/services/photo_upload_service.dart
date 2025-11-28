import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class UploadedPhoto {
  const UploadedPhoto({required this.url, this.localPath});

  final String url;
  final String? localPath;
}

abstract class PhotoUploadService {
  Future<UploadedPhoto> pickAndUpload({required int slotIndex});
}

class PhotoUploadException implements Exception {
  const PhotoUploadException(this.message);

  final String message;

  @override
  String toString() => 'PhotoUploadException: $message';
}

class FirebasePhotoUploadService implements PhotoUploadService {
  FirebasePhotoUploadService({
    ImagePicker? picker,
    FirebaseStorage? storage,
    Uuid? uuid,
  }) : _picker = picker ?? ImagePicker(),
       _storage = storage ?? FirebaseStorage.instance,
       _uuid = uuid ?? const Uuid();

  final ImagePicker _picker;
  final FirebaseStorage _storage;
  final Uuid _uuid;

  @override
  Future<UploadedPhoto> pickAndUpload({required int slotIndex}) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) {
        throw const PhotoUploadException('picker_cancelled');
      }
      final file = File(picked.path);
      final fileName = 'onboarding/${_uuid.v4()}';
      final ref = _storage.ref(fileName);
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      return UploadedPhoto(url: downloadUrl, localPath: picked.path);
    } on FirebaseException catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Firebase upload failed: ${error.code} ${error.message}\n$stackTrace',
        );
      }
      throw PhotoUploadException('storage_${error.code ?? 'unknown'}');
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Photo upload failed: $error\n$stackTrace');
      }
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
  Future<UploadedPhoto> pickAndUpload({required int slotIndex}) async {
    await Future<void>.delayed(delay);
    final url = _demoUrls[_index % _demoUrls.length];
    _index++;
    return UploadedPhoto(url: url);
  }
}
