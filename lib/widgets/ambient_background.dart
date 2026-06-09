import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

class AmbientBackground extends StatefulWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Deep obsidian solid base
        Positioned.fill(
          child: Container(
            color: AppColors.scaffoldBg,
          ),
        ),
        
        // Slow drifting radial gradient blobs
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final val = _controller.value * 2 * pi;
            
            // Generate circular orbit coordinate factors
            final x1 = sin(val) * 0.45 + 0.5;
            final y1 = cos(val) * 0.35 + 0.5;
            
            final x2 = cos(val + pi / 2) * 0.35 + 0.5;
            final y2 = sin(val + pi / 2) * 0.45 + 0.5;

            return Stack(
              children: [
                // Glowing Violet Blob
                Align(
                  alignment: Alignment(x1 * 2 - 1, y1 * 2 - 1),
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primaryPurple.withValues(alpha: 0.3),
                          AppColors.primaryPurple.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Glowing Soft Pink/Neon Pink Blob
                Align(
                  alignment: Alignment(x2 * 2 - 1, y2 * 2 - 1),
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.softPink.withValues(alpha: 0.2),
                          AppColors.softPink.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // Cyber Grid Lines overlay for modern tech aesthetic
        Positioned.fill(
          child: Opacity(
            opacity: 0.15,
            child: CustomPaint(
              painter: GridPainter(
                color: Colors.white.withValues(alpha: 0.05),
                gridSize: 30.0,
              ),
            ),
          ),
        ),

        // Frosted glass BackdropFilter to diffuse the blobs into liquid gradients
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),

        // Actual layout content
        Positioned.fill(
          child: widget.child,
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  final double gridSize;

  GridPainter({required this.color, required this.gridSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;

    // Draw vertical mesh grid lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Draw horizontal mesh grid lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// A timed staggered entrance slide-and-fade animation wrapper
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;

  const FadeInSlide({
    super.key,
    required this.child,
    required this.index,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Apply staggered entry delay based on item index position
    final delay = Duration(milliseconds: 90 * widget.index);
    _timer = Timer(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: FractionalTranslation(
            translation: _slideAnimation.value,
            child: widget.child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
