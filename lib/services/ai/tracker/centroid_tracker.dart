import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/ai/detection_result.dart';

class TrackedPerson {
  final int id;
  Rect rect;
  String label;
  double confidence;
  int framesWithoutDetection;

  TrackedPerson({
    required this.id,
    required this.rect,
    required this.label,
    required this.confidence,
    this.framesWithoutDetection = 0,
  });
}

class CentroidTracker {
  /// Maximum normalized distance threshold to associate a detection with an existing track
  final double maxDistanceThreshold;
  
  /// Number of consecutive frames an object can be missing before we delete its track ID
  final int maxDisappearedFrames;
  
  int _nextTrackId = 1;
  final List<TrackedPerson> _trackedPeople = [];

  CentroidTracker({
    this.maxDistanceThreshold = 0.22,
    this.maxDisappearedFrames = 12,
  });

  /// Processes new detections and updates track IDs
  List<DetectionResult> track(List<DetectionResult> newDetections) {
    // 1. If tracking list is empty, register all incoming detections as new tracks
    if (_trackedPeople.isEmpty) {
      for (var det in newDetections) {
        final track = TrackedPerson(
          id: _nextTrackId++,
          rect: det.rect,
          label: det.label,
          confidence: det.confidence,
        );
        _trackedPeople.add(track);
        det.trackingId = track.id;
      }
      return newDetections;
    }

    // 2. Retrieve centroids of existing tracks
    final trackedCentroids = _trackedPeople.map((t) => _getCentroid(t.rect)).toList();
    
    // 3. Retrieve centroids of new detections
    final detectionCentroids = newDetections.map((d) => _getCentroid(d.rect)).toList();

    final List<bool> matchedDetections = List.filled(newDetections.length, false);
    final List<bool> matchedTracks = List.filled(_trackedPeople.length, false);

    // 4. Compute distance matrix and match tracks
    for (int tIdx = 0; tIdx < _trackedPeople.length; tIdx++) {
      double minDistance = double.maxFinite;
      int bestDetectionIdx = -1;

      for (int dIdx = 0; dIdx < newDetections.length; dIdx++) {
        if (matchedDetections[dIdx]) continue;
        
        final distance = _getDistance(trackedCentroids[tIdx], detectionCentroids[dIdx]);
        if (distance < minDistance) {
          minDistance = distance;
          bestDetectionIdx = dIdx;
        }
      }

      // If matched detection is within max distance threshold, pair it
      if (bestDetectionIdx != -1 && minDistance < maxDistanceThreshold) {
        _trackedPeople[tIdx].rect = newDetections[bestDetectionIdx].rect;
        _trackedPeople[tIdx].label = newDetections[bestDetectionIdx].label;
        _trackedPeople[tIdx].confidence = newDetections[bestDetectionIdx].confidence;
        _trackedPeople[tIdx].framesWithoutDetection = 0;
        
        newDetections[bestDetectionIdx].trackingId = _trackedPeople[tIdx].id;
        
        matchedDetections[bestDetectionIdx] = true;
        matchedTracks[tIdx] = true;
      }
    }

    // 5. Update state of unmatched tracks (objects that disappeared in this frame)
    for (int tIdx = 0; tIdx < _trackedPeople.length; tIdx++) {
      if (!matchedTracks[tIdx]) {
        _trackedPeople[tIdx].framesWithoutDetection++;
      }
    }

    // Remove tracks that have been missing for longer than maxDisappearedFrames
    _trackedPeople.removeWhere((t) => t.framesWithoutDetection > maxDisappearedFrames);

    // 6. Register unmatched detections as new tracks
    for (int dIdx = 0; dIdx < newDetections.length; dIdx++) {
      if (!matchedDetections[dIdx]) {
        final track = TrackedPerson(
          id: _nextTrackId++,
          rect: newDetections[dIdx].rect,
          label: newDetections[dIdx].label,
          confidence: newDetections[dIdx].confidence,
        );
        _trackedPeople.add(track);
        newDetections[dIdx].trackingId = track.id;
      }
    }

    // 7. Align output collection with corresponding tracks
    final List<DetectionResult> results = [];
    for (var det in newDetections) {
      if (det.trackingId != -1) {
        results.add(det);
      }
    }
    return results;
  }

  Offset _getCentroid(Rect rect) {
    return Offset(rect.left + rect.width / 2, rect.top + rect.height / 2);
  }

  double _getDistance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return sqrt(dx * dx + dy * dy);
  }
}
