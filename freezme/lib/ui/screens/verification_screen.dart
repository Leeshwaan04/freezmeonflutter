import 'dart:io';
import 'package:dio/dio.dart' as dio_options;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../services/api_client.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  bool _isCapturing = false;
  bool _isComplete = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _startVerification() async {
    setState(() {
      _errorMessage = null;
    });

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null || !mounted) return;

    setState(() => _isCapturing = true);

    try {
      // Step 1: get presigned S3 URL
      final urlResp = await ApiClient.instance.dio.post<Map<String, dynamic>>(
        '/verification/selfie-url',
      );
      final uploadUrl = urlResp.data!['uploadUrl'] as String;
      final selfieKey = urlResp.data!['selfieKey'] as String;

      // Step 2: PUT selfie directly to S3
      final bytes = await File(picked.path).readAsBytes();
      await ApiClient.instance.dio.put<void>(
        uploadUrl,
        data: bytes,
        options: dio_options.Options(
          headers: {'Content-Type': 'image/jpeg'},
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      // Step 3: submit selfieKey to backend → marks verification_pending
      await ApiClient.instance.dio.post<void>(
        '/verification/selfie-submit',
        data: {'selfieKey': selfieKey},
      );

      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isComplete = true;
        });
      }
    } catch (e) {
      debugPrint('[Verification] selfie upload error: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _errorMessage = 'Upload failed — please try again';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Solid dark background
          Positioned.fill(
            child: Container(color: const Color(0xFF0A0518)),
          ),

          // Scanning Overlay
          if (_isCapturing)
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return Positioned(
                  top: MediaQuery.of(context).size.height * 0.2 +
                      (MediaQuery.of(context).size.height * 0.6 *
                          _scanController.value),
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: FreezmeColors.primary.withValues(alpha: 0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    'Vibe Check',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isComplete
                        ? 'Selfie submitted for review!'
                        : _isCapturing
                            ? 'Uploading securely…'
                            : 'Take a selfie to verify you\'re a real person',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  if (!_isComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield,
                              color: Colors.blueAccent, size: 16),
                          SizedBox(width: 8),
                          Text(
                            '+50 TRUST SCORE',
                            style: TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Verification Frame
                  Center(
                    child: Container(
                      width: 280,
                      height: 380,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isComplete ? Colors.green : Colors.white24,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(140),
                      ),
                      child: _isComplete
                          ? const Center(
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 80,
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.white.withValues(alpha: 0.3),
                                size: 64,
                              ),
                            ),
                    ),
                  ),

                  const Spacer(),

                  if (!_isCapturing && !_isComplete)
                    ElevatedButton(
                      onPressed: _startVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FreezmeColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Capture Selfie'),
                    ),

                  if (_isCapturing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: CircularProgressIndicator(
                          color: Colors.white),
                    ),

                  if (_isComplete)
                    ElevatedButton(
                      onPressed: flow.completeVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Continue'),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Back button
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
