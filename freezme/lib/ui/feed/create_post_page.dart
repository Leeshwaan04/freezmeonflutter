import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/photo_upload_service.dart';
import '../../main.dart';
import '../theme.dart';

/// Page for creating a new feed post with photos and caption
class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _captionController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<File> _selectedImages = [];
  final int _maxImages = 10;
  final int _maxCaptionLength = 500;
  
  String _visibility = 'public'; // 'public' or 'connections'
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_selectedImages.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $_maxImages photos allowed')),
      );
      return;
    }

    try {
      final images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      final remainingSlots = _maxImages - _selectedImages.length;
      final imagesToAdd = images.take(remainingSlots).map((xFile) => File(xFile.path)).toList();

      setState(() {
        _selectedImages.addAll(imagesToAdd);
      });

      if (images.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Only $remainingSlots more photos could be added')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _createPost() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo')),
      );
      return;
    }

    if (_captionController.text.trim().length > _maxCaptionLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Caption too long (max $_maxCaptionLength characters)')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final flow = AppFlowScope.of(context, listen: false);
      final uploadService = FirebasePhotoUploadService();

      // Upload all images
      final photoUrls = <String>[];
      for (int i = 0; i < _selectedImages.length; i++) {
        final url = await uploadService.uploadPhoto(
          _selectedImages[i],
          userId: FirebaseAuth.instance.currentUser!.uid,
          photoIndex: i,
        );
        photoUrls.add(url);
        
        // Show progress
        if (mounted) {
          setState(() {}); // Trigger rebuild to show progress
        }
      }

      // Create post
      await flow.repository.createPost(
        photoUrls: photoUrls,
        caption: _captionController.text.trim().isEmpty 
            ? null 
            : _captionController.text.trim(),
        visibility: _visibility,
      );

      if (!mounted) return;

      // Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Post created successfully!'),
            ],
          ),
          backgroundColor: FreezmeColors.success,
        ),
      );

      // Go back
      flow.pop();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating post: $e'),
          backgroundColor: FreezmeColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _captionController.text.length;
    final charColor = charCount > _maxCaptionLength * 0.9
        ? FreezmeColors.error
        : FreezmeColors.textMuted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: FreezmeColors.background,
        foregroundColor: FreezmeColors.text,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isUploading ? null : () => AppFlowScope.of(context, listen: false).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading || _selectedImages.isEmpty ? null : _createPost,
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photos grid
                  if (_selectedImages.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImages[index],
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  
                  // Add photos button
                  if (_selectedImages.length < _maxImages)
                    Padding(
                      padding: EdgeInsets.only(top: _selectedImages.isEmpty ? 0 : 16),
                      child: OutlinedButton.icon(
                        onPressed: _isUploading ? null : _pickImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: Text(_selectedImages.isEmpty ? 'Add Photos' : 'Add More'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),

                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    
                    // Caption
                    TextField(
                      controller: _captionController,
                      decoration: InputDecoration(
                        hintText: 'Write a caption...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixText: '$charCount/$_maxCaptionLength',
                        suffixStyle: TextStyle(color: charColor, fontSize: 12),
                      ),
                      maxLines: 5,
                      maxLength: _maxCaptionLength,
                      enabled: !_isUploading,
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 24),

                    // Visibility selector
                    const Text('Visibility', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Public'),
                            subtitle: const Text('Everyone can see'),
                            value: 'public',
                            groupValue: _visibility,
                            onChanged: _isUploading ? null : (value) {
                              setState(() => _visibility = value!);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Connections'),
                            subtitle: const Text('Matches only'),
                            value: 'connections',
                            groupValue: _visibility,
                            onChanged: _isUploading ? null : (value) {
                              setState(() => _visibility = value!);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Upload progress
          if (_isUploading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FreezmeColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    'Uploading photos and creating post...',
                    style: TextStyle(color: FreezmeColors.textMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
