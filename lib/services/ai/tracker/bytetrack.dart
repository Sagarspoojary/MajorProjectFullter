import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/ai/detection_result.dart';

class ByteTracklet {
  final int id;
  Rect rect;
  double score;
  int missingFrames;

  ByteTracklet({
    required this.id,
    required this.rect,
    required this.score,
    this.missingFrames = 0,
  });
}

class _MatchCandidate {
  final int tIdx;
  final int dIdx;
  final double cost;

  _MatchCandidate({
    required this.tIdx,
    required this.dIdx,
    required this.cost,
  });
}

class ByteTracker {
  final double trackThreshold;     // Threshold to initiate/continue a track (default 0.5)
  final double highThreshold;      // Detections above this are high-score (default 0.6)
  final double matchThreshold;     // Minimum IoU to associate detection with track (default 0.2)
  final int maxMissingFrames;      // Frames to keep a missing track before deleting it (default 30)

  int _nextTrackId = 1;
  final List<ByteTracklet> _trackedPeople = [];

  ByteTracker({
    this.trackThreshold = 0.50,
    this.highThreshold = 0.60,
    this.matchThreshold = 0.20,
    this.maxMissingFrames = 30,
  });

  /// Tracks person detections across frames using the ByteTrack algorithm.
  List<DetectionResult> track(List<DetectionResult> newDetections) {
    // 1. Separate detections into high-score and low-score classes
    final List<DetectionResult> highDetections = [];
    final List<DetectionResult> lowDetections = [];

    for (var det in newDetections) {
      if (det.confidence >= highThreshold) {
        highDetections.add(det);
      } else if (det.confidence >= 0.15) { // Minimum threshold to consider detection at all
        lowDetections.add(det);
      }
    }

    // List to keep track of associations
    final List<bool> matchedHighDetections = List.filled(highDetections.length, false);
    final List<bool> matchedTracks = List.filled(_trackedPeople.length, false);

    // 2. First association: Match high-score detections with existing tracks
    final List<_MatchCandidate> highCandidates = [];
    for (int tIdx = 0; tIdx < _trackedPeople.length; tIdx++) {
      for (int dIdx = 0; dIdx < highDetections.length; dIdx++) {
        final double iou = _getIoU(_trackedPeople[tIdx].rect, highDetections[dIdx].rect);
        if (iou > matchThreshold) {
          highCandidates.add(_MatchCandidate(tIdx: tIdx, dIdx: dIdx, cost: 1.0 - iou));
        }
      }
    }
    
    // Greedy matching based on lowest cost (highest IoU)
    highCandidates.sort((a, b) => a.cost.compareTo(b.cost));
    for (var candidate in highCandidates) {
      if (matchedTracks[candidate.tIdx] || matchedHighDetections[candidate.dIdx]) continue;
      
      matchedTracks[candidate.tIdx] = true;
      matchedHighDetections[candidate.dIdx] = true;

      // Update track attributes
      _trackedPeople[candidate.tIdx].rect = highDetections[candidate.dIdx].rect;
      _trackedPeople[candidate.tIdx].score = highDetections[candidate.dIdx].confidence;
      _trackedPeople[candidate.tIdx].missingFrames = 0;

      highDetections[candidate.dIdx].trackingId = _trackedPeople[candidate.tIdx].id;
    }

    // 3. Second association: Match unmatched tracks with low-score detections
    final List<bool> matchedLowDetections = List.filled(lowDetections.length, false);
    final List<_MatchCandidate> lowCandidates = [];
    for (int tIdx = 0; tIdx < _trackedPeople.length; tIdx++) {
      if (matchedTracks[tIdx]) continue;
      for (int dIdx = 0; dIdx < lowDetections.length; dIdx++) {
        final double iou = _getIoU(_trackedPeople[tIdx].rect, lowDetections[dIdx].rect);
        if (iou > matchThreshold) {
          lowCandidates.add(_MatchCandidate(tIdx: tIdx, dIdx: dIdx, cost: 1.0 - iou));
        }
      }
    }

    lowCandidates.sort((a, b) => a.cost.compareTo(b.cost));
    for (var candidate in lowCandidates) {
      if (matchedTracks[candidate.tIdx] || matchedLowDetections[candidate.dIdx]) continue;

      matchedTracks[candidate.tIdx] = true;
      matchedLowDetections[candidate.dIdx] = true;

      // Update track attributes (recovered from occlusion/low detection confidence)
      _trackedPeople[candidate.tIdx].rect = lowDetections[candidate.dIdx].rect;
      _trackedPeople[candidate.tIdx].score = lowDetections[candidate.dIdx].confidence;
      _trackedPeople[candidate.tIdx].missingFrames = 0;

      lowDetections[candidate.dIdx].trackingId = _trackedPeople[candidate.tIdx].id;
    }

    // 4. Handle remaining unmatched tracks
    for (int tIdx = 0; tIdx < _trackedPeople.length; tIdx++) {
      if (!matchedTracks[tIdx]) {
        _trackedPeople[tIdx].missingFrames++;
      }
    }

    // Prune tracks that have been missing for too long
    _trackedPeople.removeWhere((track) => track.missingFrames > maxMissingFrames);

    // 5. Initialize new tracks from unmatched high-score detections
    final List<DetectionResult> activeResults = [];

    // Add successfully matched high detections
    for (int dIdx = 0; dIdx < highDetections.length; dIdx++) {
      if (matchedHighDetections[dIdx]) {
        activeResults.add(highDetections[dIdx]);
      } else {
        // Unmatched high-score detection: start a new tracklet
        final newTrack = ByteTracklet(
          id: _nextTrackId++,
          rect: highDetections[dIdx].rect,
          score: highDetections[dIdx].confidence,
        );
        _trackedPeople.add(newTrack);
        highDetections[dIdx].trackingId = newTrack.id;
        activeResults.add(highDetections[dIdx]);
      }
    }

    // Add successfully matched low detections (re-identified)
    for (int dIdx = 0; dIdx < lowDetections.length; dIdx++) {
      if (matchedLowDetections[dIdx]) {
        activeResults.add(lowDetections[dIdx]);
      }
    }

    return activeResults;
  }

  double _getIoU(Rect a, Rect b) {
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

  void reset() {
    _trackedPeople.clear();
    _nextTrackId = 1;
  }
}
