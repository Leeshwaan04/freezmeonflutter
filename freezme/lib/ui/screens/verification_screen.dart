import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  bool _isCapturing = false;
  bool _isComplete = false;

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

  void _startVerification() async {
    setState(() => _isCapturing = true);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _isCapturing = false;
        _isComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Simulated Camera View
          Positioned.fill(
            child: Opacity(
              opacity: 0.6,
              child: CachedNetworkImage(
                imageUrl: 'https://images.unsplash.com/photo-1546961329-78bef0414d7c?fit=crop&w=1080',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.black12),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          ),

          // Scanning Overlay
          if (_isCapturing)
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return Positioned(
                  top: MediaQuery.of(context).size.height * 0.2 + 
                       (MediaQuery.of(context).size.height * 0.6 * _scanController.value),
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
                      ? 'Verification Successful!' 
                      : 'Position your face in the frame',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  if (!_isComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield, color: Colors.blueAccent, size: 16),
                          SizedBox(width: 8),
                          Text(
                            '+50 TRUST SCORE',
                            style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  
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
                        : null,
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
                      child: const Text('Get My Verified Badge'),
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
