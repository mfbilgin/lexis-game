import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../services/services.dart';
import '../providers/providers.dart';

class JokerPanelSheet extends ConsumerWidget {
  final int vowelJokers;
  final int consonantJokers;
  final VoidCallback? onRevealVowel;
  final VoidCallback? onRevealConsonant;
  final VoidCallback? onBuyJokers;

  const JokerPanelSheet({
    super.key,
    this.vowelJokers = 3,
    this.consonantJokers = 1,
    this.onRevealVowel,
    this.onRevealConsonant,
    this.onBuyJokers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: const Border(
              top: BorderSide(color: AppColors.glassBorder, width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Joker Seç',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: AppColors.glassDecoration(borderRadius: 16),
                      child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Güçlendirme ile avantaj kazan',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
              _buildJokerItem(
                context: context,
                ref: ref,
                emoji: '🔤',
                iconBg: AppColors.primary,
                title: 'Ünlü Harf',
                subtitle: 'Rastgele bir ünlü harfi göster',
                count: vowelJokers,
                onTap: vowelJokers > 0 ? onRevealVowel : null,
              ),
              const SizedBox(height: 10),
              _buildJokerItem(
                context: context,
                ref: ref,
                emoji: '🔡',
                iconBg: AppColors.surfaceLight,
                title: 'Ünsüz Harfi Göster',
                subtitle: 'Rastgele bir ünsüz harfi göster',
                count: consonantJokers,
                onTap: consonantJokers > 0 ? onRevealConsonant : null,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  const Text(
                    'Online maçlarda kullanılamaz',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJokerItem({
    required BuildContext context,
    required WidgetRef ref,
    required String emoji,
    required Color iconBg,
    required String title,
    required String subtitle,
    required int count,
    VoidCallback? onTap,
  }) {
    final isDisabled = count == 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppColors.glassDecoration(
            borderRadius: 16,
            bgColor: AppColors.background.withValues(alpha: 0.6),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (count == 0)
                _buildGetMoreButton(context, ref)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count kaldı',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGetMoreButton(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // Close the sheet
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => _buildGetJokersSheet(ctx, ref),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: AppColors.background),
            SizedBox(width: 2),
            Text(
              'AL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.background,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGetJokersSheet(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Jokerlerin Bitti!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),
          
          // Watch Ad Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(context);
                final adService = ref.read(adServiceProvider);
                adService.showRewardedAd(
                  onUserEarnedReward: () {
                    // Give 1 Vowel, 1 Consonant, 1 Extra Guess
                    ref.read(jokerProvider.notifier).addJokers(vowel: 1, consonant: 1, extra: 1);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tebrikler! +1 Joker Paketi kazandınız.')),
                    );
                  },
                );
              },
              icon: const Icon(Icons.play_circle_fill, color: Colors.white),
              label: const Text('Reklam İzle ve Kazan (+1 Joker)', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Go to Store Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(context);
                context.push('/store');
              },
              icon: const Icon(Icons.shopping_bag, color: AppColors.primary),
              label: const Text('Mağazaya Git', style: TextStyle(color: AppColors.primary, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

