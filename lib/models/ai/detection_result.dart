import 'package:flutter/material.dart';

class DetectionResult {
  /// Bounding box normalized coordinates (values between 0.0 and 1.0)
  /// represents [left, top, right, bottom] relative to frame dimensions.
  final Rect rect;
  
  /// Gender label ("Male" or "Female")
  final String label;
  
  /// Detection confidence (0.0 to 1.0)
  final double confidence;
  
  /// Unique tracking ID (-1 if untracked)
  int trackingId;

  DetectionResult({
    required this.rect,
    required this.label,
    required this.confidence,
    this.trackingId = -1,
  });

  DetectionResult copyWith({
    Rect? rect,
    String? label,
    double? confidence,
    int? trackingId,
  }) {
    return DetectionResult(
      rect: rect ?? this.rect,
      label: label ?? this.label,
      confidence: confidence ?? this.confidence,
      trackingId: trackingId ?? this.trackingId,
    );
  }

  @override
  String toString() {
    return 'DetectionResult(ID: $trackingId, Label: $label, Conf: ${(confidence * 100).toStringAsFixed(1)}%, Rect: $rect)';
  }
}
