import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/ai/detection_result.dart';

class AiPipelineService {
  WebSocket? _webSocket;
  final StreamController<List<DetectionResult>> _detectionController = 
      StreamController<List<DetectionResult>>.broadcast();

  // Expose the stream of detection results for the UI to listen to
  Stream<List<DetectionResult>> get detectionStream => _detectionController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Establishes WebSocket connection to the Python AI backend
  Future<void> initialize() async {
    await connect();
  }

  /// Attempts connection to the AI Backend WebSocket server
  /// Attempts connection to the AI Backend WebSocket server
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      // Use host computer's actual local IP address for the physical device (V2050)
      const String serverUrl = 'ws://192.168.31.193:8000/ws';
      debugPrint('[WebSocket Client] Connecting to SHEGUARD AI Backend at $serverUrl...');
      
      _webSocket = await WebSocket.connect(serverUrl)
          .timeout(const Duration(seconds: 4));

      _isConnected = true;
      debugPrint('[WebSocket Client] Connected to SHEGUARD AI Backend WebSocket successfully.');

      _webSocket!.listen(
        (message) {
          final List<DetectionResult> results = _parseDetections(message);
          _detectionController.add(results);
        },
        onError: (error) {
          debugPrint('[WebSocket Client] SHEGUARD AI Backend WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[WebSocket Client] SHEGUARD AI Backend WebSocket connection closed by server.');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('[WebSocket Client] Failed to connect to AI Backend WebSocket: $e');
      debugPrint('[WebSocket Client] WARNING: If you are running on a physical device (e.g. V2050), ws://10.0.2.2:8000/ws will NOT work. You must replace 10.0.2.2 in ai_pipeline_service.dart with your machine\'s local IP address (e.g. ws://192.168.1.100:8000/ws) and verify both devices are on the same Wi-Fi network.');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _webSocket = null;
  }

  /// Sends a raw JPEG compressed frame to the Python backend over WebSocket
  void sendFrame(Uint8List jpegBytes) {
    if (_webSocket != null && _isConnected && _webSocket!.readyState == WebSocket.open) {
      try {
        debugPrint('[WebSocket Client] Sending binary frame payload (${jpegBytes.length} bytes)...');
        _webSocket!.add(jpegBytes);
      } catch (e) {
        debugPrint('[WebSocket Client] Error sending frame over WebSocket: $e');
      }
    } else {
      debugPrint('[WebSocket Client] Cannot send frame: WebSocket is not connected (readyState: ${_webSocket?.readyState}). Attempting reconnect.');
      connect();
    }
  }

  List<DetectionResult> _parseDetections(dynamic message) {
    debugPrint('[WebSocket Client] Raw message received from backend: $message');
    try {
      final List<dynamic> jsonList = jsonDecode(message.toString());
      final List<DetectionResult> results = jsonList.map((item) {
        final List<dynamic> rectList = item['rect'];
        final String label = item['label'];
        final double confidence = item['confidence'];

        return DetectionResult(
          rect: Rect.fromLTWH(
            rectList[0].toDouble(),
            rectList[1].toDouble(),
            rectList[2].toDouble(),
            rectList[3].toDouble(),
          ),
          label: label,
          confidence: confidence,
          trackingId: -1, // Tracking ID is backend-only and kept private from client
        );
      }).toList();
      debugPrint('[WebSocket Client] Successfully parsed ${results.length} detection results.');
      return results;
    } catch (e) {
      debugPrint('[WebSocket Client] Failed to parse detection results: $e');
      return [];
    }
  }

  /// Closes the connection and releases stream controllers
  void dispose() {
    _webSocket?.close();
    _detectionController.close();
  }
}
