import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _gridSlideAnimation;
  late Animation<double> _buttonSlideAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    );

    _gridSlideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _buttonSlideAnimation = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(authServiceProvider).signInWithGoogle();
      if (result != null && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Giriş hatası: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1F17), Color(0xFF0B1410), Color(0xFF060F0B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // LEXIS logo
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
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
                              Shadow(color: Color(0x9926E575), blurRadius: 20),
                              Shadow(color: Color(0x6626E575), blurRadius: 40),
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

                const Spacer(flex: 1),

                // 4x4 Word grid
                AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _gridSlideAnimation.value),
                        child: child,
                      ),
                    );
                  },
                  child: _buildWordGrid(),
                ),

                const Spacer(flex: 2),

                // Continue with Google button
                AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _buttonSlideAnimation.value),
                        child: child,
                      ),
                    );
                  },
                  child: _buildGoogleButton(),
                ),

                const SizedBox(height: 16),

                const SizedBox(height: 20),

                // Terms & Privacy links
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    'Giriş yaparak Kullanım Şartları ve Gizlilik Politikasını kabul etmiş olursunuz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordGrid() {
    // Grid layout matching the design mockup:
    // WORD → O is green (correct)
    // PLAY → A is yellow (wrong position)
    // GAME → A is green (correct)
    // SOLV → V is yellow (wrong position)
    final tiles = [
      _tile('W', null), _tile('O', 'green'), _tile('R', null), _tile('D', null),
      _tile('P', null), _tile('L', null), _tile('A', 'yellow'), _tile('Y', null),
      _tile('G', null), _tile('A', 'green'), _tile('M', null), _tile('E', null),
      _tile('S', null), _tile('O', null), _tile('L', null), _tile('V', 'yellow'),
    ];

    return SizedBox(
      width: 280,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glow effects
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD34E).withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: tiles,
          ),
        ],
      ),
    );
  }

  Widget _tile(String letter, String? color) {
    Color bgColor;
    Color textColor;
    List<BoxShadow> shadows = [];
    Border? border;

    if (color == 'green') {
      bgColor = AppColors.primary;
      textColor = Colors.black;
      shadows = [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.4),
          blurRadius: 15,
        ),
      ];
      border = Border.all(color: AppColors.primary.withValues(alpha: 0.6));
    } else if (color == 'yellow') {
      bgColor = const Color(0xFFFFD34E);
      textColor = Colors.black;
      shadows = [
        BoxShadow(
          color: const Color(0xFFFFD34E).withValues(alpha: 0.3),
          blurRadius: 15,
        ),
      ];
      border = Border.all(color: const Color(0xFFFFD34E).withValues(alpha: 0.5));
    } else {
      bgColor = const Color(0xFF15211B);
      textColor = Colors.white.withValues(alpha: 0.2);
      border = Border.all(color: Colors.white.withValues(alpha: 0.05));
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: shadows,
        border: border,
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF102216),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF102216),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google G logo
                  Image.asset(
                    'assets/g-logo.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.g_mobiledata, size: 32, color: Colors.blue);
                    },
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Google ile Devam Et',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}


