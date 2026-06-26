import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../models/badge_models.dart';
import '../services/firestore_service.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(Theme.of(context).brightness),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: AppColors.glassDecoration(borderRadius: 20),
                        child: const Icon(Icons.arrow_back_ios_new, color: AppColors.textSecondary, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Rozetler',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Badge grid
              Expanded(
                child: statsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (_, __) => _buildBadgeGrid(null, ref),
                  data: (stats) => _buildBadgeGrid(stats, ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeGrid(UserStats? stats, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesProvider);
    return badgesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Center(child: Text('Rozetler yüklenemedi', style: TextStyle(color: AppColors.error))),
      data: (badges) {
        if (badges.isEmpty) return const Center(child: Text('Henüz rozet yok.', style: TextStyle(color: AppColors.textSecondary)));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final badge = badges[index];
              final unlocked = badge.isUnlocked(stats);
              return _buildBadgeCard(context, badge, unlocked);
            },
          ),
        );
      },
    );
  }

  Widget _buildBadgeCard(BuildContext context, BadgeDefinition badge, bool unlocked) {
    return GestureDetector(
      onTap: () => _showBadgeDetail(context, badge, unlocked),
      child: Container(
        decoration: BoxDecoration(
          color: unlocked
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: unlocked
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.glassBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              unlocked ? badge.emoji : '🔒',
              style: TextStyle(
                fontSize: 36,
                color: unlocked ? null : Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              badge.getName('tr'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: unlocked ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            if (unlocked)
              const Text(
                'Kazanıldı ✓',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              const Text(
                'Kilitli',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(BuildContext context, BadgeDefinition badge, bool unlocked) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              unlocked ? badge.emoji : '🔒',
              style: const TextStyle(fontSize: 52),
            ),
            const SizedBox(height: 16),
            Text(
              badge.getName('tr'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              badge.getDescription('tr'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: unlocked
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unlocked ? 'Kazanıldı ✓' : 'Henüz kazanılmadı',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: unlocked ? AppColors.primary : AppColors.error,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
