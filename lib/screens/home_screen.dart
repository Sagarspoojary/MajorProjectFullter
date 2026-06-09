import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import '../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/loading_overlay.dart';
import 'splash_screen.dart'; // For CyberGridBackground

// AI imports
import '../models/ai/detection_result.dart';
import '../services/ai/ai_pipeline_service.dart';
import '../widgets/ai/bounding_box_overlay.dart';
import '../utils/image_utils.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _hasCameraError = false;

  // AI Pipeline variables
  final AiPipelineService _aiPipeline = AiPipelineService();
  StreamSubscription<List<DetectionResult>>? _detectionSubscription;
  List<DetectionResult> _detections = [];
  bool _isProcessingFrame = false;
  bool _isFrameInFlight = false;
  DateTime _lastFrameSentTime = DateTime.now();
  int _framesProcessedCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    
    // Drives the vertical HUD scanline sweeping animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  Future<void> _initializeCamera() async {
    debugPrint('[STAGE: Camera Initialization] Starting _initializeCamera...');
    try {
      // Initialize AI interpreters/engines
      debugPrint('[STAGE: Camera Initialization] Initializing AI pipeline WebSocket...');
      await _aiPipeline.initialize();
      debugPrint('[STAGE: Camera Initialization] AI pipeline connection method finished.');

      _detectionSubscription = _aiPipeline.detectionStream.listen((results) {
        debugPrint('[STAGE: UI Update] Received ${results.length} detection results from WebSocket.');
        _isFrameInFlight = false;
        if (mounted && _isCameraInitialized) {
          setState(() {
            _detections = results;
            _framesProcessedCount++;
          });
          debugPrint('[STAGE: UI Update] State updated via setState(). Total processed frames: $_framesProcessedCount. Detections rendered: ${results.length}');
        } else {
          debugPrint('[STAGE: UI Update] Stream callback fired but state NOT updated (mounted: $mounted, _isCameraInitialized: $_isCameraInitialized).');
        }
      });

      debugPrint('[STAGE: Camera Initialization] Retrieving available cameras...');
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('[STAGE: Camera Initialization] Failed: No cameras available on device.');
        if (mounted) {
          setState(() {
            _hasCameraError = true;
          });
        }
        return;
      }
      debugPrint('[STAGE: Camera Initialization] Found ${_cameras.length} cameras.');
      
      // Default to back camera if available, otherwise first camera index
      int defaultIndex = _cameras.indexWhere((cam) => cam.lensDirection == CameraLensDirection.back);
      if (defaultIndex == -1) {
        defaultIndex = 0;
      }
      _selectedCameraIndex = defaultIndex;

      debugPrint('[STAGE: Camera Initialization] Selecting camera index $_selectedCameraIndex: ${_cameras[_selectedCameraIndex].name}');
      await _startCamera(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('[STAGE: Camera Initialization] Critical Error during initialization: $e');
      if (mounted) {
        setState(() {
          _hasCameraError = true;
        });
      }
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    debugPrint('[STAGE: Camera Initialization] _startCamera called for camera: ${camera.name} (${camera.lensDirection})');
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        try {
          debugPrint('[STAGE: Camera Initialization] Stopping existing camera streaming...');
          await _cameraController!.stopImageStream();
        } catch (_) {}
      }
      debugPrint('[STAGE: Camera Initialization] Disposing existing camera controller...');
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      debugPrint('[STAGE: Camera Initialization] Initializing CameraController...');
      await _cameraController!.initialize();
      debugPrint('[STAGE: Camera Initialization] CameraController initialized successfully.');
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _hasCameraError = false;
        });
        debugPrint('[STAGE: Camera Initialization] Invoking _startImageStreaming...');
        _startImageStreaming();
      }
    } catch (e) {
      debugPrint('[STAGE: Camera Initialization] Error starting camera: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _hasCameraError = true;
        });
      }
    }
  }

  void _startImageStreaming() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      debugPrint('[STAGE: Frame Capture] Cannot start streaming: controller is null or not initialized.');
      return;
    }

    debugPrint('[STAGE: Frame Capture] _startImageStreaming registered successfully.');
    _cameraController!.startImageStream((CameraImage image) {
      final now = DateTime.now();
      if (_isFrameInFlight && now.difference(_lastFrameSentTime).inMilliseconds < 300) {
        // Log frame drop
        debugPrint('[STAGE: Frame Capture] Dropping camera frame to maintain backpressure (previous frame in flight).');
        return;
      }
      if (_isProcessingFrame || !mounted) return;
      _isProcessingFrame = true;

      try {
        _isFrameInFlight = true;
        _lastFrameSentTime = now;

        debugPrint('[STAGE: Frame Capture] Processing frame of dimensions ${image.width}x${image.height}.');
        // Convert to raw RGB bytes with 8-byte header prepended (480x360 resolution)
        final Uint8List rawBytes = ImageUtils.convertToRawRGB(image, 480, 360);
        
        debugPrint('[STAGE: Frame Capture] Frame successfully converted to raw RGB (${rawBytes.length} bytes including header). Streaming to backend...');
        _aiPipeline.sendFrame(rawBytes);
      } catch (e) {
        debugPrint('[STAGE: Frame Capture] Error converting/sending raw frame: $e');
        _isFrameInFlight = false;
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
      } catch (_) {}
    }

    setState(() {
      _isCameraInitialized = false;
      _detections = []; // Reset visual bounding boxes
    });

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _startCamera(_cameras[_selectedCameraIndex]);
  }

  @override
  void dispose() {
    _detectionSubscription?.cancel();
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      try {
        _cameraController!.stopImageStream();
      } catch (_) {}
    }
    _cameraController?.dispose();
    _animationController.dispose();
    _aiPipeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    
    // Listen to session terminations/logouts
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.user == null && previous?.user != null) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.neonPink,
          ),
        );
        ref.read(authNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: LoadingOverlay(
        isLoading: authState.isLoading,
        child: Stack(
          children: [
            // Full Screen Live Viewport & Bounding Box HUD layer
            Positioned.fill(
              child: _isCameraInitialized && _cameraController != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize?.height ?? 1080,
                            height: _cameraController!.value.previewSize?.width ?? 1920,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                        
                        // Draw HUD bounding boxes on top of the live camera view
                        BoundingBoxOverlay(detections: _detections),
                      ],
                    )
                  : Container(
                      color: AppColors.scaffoldBg,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonViolet),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'INITIALIZING SECURE VIDEO LENS...',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            
            // Camera Error Overlay
            if (_hasCameraError)
              Positioned.fill(
                child: Container(
                  color: AppColors.scaffoldBg,
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingL),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.videocam_off_rounded,
                          color: AppColors.neonPink,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'SECURE LENS ACCESS BLOCKED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please ensure camera permissions are enabled in your device settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
            // Ambient grid background (very subtle opacity) when camera is active
            if (_isCameraInitialized && !_hasCameraError)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.08,
                    child: const CyberGridBackground(),
                  ),
                ),
              ),

            // Test Debug Overlay Panel
            if (_isCameraInitialized && !_hasCameraError)
              Positioned(
                top: MediaQuery.of(context).padding.top + 80,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'DEBUG TEST HUD',
                        style: TextStyle(
                          color: AppColors.neonPink,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'YOLO Loaded: ${_aiPipeline.isConnected ? 'YES' : 'NO'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        'Frames Processed: $_framesProcessedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        'Persons Detected: ${_detections.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Animated scanning vertical sweep line
            if (_isCameraInitialized && !_hasCameraError)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Positioned(
                    top: MediaQuery.of(context).size.height * _animationController.value,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1.8,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonGreen.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1.5,
                          ),
                        ],
                        color: AppColors.neonGreen,
                      ),
                    ),
                  );
                },
              ),

            // Green overlay lens filter effect
            if (_isCameraInitialized && !_hasCameraError)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: AppColors.neonGreen.withValues(alpha: 0.02),
                  ),
                ),
              ),

            // Top Bar Overlay (Logout, App Title, REC Blinker)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12,
                  bottom: 16,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Deactivate Session / Log out button
                    GestureDetector(
                      onTap: () => ref.read(authNotifierProvider.notifier).signOut(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                        ),
                        child: const Icon(
                          Icons.power_settings_new_rounded,
                          color: AppColors.neonPink,
                          size: 20,
                        ),
                      ),
                    ),
                    
                    // Title HUD details
                    Column(
                      children: [
                        Text(
                          'SHEGUARD AI',
                          style: GoogleFonts.orbitron(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'LENS STATUS: ACTIVE SCAN',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppColors.neonGreen,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    
                    // Active REC status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              final isGlowing = _animationController.value % 0.4 < 0.2;
                              return Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isGlowing ? AppColors.neonPink : AppColors.neonPink.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'REC',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neonPink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Lens Controls Overlay
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Active Camera info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isCameraInitialized && _cameraController != null
                                ? 'CAMERA: ${_cameraController!.description.lensDirection.name.toUpperCase()}'
                                : 'CAMERA: INITIALIZING',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isCameraInitialized && _cameraController != null
                                ? 'RESOLUTION: ${_cameraController!.value.previewSize?.width.toInt()}x${_cameraController!.value.previewSize?.height.toInt()}'
                                : 'RESOLUTION: PENDING',
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Circular camera lens toggle button
                    GestureDetector(
                      onTap: _switchCamera,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple,
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.flip_camera_android_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
