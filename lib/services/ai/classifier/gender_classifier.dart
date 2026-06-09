import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../detector/face_detector.dart';
import '../detector/pose_detector.dart';
import '../fusion/prediction_fusion_engine.dart';
import 'body_gender_classifier.dart';
import 'face_gender_classifier.dart';

class GenderClassificationResult {
  final String label;
  final double confidence;

  GenderClassificationResult({
    required this.label,
    required this.confidence,
  });
}

abstract class GenderClassifier {
  Future<void> initialize();
  Future<GenderClassificationResult> classify(CameraImage image, Rect rect, int trackingId);
  void prune(List<int> activeIds);
  void dispose();
}

class _GenderHistory {
  final List<String> labels = [];
  final List<double> confidences = [];
  String? lockedLabel;
  int consecutiveLowConfidenceFrames = 0;

  void add(String label, double confidence, int maxBufferSize) {
    labels.add(label);
    confidences.add(confidence);
    if (labels.length > maxBufferSize) {
      labels.removeAt(0);
      confidences.removeAt(0);
    }
  }
}

class GenderClassifierImpl implements GenderClassifier {
  final RetinaFaceDetector _faceDetector;
  final FaceGenderClassifier _faceGenderClassifier;
  final EfficientNetBodyClassifier _bodyClassifier;
  final MediaPipePoseDetector _poseDetector;
  final PredictionFusionEngine _fusionEngine;

  bool _isInitialized = false;
  
  // Cache histories for each tracking ID to maintain temporal consistency
  final Map<int, _GenderHistory> _historyMap = {};
  
  // Configurations for the stability filter
  static const int maxBufferSize = 25;            // Max prediction history buffer size (approx. 1-2 seconds of feed)
  static const int minFramesRequired = 12;          // Warm-up period before making any classification decision
  static const double highConfidenceThreshold = 0.95; // Display only when majority confidence is above 95%
  static const double unlockThreshold = 0.78;         // Hysteresis threshold to drop the lock if classification degrades
  static const int unlockRequiredFrames = 30;       // Consecutive low confidence frames required to unlock

  GenderClassifierImpl({
    RetinaFaceDetector? faceDetector,
    FaceGenderClassifier? faceGenderClassifier,
    EfficientNetBodyClassifier? bodyClassifier,
    MediaPipePoseDetector? poseDetector,
    PredictionFusionEngine? fusionEngine,
  })  : _faceDetector = faceDetector ?? RetinaFaceDetectorImpl(),
        _faceGenderClassifier = faceGenderClassifier ?? FaceGenderClassifierImpl(),
        _bodyClassifier = bodyClassifier ?? EfficientNetBodyClassifierImpl(),
        _poseDetector = poseDetector ?? MediaPipePoseDetectorImpl(),
        _fusionEngine = fusionEngine ?? PredictionFusionEngine();

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _faceDetector.initialize();
    await _faceGenderClassifier.initialize();
    await _bodyClassifier.initialize();
    await _poseDetector.initialize();
    
