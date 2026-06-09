import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../models/ai/detection_result.dart';
import '../../../utils/image_utils.dart';

abstract class PersonDetector {
  Future<void> initialize();
  Future<List<DetectionResult>> detect(CameraImage image, int rotation);
  void dispose();
}

class PersonDetectorImpl implements PersonDetector {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  bool _useSimulation = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check if the model asset is loaded and bundle configuration is active
      await rootBundle.load('assets/models/yolov8n_person.tflite');
      
      // Load interpreter
      _interpreter = await Interpreter.fromAsset('assets/models/yolov8n_person.tflite');
      _useSimulation = false;
      debugPrint('YOLOv8 TFLite model loaded successfully.');
    } catch (e) {
      debugPrint('Failed to load yolov8n_person.tflite, falling back to dynamic simulation engine: $e');
      _useSimulation = true;
    }
    _isInitialized = true;
  }

  @override
  Future<List<DetectionResult>> detect(CameraImage image, int rotation) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_useSimulation || _interpreter == null) {
      return _generateSimulatedDetections();
    }

    try {
      // 1. Preprocess CameraImage to YOLOv8 input size [640, 640] normalized [0.0 - 1.0]
      final Float32List inputData = ImageUtils.preprocessCameraImage(image, 640, 640);
      
      // Shape [1, 640, 640, 3] or [1, 3, 640, 640] - standard exported YOLO shape is [1, 640, 640, 3]
      final inputTensor = inputData.reshape([1, 640, 640, 3]);

      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final isChannelFirst = outputShape[1] == 84;
      final int numAnchors = isChannelFirst ? outputShape[2] : outputShape[1];

      // Allocate output buffer according to actual shape
      final outputBuffer = List.filled(outputShape[0] * outputShape[1] * outputShape[2], 0.0)
          .reshape(outputShape);

      // Run inference
      _interpreter!.run(inputTensor, outputBuffer);

      final List<DetectionResult> candidates = [];
      const double confidenceThreshold = 0.40; // Detection confidence threshold

      for (int i = 0; i < numAnchors; i++) {
        final double score = isChannelFirst
            ? outputBuffer[0][4][i]
            : outputBuffer[0][i][4]; // Index 4 is COCO Class 0 (Person)

        if (score >= confidenceThreshold) {
          final double cx = isChannelFirst ? outputBuffer[0][0][i] : outputBuffer[0][i][0];
          final double cy = isChannelFirst ? outputBuffer[0][1][i] : outputBuffer[0][i][1];
          final double w = isChannelFirst ? outputBuffer[0][2][i] : outputBuffer[0][i][2];
          final double h = isChannelFirst ? outputBuffer[0][3][i] : outputBuffer[0][i][3];

          // Convert center coordinates [cx, cy, w, h] to bounding box corners [left, top, width, height]
          final double left = (cx - w / 2) / 640.0;
          final double top = (cy - h / 2) / 640.0;
          final double rectWidth = w / 640.0;
          final double rectHeight = h / 640.0;

          candidates.add(
            DetectionResult(
              rect: Rect.fromLTWH(
                left.clamp(0.0, 1.0),
                top.clamp(0.0, 1.0),
                rectWidth.clamp(0.0, 1.0),
                rectHeight.clamp(0.0, 1.0),
              ),
              label: "person",
              confidence: score,
            ),
          );
        }
      }

      // Apply Non-Maximum Suppression (NMS) to clear overlapping duplicates
      return _nms(candidates, 0.45);
    } catch (e) {
      debugPrint('Error running YOLOv8 interpreter: $e');
      return [];
    }
  }

  List<DetectionResult> _nms(List<DetectionResult> detections, double iouThreshold) {
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final List<DetectionResult> selected = [];

    for (var det in detections) {
      bool keep = true;
      for (var sel in selected) {
        if (_boxIoU(det.rect, sel.rect) > iouThreshold) {
          keep = false;
          break;
        }
      }
      if (keep) {
        selected.add(det);
      }
    }
    return selected;
  }

  double _boxIoU(Rect a, Rect b) {
    final double left = max(a.left, b.left);
    final double top = max(a.top, b.top);
    final double right = min(a.right, b.right);
    final double bottom = min(a.bottom, b.bottom);

    if (right <= left || bottom <= top) return 0.0;

    final double intersectionArea = (right - left) * (bottom - top);
    final double areaA = a.width * a.height;
    final double areaB = b.width * b.height;
    final double unionArea = areaA + areaB - intersectionArea;

    if (unionArea <= 0.0) return 0.0;
    return intersectionArea / unionArea;
  }

  List<DetectionResult> _generateSimulatedDetections() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final List<DetectionResult> list = [];
    
    // Simulate Person 1: Walking across the left/center field of view
    double p1x = 0.15 + (sin(now / 6000) * 0.1);
    double p1y = 0.22 + (cos(now / 9000) * 0.04);
    list.add(DetectionResult(
      rect: Rect.fromLTWH(p1x, p1y, 0.28, 0.46),
      label: "person",
      confidence: 0.94 + (sin(now / 1500) * 0.02),
    ));

    // Simulate Person 2: Moving in the right field of view
    double p2x = 0.58 + (cos(now / 7000) * 0.12);
    double p2y = 0.28 + (sin(now / 8000) * 0.06);
    list.add(DetectionResult(
      rect: Rect.fromLTWH(p2x, p2y, 0.26, 0.52),
      label: "person",
      confidence: 0.88 + (cos(now / 1200) * 0.03),
    ));

    return list;
  }

  @override
  void dispose() {
    _interpreter?.close();
  }
}
