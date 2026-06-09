import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../utils/validators.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/ambient_background.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  double _passwordStrength = 0.0;
  String _passwordStrengthLabel = 'Empty';
  Color _strengthColor = Colors.grey;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: AppConstants.durationNormal,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String val) {
    final strength = Validators.getPasswordStrength(val);
    final label = Validators.getPasswordStrengthLabel(strength);
    Color color;

    if (val.isEmpty) {
      color = Colors.grey;
    } else if (strength <= 0.2) {
      color = AppColors.neonPink;
    } else if (strength <= 0.4) {
      color = Colors.orangeAccent;
    } else if (strength <= 0.6) {
      color = Colors.amber.shade700;
    } else if (strength <= 0.8) {
      color = Colors.blueAccent;
    } else {
      color = AppColors.neonGreen;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = label;
      _strengthColor = color;
    });
  }

  void _onRegisterPressed() {
    if (_formKey.currentState!.validate()) {
      ref.read(authNotifierProvider.notifier).signUpWithEmailAndPassword(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    }
  }

  Widget _buildPasswordStrengthIndicator(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Password Strength',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              _passwordStrengthLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _strengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final segmentThreshold = (index + 1) * 0.2;
            final isFilled = _passwordStrength >= segmentThreshold - 0.01;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
                decoration: BoxDecoration(
                  color: isFilled ? _strengthColor : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Incorporate uppercase, lowercase, numbers, and symbols.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);

    // Listen to changes in authState (redirect or show error)
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

      if (next.isSignUpSuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registration successful! Please sign in with your credentials.'),
            backgroundColor: AppColors.neonGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
            ),
          ),
        );
        ref.read(authNotifierProvider.notifier).clearSignUpSuccess();
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.login,
        );
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LoadingOverlay(
        isLoading: authState.isLoading,
        child: AmbientBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.paddingL,
                          vertical: AppConstants.paddingM,
                        ),
                        child: Form(
                          key: _formKey,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 10),
                                // Header
                                FadeInSlide(
                                  index: 0,
                                  child: Text(
                                    'Create Account',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FadeInSlide(
                                  index: 1,
                                  child: Text(
                                    'Register to deploy SHEGUARD AI real-time security.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Glassmorphism form card
                                FadeInSlide(
                                  index: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(AppConstants.paddingL),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.05),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Name
                                        CustomTextField(
                                          controller: _nameController,
                                          labelText: 'Full Name',
                                          hintText: 'Jane Doe',
                                          prefixIcon: Icons.person_outline_rounded,
                                          validator: Validators.validateName,
                                        ),
                                        const SizedBox(height: 16),

                                        // Email
                                        CustomTextField(
                                          controller: _emailController,
                                          labelText: 'Email Address',
                                          hintText: 'name@example.com',
                                          prefixIcon: Icons.email_outlined,
                                          keyboardType: TextInputType.emailAddress,
                                          validator: Validators.validateEmail,
                                        ),
                                        const SizedBox(height: 16),

                                        // Password
                                        CustomTextField(
                                          controller: _passwordController,
                                          labelText: 'Password',
                                          hintText: 'Create secure password',
                                          prefixIcon: Icons.lock_outline_rounded,
                                          isPassword: true,
                                          onChanged: _onPasswordChanged,
                                          validator: Validators.validatePassword,
                                        ),
                                        const SizedBox(height: 12),

                                        // Strength Meter
                                        _buildPasswordStrengthIndicator(theme),
                                        const SizedBox(height: 16),

                                        // Confirm Password
                                        CustomTextField(
                                          controller: _confirmPasswordController,
                                          labelText: 'Confirm Password',
                                          hintText: 'Re-enter your password',
                                          prefixIcon: Icons.lock_reset_rounded,
                                          isPassword: true,
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) => _onRegisterPressed(),
                                          validator: (val) => Validators.validateConfirmPassword(
                                            val,
                                            _passwordController.text,
                                          ),
                                        ),

                                        const SizedBox(height: 32),

                                        // Submit button
                                        CustomButton(
                                          text: 'Deploy Credentials',
                                          type: ButtonType.primary,
                                          onPressed: _onRegisterPressed,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // Divider
                                FadeInSlide(
                                  index: 3,
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
                                          'OR REGISTER WITH',
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

                                // Google button
                                FadeInSlide(
                                  index: 4,
                                  child: CustomButton(
                                    text: 'Sign Up with Google',
                                    type: ButtonType.google,
                                    onPressed: () {
                                      ref.read(authNotifierProvider.notifier).signInWithGoogle();
                                    },
                                  ),
                                ),

                                const Spacer(flex: 1),

                                // Footer Navigation Link
                                FadeInSlide(
                                  index: 5,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Already registered? ',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.pushReplacementNamed(context, AppRoutes.login);
                                          },
                                          child: const Text(
                                            'Sign In',
                                            style: TextStyle(
                                              color: AppColors.neonViolet,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
