import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_overlay.dart';
import 'splash_screen.dart' show ShieldPainter;
import '../widgets/ambient_background.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    // Floating logo animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _floatAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOutQuad,
      ),
    );
    _floatController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    // Listen to error notifications
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.neonPink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
            ),
          ),
        );
        ref.read(authNotifierProvider.notifier).clearError();
      }
      if (next.user != null && previous?.user == null) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
      }
    });

    return Scaffold(
      body: LoadingOverlay(
        isLoading: authState.isLoading,
        child: AmbientBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.paddingL,
                          vertical: AppConstants.paddingXL,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Spacer(flex: 1),
                            
                            // Floating shield graphic representing AI monitoring protection
                            FadeInSlide(
                              index: 0,
                              child: Center(
                                child: AnimatedBuilder(
                                  animation: _floatController,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(0, _floatAnimation.value),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Glowing orb behind the shield
                                          Container(
                                            width: 170,
                                            height: 170,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: [
                                                  AppColors.primaryPurple.withValues(alpha: 0.25),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                          // Concentric circle dots
                                          CustomPaint(
                                            size: const Size(200, 200),
                                            painter: ConcentricDotsPainter(
                                              color: AppColors.neonViolet.withValues(alpha: 0.2),
                                            ),
                                          ),
                                          // Shield logo
                                          Container(
                                            width: 90,
                                            height: 90,
                                            decoration: BoxDecoration(
                                              color: AppColors.cardBg.withValues(alpha: 0.8),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.15),
                                                width: 1.5,
                                                ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.neonViolet.withValues(alpha: 0.2),
                                                  blurRadius: 15,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: CustomPaint(
                                                size: const Size(40, 48),
                                                painter: ShieldPainter(
                                                  glowColor: AppColors.softPink,
                                                  primaryColor: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 48),
                            
                            // Brand Name
                            FadeInSlide(
                              index: 1,
                              child: Text(
                                AppConstants.appName,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  foreground: Paint()
                                    ..shader = const LinearGradient(
                                      colors: [Colors.white, AppColors.softPink],
                                    ).createShader(const Rect.fromLTWH(0.0, 0.0, 300.0, 70.0)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Tagline description
                            FadeInSlide(
                              index: 2,
                              child: Text(
                                "AI-Powered Real-Time Safety Dashboard. Protecting lives through smart distress analysis.",
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            
                            const Spacer(flex: 2),
                            
                            // Buttons Group
                            FadeInSlide(
                              index: 3,
                              child: CustomButton(
                                text: 'Sign In Session',
                                type: ButtonType.primary,
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.login);
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            FadeInSlide(
                              index: 4,
                              child: CustomButton(
                                text: 'Deploy Register',
                                type: ButtonType.secondary,
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.register);
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Social Divider
                            FadeInSlide(
                              index: 5,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'OR CONNECT SECURELY',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(alpha: 0.4),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Google Button
                            FadeInSlide(
                              index: 6,
                              child: CustomButton(
                                text: 'Continue with Google',
                                type: ButtonType.google,
                                onPressed: () {
                                  ref.read(authNotifierProvider.notifier).signInWithGoogle();
                                },
                              ),
                            ),
                            
                            const Spacer(flex: 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Drawing decorative circles around the shield logo
class ConcentricDotsPainter extends CustomPainter {
  final Color color;

  ConcentricDotsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Draw dashed concentric circle
    for (int i = 0; i < 360; i += 12) {
      final radians = i * pi / 180;
      final x = center.dx + radius * cos(radians);
      final y = center.dy + radius * sin(radians);
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
