import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants.dart';
import '../ai/gemini_service.dart';
import '../../../main.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  late GeminiService _geminiService;
  late FlutterTts _flutterTts;
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  bool _isProcessing = false;
  bool _isActive = false;
  String? _lastResponse;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService(AppConstants.geminiApiKey);

    _initTts();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _scanController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _scanController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _scanController.forward();
      }
    });

    _requestPermissionsAndInitCamera();
  }

  Future<void> _requestPermissionsAndInitCamera() async {
    await [Permission.camera, Permission.microphone].request();

    _initializeCamera();
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) return;

    final rearCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      rearCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  void _toggleSession() {
    setState(() {
      _isActive = !_isActive;
    });
    if (_isActive) {
      _flutterTts.speak("I am watching. Go ahead.");
      _scanController.forward();
      _processFrameLoop();
    } else {
      _flutterTts.speak("Session paused.");
      _scanController.stop();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processFrameLoop() async {
    if (!_isActive) return;
    await _processFrame();
    if (_isActive) {
      Future.delayed(const Duration(seconds: 10), _processFrameLoop);
    }
  }

  Future<void> _processFrame() async {
    if (_isProcessing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }

    try {
      final image = await _controller!.takePicture();
      final imageBytes = await image.readAsBytes();

      final response = await _geminiService.analyzeImage(
        imageBytes: imageBytes,
        prompt:
            "You are Athena, a real-time AI tutor. Look at this image. If you see a math problem, code, or study notes, briefly explain the next step or correct any visible mistake. If nothing is happening, say nothing. Keep it under 2 sentences. Speak directly to the student.",
      );

      if (response != null && response.isNotEmpty && mounted) {
        setState(() {
          _lastResponse = response;
        });
        await _flutterTts.speak(response);
      }
    } catch (e) {
      debugPrint("AI Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Layer
          Center(child: CameraPreview(_controller!)),

          // Scanning Line
          if (_isActive)
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Positioned(
                  top:
                      MediaQuery.of(context).size.height *
                          0.7 *
                          _scanAnimation.value +
                      100,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          // Thinking Indicator (Overlay)
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.cyanAccent,
                        ),
                        strokeWidth: 6,
                      ),
                      const SizedBox(height: 20),
                      Text(
                            "Athena is thinking...",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  blurRadius: 10.0,
                                  color: Colors.cyanAccent,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(duration: 1.seconds, color: Colors.white),
                    ],
                  ),
                ),
              ).animate().fade(duration: 300.ms),
            ),

          // AI Response Text Overlay
          if (_lastResponse != null)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child:
                  Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          _lastResponse!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                      .animate()
                      .fade(duration: 500.ms)
                      .slideY(begin: -0.2, end: 0, curve: Curves.easeOutBack),
            ),

          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton.large(
                      onPressed: _toggleSession,
                      backgroundColor: _isActive
                          ? Colors.redAccent
                          : Colors.blueAccent,
                      child: Icon(
                        _isActive ? Icons.stop : Icons.visibility,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _isActive ? "Athena is Watching..." : "Tap Eye to Start",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
