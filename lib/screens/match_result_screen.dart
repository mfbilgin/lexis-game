import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/turkish_utils.dart';

class MatchResultScreen extends StatefulWidget {
  final bool isVictory;
  final String word;
  final int score;
  final int ratingChange;
  final int duration;
  final DateTime? nextDailyReset;
  final String definition;

  const MatchResultScreen({
    super.key,
    required this.isVictory,
    required this.word,
    this.score = 0,
    this.ratingChange = 0,
    this.duration = 0,
    this.nextDailyReset,
    this.definition = '',
  });

  @override
  State<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends State<MatchResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _pulseController.repeat(reverse: true);

    if (widget.nextDailyReset != null) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    void updateTime() {
      final now = DateTime.now().toUtc();
      final diff = widget.nextDailyReset!.difference(now);
      if (diff.isNegative) {
        setState(() => _timeUntilReset = Duration.zero);
        _countdownTimer?.cancel();
      } else {
        setState(() => _timeUntilReset = diff);
      }
    }

    updateTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => updateTime());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultColor = widget.isVictory ? AppColors.primary : AppColors.error;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(Theme.of(context).brightness),
        ),
        child: Stack(
          children: [
            // Background glow
            _buildBackgroundGlow(resultColor),
            SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        // Result icon
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: resultColor.withValues(alpha: 0.15),
                                boxShadow: [
                                  BoxShadow(
                                    color: resultColor.withValues(
                                      alpha: 0.2 * _pulseAnimation.value,
                                    ),
                                    blurRadius: 30 + (_pulseAnimation.value * 20),
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                widget.isVictory ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied,
                                color: resultColor,
                                size: 40,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        // Title
                        Text(
                          widget.isVictory ? 'TEBRİKLER!' : 'MAALESEF',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                            color: resultColor,
                            shadows: [
                              Shadow(
                                color: resultColor.withValues(alpha: 0.4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isVictory ? 'Kelimeyi buldun!' : 'Bu sefer olmadı',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Word tiles
                        _buildWordTiles(),
                        if (widget.definition.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildDefinitionCard(),
                        ],
                        const SizedBox(height: 28),
                        // Stats row
                        _buildStatsRow(),
                        // Rating change
                        if (widget.ratingChange != 0) ...[
                          const SizedBox(height: 20),
                          _buildRatingChange(),
                        ],
                        const Spacer(flex: 2),
                        // Action buttons
                        _buildActionButtons(context),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGlow(Color color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        return Positioned.fill(
          child: Center(
            child: Container(
              width: 300 + (_pulseAnimation.value * 50),
              height: 300 + (_pulseAnimation.value * 50),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.06 * _pulseAnimation.value),
                    color.withValues(alpha: 0.02 * _pulseAnimation.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWordTiles() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final totalSpacing = (widget.word.length - 1) * 6;
        final maxTileWidth = (availableWidth - totalSpacing) / widget.word.length;
        final tileSize = maxTileWidth > 48.0 ? 48.0 : maxTileWidth;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.word.split('').map((letter) {
            return Container(
              width: tileSize,
              height: tileSize,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: widget.isVictory ? AppColors.primary : AppColors.letterWrong,
                borderRadius: BorderRadius.circular(10),
                boxShadow: widget.isVictory
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  turkishUpperCase(letter),
                  style: TextStyle(
                    fontSize: tileSize * 0.4,
                    fontWeight: FontWeight.w700,
                    color: widget.isVictory ? AppColors.background : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDefinitionCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'TDK SÖZLÜK ANLAMI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.definition,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem(
          Icons.star_rounded,
          '${widget.score}',
          'Puan',
          AppColors.primary,
        ),
        Container(
          width: 1,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          color: AppColors.glassBorder,
        ),
        _buildStatItem(
          Icons.timer_outlined,
          _formatDuration(widget.duration),
          'Süre',
          AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color iconColor) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildRatingChange() {
    final isPositive = widget.ratingChange > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (isPositive ? AppColors.primary : AppColors.error).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isPositive ? AppColors.primary : AppColors.error).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
            color: isPositive ? AppColors.primary : AppColors.error,
          ),
          const SizedBox(width: 6),
          Text(
            '${isPositive ? '+' : ''}${widget.ratingChange}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPositive ? AppColors.primary : AppColors.error,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Rating',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        if (widget.nextDailyReset == null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Tekrar Oyna',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppColors.glassDecoration(borderRadius: 16),
            child: Column(
              children: [
                Text(
                  'SONRAKİ KELİME',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCountdown(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.go('/home'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.glassBorder),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Ana Sayfa',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) return '${mins}d ${secs}s';
    return '${secs}s';
  }

  String _formatCountdown() {
    final h = _timeUntilReset.inHours.toString().padLeft(2, '0');
    final m = (_timeUntilReset.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_timeUntilReset.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
