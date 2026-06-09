import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';

class ImageUtils {
  /// Converts a [CameraImage] (YUV420 or BGRA8888) to a normalized Float32List of shape [targetWidth, targetHeight, 3].
  /// This performs scaling and colorspace conversion in a single pass to maximize performance.
  static Float32List preprocessCameraImage(
    CameraImage image,
    int targetWidth,
    int targetHeight,
  ) {
    final int width = image.width;
    final int height = image.height;
    
    // Output size: targetWidth * targetHeight * 3 channels
    final Float32List output = Float32List(targetWidth * targetHeight * 3);
    
    final double scaleX = width / targetWidth;
    final double scaleY = height / targetHeight;

    if (image.format.group == ImageFormatGroup.yuv420) {
      // YUV420 processing (typically Android)
      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      final Uint8List yBuffer = yPlane.bytes;
      final Uint8List uBuffer = uPlane.bytes;
      final Uint8List vBuffer = vPlane.bytes;

      final int yRowStride = yPlane.bytesPerRow;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

      int outIdx = 0;
      for (int yOut = 0; yOut < targetHeight; yOut++) {
        final int srcY = (yOut * scaleY).toInt().clamp(0, height - 1);
        for (int xOut = 0; xOut < targetWidth; xOut++) {
          final int srcX = (xOut * scaleX).toInt().clamp(0, width - 1);

          // Y value index
          final int yIdx = srcY * yRowStride + srcX;
          if (yIdx >= yBuffer.length) continue;
          final int y = yBuffer[yIdx];

          // U/V value indices (typically downsampled by 2 in YUV420)
          final int uvX = srcX >> 1;
          final int uvY = srcY >> 1;
          final int uvIdx = uvY * uvRowStride + uvX * uvPixelStride;

          if (uvIdx >= uBuffer.length || uvIdx >= vBuffer.length) continue;
          final int u = uBuffer[uvIdx];
          final int v = vBuffer[uvIdx];

          // Convert YUV to RGB
          // R = Y + 1.402 * (V - 128)
          // G = Y - 0.344136 * (U - 128) - 0.714136 * (V - 128)
          // B = Y + 1.772 * (U - 128)
          final int r = (y + 1.402 * (v - 128)).toInt().clamp(0, 255);
          final int g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).toInt().clamp(0, 255);
          final int b = (y + 1.772 * (u - 128)).toInt().clamp(0, 255);

          // Write to normalized float output [R, G, B]
          output[outIdx++] = r / 255.0;
          output[outIdx++] = g / 255.0;
          output[outIdx++] = b / 255.0;
        }
      }
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      // BGRA8888 processing (typically iOS)
      final Plane plane = image.planes[0];
      final Uint8List buffer = plane.bytes;
      final int rowStride = plane.bytesPerRow;
      final int pixelStride = plane.bytesPerPixel ?? 4;

      int outIdx = 0;
      for (int yOut = 0; yOut < targetHeight; yOut++) {
        final int srcY = (yOut * scaleY).toInt().clamp(0, height - 1);
        for (int xOut = 0; xOut < targetWidth; xOut++) {
          final int srcX = (xOut * scaleX).toInt().clamp(0, width - 1);

          final int idx = srcY * rowStride + srcX * pixelStride;
          if (idx + 2 >= buffer.length) continue;

          // BGRA format
          final int b = buffer[idx];
          final int g = buffer[idx + 1];
          final int r = buffer[idx + 2];

          output[outIdx++] = r / 255.0;
          output[outIdx++] = g / 255.0;
          output[outIdx++] = b / 255.0;
        }
      }
    }
    return output;
  }

  /// Converts a cropped region of a [CameraImage] (YUV420 or BGRA8888) to a normalized Float32List of shape [targetWidth, targetHeight, 3].
  /// This performs cropping, scaling, and colorspace conversion in a single pass to maximize performance.
  static Float32List preprocessCameraImageCrop(
    CameraImage image,
    Rect rect,
    int targetWidth,
    int targetHeight,
  ) {
    final int width = image.width;
    final int height = image.height;
    
    final double srcLeft = rect.left * width;
    final double srcTop = rect.top * height;
    final double srcWidth = rect.width * width;
    final double srcHeight = rect.height * height;

    final Float32List output = Float32List(targetWidth * targetHeight * 3);
    
    final double scaleX = srcWidth / targetWidth;
    final double scaleY = srcHeight / targetHeight;

    if (image.format.group == ImageFormatGroup.yuv420) {
      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      final Uint8List yBuffer = yPlane.bytes;
      final Uint8List uBuffer = uPlane.bytes;
      final Uint8List vBuffer = vPlane.bytes;

      final int yRowStride = yPlane.bytesPerRow;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

      int outIdx = 0;
      for (int yOut = 0; yOut < targetHeight; yOut++) {
        final int srcY = (srcTop + yOut * scaleY).toInt().clamp(0, height - 1);
        for (int xOut = 0; xOut < targetWidth; xOut++) {
          final int srcX = (srcLeft + xOut * scaleX).toInt().clamp(0, width - 1);

          final int yIdx = srcY * yRowStride + srcX;
          if (yIdx >= yBuffer.length) continue;
          final int y = yBuffer[yIdx];

          final int uvX = srcX >> 1;
          final int uvY = srcY >> 1;
          final int uvIdx = uvY * uvRowStride + uvX * uvPixelStride;

          if (uvIdx >= uBuffer.length || uvIdx >= vBuffer.length) continue;
          final int u = uBuffer[uvIdx];
          final int v = vBuffer[uvIdx];

          final int r = (y + 1.402 * (v - 128)).toInt().clamp(0, 255);
          final int g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).toInt().clamp(0, 255);
          final int b = (y + 1.772 * (u - 128)).toInt().clamp(0, 255);

          output[outIdx++] = r / 255.0;
          output[outIdx++] = g / 255.0;
          output[outIdx++] = b / 255.0;
        }
      }
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      final Plane plane = image.planes[0];
      final Uint8List buffer = plane.bytes;
      final int rowStride = plane.bytesPerRow;
      final int pixelStride = plane.bytesPerPixel ?? 4;

      int outIdx = 0;
      for (int yOut = 0; yOut < targetHeight; yOut++) {
        final int srcY = (srcTop + yOut * scaleY).toInt().clamp(0, height - 1);
        for (int xOut = 0; xOut < targetWidth; xOut++) {
          final int srcX = (srcLeft + xOut * scaleX).toInt().clamp(0, width - 1);

          final int idx = srcY * rowStride + srcX * pixelStride;
          if (idx + 2 >= buffer.length) continue;

          final int b = buffer[idx];
          final int g = buffer[idx + 1];
          final int r = buffer[idx + 2];

          output[outIdx++] = r / 255.0;
          output[outIdx++] = g / 255.0;
          output[outIdx++] = b / 255.0;
        }
      }
    }
    return output;
  }

  /// Converts a [CameraImage] (YUV420 or BGRA8888) to a downsampled raw Uint8List buffer (e.g. RGB format)
  /// and prepends an 8-byte header: [width (4-bytes), height (4-bytes)] as Big Endian 32-bit integers.
  static Uint8List convertToRawRGB(
    CameraImage image,
    int targetWidth,
    int targetHeight,
  ) {
    final int width = image.width;
    final int height = image.height;
    
    final int rgbSize = targetWidth * targetHeight * 3;
    final Uint8List output = Uint8List(8 + rgbSize);
    
    // Write 8-byte header
    final ByteData headerData = ByteData.sublistView(output, 0, 8);
    headerData.setInt32(0, targetWidth, Endian.big);
    headerData.setInt32(4, targetHeight, Endian.big);
    
    final double scaleX = width / targetWidth;
    final double scaleY = height / targetHeight;

    int outIdx = 8;
    if (image.format.group == ImageFormatGroup.yuv420) {
      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      final Uint8List yBuffer = yPlane.bytes;
      final Uint8List uBuffer = uPlane.bytes;
      final Uint8List vBuffer = vPlane.bytes;

      final int yRowStride = yPlane.bytesPerRow;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

      for (int yOut = 0; yOut < targetHeight; yOut++) {
        final int srcY = (yOut * scaleY).toInt().clamp(0, height - 1);
        for (int xOut = 0; xOut < targetWidth; xOut++) {
          final int srcX = (xOut * scaleX).toInt().clamp(0, width - 1);

          final int yIdx = srcY * yRowStride + srcX;
          if (yIdx >= yBuffer.length) {
            output[outIdx++] = 0;
            output[outIdx++] = 0;
            output[outIdx++] = 0;
            continue;
          }
          final int yVal = yBuffer[yIdx];

          final int uvX = srcX >> 1;
          final int uvY = srcY >> 1;
          final int uvIdx = uvY * uvRowStride + uvX * uvPixelStride;

          if (uvIdx >= uBuffer.length || uvIdx >= vBuffer.length) {
            output[outIdx++] = 0;
            output[outIdx++] = 0;
            output[outIdx++] = 0;
            continue;
          }
          final int uVal = uBuffer[uvIdx];
          final int vVal = vBuffer[uvIdx];

          final int r = (yVal + 1.402 * (vVal - 128)).toInt().clamp(0, 255);
          final int g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).toInt().clamp(0, 255);
          final int b = (yVal + 1.772 * (uVal - 128)).toInt().clamp(0, 255);

          output[outIdx++] = r;
          output[outIdx++] = g;
          output[outIdx++] = b;
        }
      }
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      final Plane plane = image.planes[0];
      final Uint8List buffer = plane.bytes;
      final int rowStride = plane.bytesPerRow;
      final int pixelStride = plane.bytesPerPixel ?? 4;

      for (int yOut = 0; yOut < targetHeight; yOut++) {
        final int srcY = (yOut * scaleY).toInt().clamp(0, height - 1);
        for (int xOut = 0; xOut < targetWidth; xOut++) {
          final int srcX = (xOut * scaleX).toInt().clamp(0, width - 1);

          final int idx = srcY * rowStride + srcX * pixelStride;
          if (idx + 2 >= buffer.length) {
            output[outIdx++] = 0;
            output[outIdx++] = 0;
            output[outIdx++] = 0;
            continue;
          }

          final int b = buffer[idx];
          final int g = buffer[idx + 1];
          final int r = buffer[idx + 2];

          output[outIdx++] = r;
          output[outIdx++] = g;
          output[outIdx++] = b;
        }
      }
    }
    return output;
  }
}
