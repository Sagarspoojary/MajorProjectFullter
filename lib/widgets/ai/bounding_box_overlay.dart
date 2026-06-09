import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/ai/detection_result.dart';

class BoundingBoxOverlay extends StatelessWidget {
  final List<DetectionResult> detections;

  const BoundingBoxOverlay({super.key, required this.detections});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: BoundingBoxPainter(detections: detections),
        ),
      ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<DetectionResult> detections;

  BoundingBoxPainter({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    for (var det in detections) {
      // 1. Map normalized box coordinates [0.0 - 1.0] to canvas pixel dimensions
      final double left = det.rect.left * size.width;
      final double top = det.rect.top * size.height;
      final double width = det.rect.width * size.width;
      final double height = det.rect.height * size.height;
      
      final rect = Rect.fromLTWH(left, top, width, height);

      // Determine colors based on classified gender label
      final String labelLower = det.label.toLowerCase();
      final isFemale = labelLower == 'female';
      final isMale = labelLower == 'male';
      
      // Use neutral styling if still analyzing or unknown, and clear pink/purple once gender is determined
      final Color accentColor = isFemale 
          ? AppColors.softPink 
          : (isMale ? AppColors.neonViolet : Colors.grey);
      final Color tagBgColor = Colors.black.withValues(alpha: 0.75);

      // 2. Draw Translucent Box Overlay
      final boxFillPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.04)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, boxFillPaint);

      // 3. Draw Premium AI-HUD Corners (instead of standard box borders)
      final borderPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final double len = min(20.0, min(width, height) * 0.25); // corner indicator length

      // Top-Left corner brackets
      canvas.drawLine(rect.topLeft, Offset(rect.left + len, rect.top), borderPaint);
      canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + len), borderPaint);

      // Top-Right corner brackets
      canvas.drawLine(rect.topRight, Offset(rect.right - len, rect.top), borderPaint);
      canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + len), borderPaint);

      // Bottom-Left corner brackets
      canvas.drawLine(rect.bottomLeft, Offset(rect.left + len, rect.bottom), borderPaint);
      canvas.drawLine(rect.bottomLeft, Offset(rect.left, rect.bottom - len), borderPaint);

      // Bottom-Right corner brackets
      canvas.drawLine(rect.bottomRight, Offset(rect.right - len, rect.bottom), borderPaint);
      canvas.drawLine(rect.bottomRight, Offset(rect.right, rect.bottom - len), borderPaint);

      // 4. Draw Tag Label Tag Background
      final String text = (labelLower == 'analyzing...' || labelLower == 'unknown')
          ? det.label
          : '${det.label} (${(det.confidence * 100).toInt()}%)';
      
      final textSpan = TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              offset: const Offset(0.8, 0.8),
              blurRadius: 2.0,
            ),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // Position the label tag slightly above the bounding box
      final double tagWidth = textPainter.width + 12.0;
      final double tagHeight = textPainter.height + 6.0;
      
      final double tagLeft = rect.left;
      final double tagTop = (rect.top - tagHeight) > 0 ? (rect.top - tagHeight) : rect.top;

      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tagLeft, tagTop, tagWidth, tagHeight),
        const Radius.circular(6.0),
      );

      // Draw tag background
      final tagPaint = Paint()
        ..color = tagBgColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(tagRect, tagPaint);

      // Draw tag border line (subtle left edge indicator)
      final tagEdgePaint = Paint()
        ..color = accentColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(tagLeft + 1.0, tagTop + 2.0),
        Offset(tagLeft + 1.0, tagTop + tagHeight - 2.0),
        tagEdgePaint,
      );

      // 5. Draw text inside tag label
      textPainter.paint(
        canvas,
        Offset(tagLeft + 8.0, tagTop + 3.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
