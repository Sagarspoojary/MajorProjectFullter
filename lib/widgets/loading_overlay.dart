import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) ...[
          // Semi-transparent blocker
          const Opacity(
            opacity: 0.3,
            child: ModalBarrier(dismissible: false, color: Colors.black),
          ),
          // Blur backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: const SizedBox.shrink(),
            ),
          ),
          // Futuristic card loader
          Center(
            child: Card(
              elevation: 8,
              color: AppColors.cardBg.withValues(alpha: 0.85),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusL),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(AppConstants.paddingL),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonViolet),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Securing session...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
