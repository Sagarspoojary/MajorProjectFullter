import '../classifier/gender_classifier.dart';

class PredictionFusionEngine {
  // Configurable weights when all models are active
  final double faceWeight;
  final double bodyWeight;
  final double poseWeight;

  PredictionFusionEngine({
    this.faceWeight = 0.50,
    this.bodyWeight = 0.30,
    this.poseWeight = 0.20,
  });

  /// Fuses predictions from Face, Body, and Pose classifiers using weighted averaging.
  /// If the face is not visible, redistributes weights between Body and Pose.
  GenderClassificationResult fuse({
    required double? faceProb, // Null if face is not detected
    required double bodyProb,
    required double poseProb,
  }) {
    double finalFemaleProbability = 0.5;

    if (faceProb != null) {
      // 1. Face model is visible: Use standard weights (Face: 50%, Body: 30%, Pose: 20%)
      finalFemaleProbability = (faceProb * faceWeight) + (bodyProb * bodyWeight) + (poseProb * poseWeight);
    } else {
      // 2. Face model is NOT visible: Redistribute weights between Body (60%) and Pose (40%)
      const double redistributedBodyWeight = 0.60;
      const double redistributedPoseWeight = 0.40;
      finalFemaleProbability = (bodyProb * redistributedBodyWeight) + (poseProb * redistributedPoseWeight);
    }

    // 3. Map final probability to Male/Female and calculate classification confidence
    String label;
    double confidence;

    if (finalFemaleProbability >= 0.50) {
      label = "Female";
      confidence = finalFemaleProbability;
    } else {
      label = "Male";
      confidence = 1.0 - finalFemaleProbability;
    }

    return GenderClassificationResult(
      label: label,
      confidence: confidence,
    );
  }
}
