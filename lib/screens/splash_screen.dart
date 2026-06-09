import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  bool _animationCompleted = false;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation controller
    _pulseController = AnimationController(
      vsync: this,
      duration: AppConstants.durationPulse,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _pulseController.repeat(reverse: true);

    // Minimum delay of 2.5 seconds to show visual branding
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _animationCompleted = true;
        });
        _checkAuthAndNavigate();
      }
    });
  }

  void _checkAuthAndNavigate() {
    if (!_animationCompleted) return;

    final authState = ref.read(authStateChangesProvider);
    if (!authState.isLoading) {
      final user = authState.value;
      if (user != null) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in authStateChangesProvider. If it resolves after the animation completes, navigate.
    ref.listen(authStateChangesProvider, (previous, next) {
      if (_animationCompleted && !next.isLoading) {
        final user = next.value;
        if (user != null) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBg,
          gradient: AppColors.darkGradient,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Cyber security background grids effect (drawn via custom widget or painter)
            const Positioned.fill(
              child: CyberGridBackground(),
            ),
            
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Security Ring & Shield Logo
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return ScaleTransition(
                      scale: _scaleAnimation,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulse ring outer 2
                          Container(
                            width: 180 * _pulseAnimation.value,
                            height: 180 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.neonViolet.withValues(alpha: 0.1),
                                width: 2,
                              ),
                            ),
                          ),
                          // Pulse ring outer 1
                          Container(
                            width: 140 * _pulseAnimation.value,
                            height: 140 * _pulseAnimation.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.softPink.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                            ),
                          ),
                          // Main glowing ring
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryPurple.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AppColors.neonViolet.withValues(alpha: 0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.neonViolet.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          // Custom Shield Painter
                          CustomPaint(
                            size: const Size(54, 64),
                            painter: ShieldPainter(
                              glowColor: AppColors.softPink,
                              primaryColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // App Title
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [Colors.white, AppColors.softPink],
                      ).createShader(const Rect.fromLTWH(0.0, 0.0, 300.0, 70.0)),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Tagline
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingXL),
                  child: Text(
                    AppConstants.appTagline.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                
                const SizedBox(height: 80),
                
                // AI distress active indicator text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulse dot
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.neonPink,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonPink.withValues(alpha: 0.6 * _pulseAnimation.value),
                                blurRadius: 8,
                                spreadRadius: 3 * _pulseAnimation.value,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI DISTRESS PROTOCOL ACTIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Shield Drawing Painter
class ShieldPainter extends CustomPainter {
  final Color glowColor;
  final Color primaryColor;

  ShieldPainter({required this.glowColor, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final fillPaint = Paint()
      ..color = AppColors.primaryPurple.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // Draw shield path
    final path = Path();
    path.moveTo(size.width * 0.5, 0); // Top-center
    path.quadraticBezierTo(size.width * 0.85, size.height * 0.05, size.width, size.height * 0.15); // Top-right curve
    path.quadraticBezierTo(size.width * 0.95, size.height * 0.6, size.width * 0.5, size.height); // Right-bottom curve
    path.quadraticBezierTo(size.width * 0.05, size.height * 0.6, 0, size.height * 0.15); // Left-bottom curve
    path.quadraticBezierTo(size.width * 0.15, size.height * 0.05, size.width * 0.5, 0); // Top-left curve
    path.close();

    // Draw Glow
    canvas.drawPath(path, glowPaint);
    // Draw Fill
    canvas.drawPath(path, fillPaint);
    // Draw Border
    canvas.drawPath(path, paint);

    // Inner Security Check/Emblem lines
    final innerPath = Path();
    innerPath.moveTo(size.width * 0.35, size.height * 0.48);
    innerPath.lineTo(size.width * 0.47, size.height * 0.6);
    innerPath.lineTo(size.width * 0.68, size.height * 0.35);

    final innerPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(innerPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Background Grid lines to give a tech dashboard feel
class CyberGridBackground extends StatelessWidget {
  const CyberGridBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GridPainter(
        color: Colors.white.withValues(alpha: 0.02),
        gridSize: 30.0,
      ),
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
      ..strokeWidth = 1.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