    _isInitialized = true;
  }

  @override
  Future<GenderClassificationResult> classify(CameraImage image, Rect rect, int trackingId) async {
    if (!_isInitialized) {
      await initialize();
    }

    // 1. Detect face region inside the detected person crop using RetinaFace
    final Rect? faceRect = await _faceDetector.detectFace(image, rect);

    // 2. Obtain face model prediction if face is visible
    double? faceProb;
    if (faceRect != null) {
      faceProb = await _faceGenderClassifier.predictFemaleProbability(image, rect, faceRect, trackingId);
    }

    // 3. Obtain body prediction using EfficientNet-B4
    final double bodyProb = await _bodyClassifier.predictFemaleProbability(image, rect, trackingId);

    // 4. Obtain pose metrics prediction using MediaPipe Pose keypoints
    final double poseProb = await _poseDetector.predictFemaleProbability(image, rect, trackingId);

    // 5. Run prediction fusion engine to compute final probability score via weighted average
    final GenderClassificationResult fusedRawResult = _fusionEngine.fuse(
      faceProb: faceProb,
      bodyProb: bodyProb,
      poseProb: poseProb,
    );

    // 6. If the person is untracked (-1), skip filtering and return fused result directly
    if (trackingId == -1) {
      return fusedRawResult;
    }

    // 7. Insert fused prediction into tracking ID's history buffer
    final history = _historyMap.putIfAbsent(trackingId, () => _GenderHistory());
    history.add(fusedRawResult.label, fusedRawResult.confidence, maxBufferSize);

    // 8. Apply majority voting, confidence averaging, and hysteresis locking
    return _applyFilter(history);
  }

  GenderClassificationResult _applyFilter(_GenderHistory history) {
    // Warm-up phase: collect enough frame samples first
    if (history.labels.length < minFramesRequired) {
      return GenderClassificationResult(label: "Analyzing...", confidence: 0.0);
    }

    // Case A: Label is already locked
    if (history.lockedLabel != null) {
      int matchCount = 0;
      double matchConfSum = 0.0;
      
      for (int i = 0; i < history.labels.length; i++) {
        if (history.labels[i] == history.lockedLabel) {
          matchCount++;
          matchConfSum += history.confidences[i];
        }
      }

      double voteFraction = matchCount / history.labels.length;
      double avgConf = matchCount > 0 ? matchConfSum / matchCount : 0.0;

      // Hysteresis release: unlock only if vote share drops below 50% or confidence degrades severely
      if (voteFraction < 0.50 || avgConf < unlockThreshold) {
        history.consecutiveLowConfidenceFrames++;
        if (history.consecutiveLowConfidenceFrames >= unlockRequiredFrames) {
          history.lockedLabel = null; // unlock
          history.consecutiveLowConfidenceFrames = 0;
        }
      } else {
        history.consecutiveLowConfidenceFrames = 0;
      }

      if (history.lockedLabel != null) {
        // Locked: return locked label with averaged confidence (clamped to high display standards)
        return GenderClassificationResult(
          label: history.lockedLabel!,
          confidence: max(highConfidenceThreshold, avgConf),
        );
      }
    }

    // Case B: Calculate vote majorities
    int femaleCount = 0;
    int maleCount = 0;
    double femaleConfSum = 0.0;
    double maleConfSum = 0.0;

    for (int i = 0; i < history.labels.length; i++) {
      if (history.labels[i] == "Female") {
        femaleCount++;
        femaleConfSum += history.confidences[i];
      } else if (history.labels[i] == "Male") {
        maleCount++;
        maleConfSum += history.confidences[i];
      }
    }

    final String majorityLabel = femaleCount >= maleCount ? "Female" : "Male";
    final int majorityCount = majorityLabel == "Female" ? femaleCount : maleCount;
    final double majorityConfSum = majorityLabel == "Female" ? femaleConfSum : maleConfSum;
    
    final double voteFraction = majorityCount / history.labels.length;
    final double avgConf = majorityCount > 0 ? majorityConfSum / majorityCount : 0.0;

    // Lock condition: majority vote share >= 70% and average confidence >= 95%
    if (voteFraction >= 0.70 && avgConf >= highConfidenceThreshold) {
      history.lockedLabel = majorityLabel;
      history.consecutiveLowConfidenceFrames = 0;
      return GenderClassificationResult(label: majorityLabel, confidence: avgConf);
    }

    // If confidence or vote share is insufficient, report "Analyzing..."
    return GenderClassificationResult(label: "Analyzing...", confidence: avgConf);
  }

  @override
  void prune(List<int> activeIds) {
    // Delete historical buffers of tracking IDs no longer active to prevent memory bloat
    _historyMap.removeWhere((id, _) => !activeIds.contains(id));
  }

  @override
  void dispose() {
    _faceDetector.dispose();
    _faceGenderClassifier.dispose();
    _bodyClassifier.dispose();
    _poseDetector.dispose();
    _historyMap.clear();
  }
}
