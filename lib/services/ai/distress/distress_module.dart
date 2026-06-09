import '../../../models/ai/detection_result.dart';

abstract class DistressDetector {
  /// Analyzes the coordinates, profiles, and tracks of people
  /// to flag a distress event (returns true if distress is detected).
  Future<bool> analyzeDistress(List<DetectionResult> trackedPeople);
}

class FutureDistressDetectorImpl implements DistressDetector {
  @override
  Future<bool> analyzeDistress(List<DetectionResult> trackedPeople) async {
    // Placeholder distress detection.
    // Future integrations will implement keypoint/pose analysis (e.g. falls, struggles, raised hands),
    // facial emotion models, or temporal anomaly classifiers on the tracked IDs.
    return false;
  }
}
