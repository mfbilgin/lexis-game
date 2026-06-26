import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Main fade/scale in
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Continuous pulse glow
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _pulseController.repeat(reverse: true);

    // Navigate to home after delay
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1F17), Color(0xFF081410), Color(0xFF060F0B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background glow effects
            _buildBackgroundGlows(),
            // Content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    AnimatedBuilder(
                      animation: _fadeController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: _buildLogo(),
                    ),
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'KELİME BULMACA',
                        style: TextStyle(
                          fontSize: 13,
                          letterSpacing: 6,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    AnimatedBuilder(
                      animation: _fadeController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _progressAnimation.value,
                          child: child,
                        );
                      },
                      child: _buildLoadingIndicator(),
                    ),
                    const SizedBox(height: 48),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'v1.0.0 © 2026 Lexis Games',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Top-center green glow
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 300 + (_pulseAnimation.value * 40),
                  height: 300 + (_pulseAnimation.value * 40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.08 * _pulseAnimation.value),
                        AppColors.primary.withValues(alpha: 0.02 * _pulseAnimation.value),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Center logo glow
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 200 + (_pulseAnimation.value * 60),
                  height: 200 + (_pulseAnimation.value * 60),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12 * _pulseAnimation.value),
                        AppColors.primary.withValues(alpha: 0.04 * _pulseAnimation.value),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                AppColors.textPrimary,
                AppColors.textPrimary,
              ],
            ).createShader(bounds),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  shadows: [
                    Shadow(
                      color: AppColors.primary.withValues(alpha: 0.6 * _pulseAnimation.value),
                      blurRadius: 30 + (_pulseAnimation.value * 20),
                    ),
                    Shadow(
                      color: AppColors.primary.withValues(alpha: 0.3 * _pulseAnimation.value),
                      blurRadius: 60 + (_pulseAnimation.value * 30),
                    ),
                  ],
                ),
                children: [
                  TextSpan(
                    text: 'LE',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  TextSpan(
                    text: 'X',
                    style: TextStyle(
                      color: AppColors.primary,
                      shadows: [
                        Shadow(
                          color: AppColors.primary.withValues(alpha: 0.8),
                          blurRadius: 20,
                        ),
                        Shadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                  ),
                  TextSpan(
                    text: 'IS',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'BAĞLANIYOR...',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 3,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 140,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: AppColors.surface.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
