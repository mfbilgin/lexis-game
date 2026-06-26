import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(Theme.of(context).brightness),
        ),
        child: Stack(
          children: [
            // Background glow
            _buildBackgroundGlow(),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, ref),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _buildDailyCard(context, ref),
                          const SizedBox(height: 28),
                          _buildSectionHeader('OYUN MODLARI'),
                          const SizedBox(height: 14),
                          _buildModeCard(
                            context,
                            icon: Icons.person_outline,
                            title: 'Tek Oyunculu',
                            subtitle: 'Kendi hızında pratik yap',
                            color: AppColors.primary,
                            onTap: () => context.push('/modes'),
                          ),
                          const SizedBox(height: 12),
                          _buildModeCard(
                            context,
                            icon: Icons.public,
                            title: 'Online Eşleşme',
                            subtitle: 'Rakiplerine meydan oku',
                            color: const Color(0xFF3B82F6),
                            onTap: () => context.push('/game/online'),
                          ),
                          const SizedBox(height: 12),
                         
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(activeIndex: 0),
    );
  }

  Widget _buildBackgroundGlow() {
    return Positioned(
      top: -60,
      right: -40,
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              AppColors.primary.withValues(alpha: 0.02),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          // Logo
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
              children: [
                const TextSpan(text: 'LE', style: TextStyle(color: AppColors.textPrimary)),
                TextSpan(
                  text: 'X',
                  style: TextStyle(
                    color: AppColors.primary,
                    shadows: [
                      Shadow(color: AppColors.primary.withValues(alpha: 0.5), blurRadius: 12),
                    ],
                  ),
                ),
                const TextSpan(text: 'IS', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Spacer(),
          // Jokers
          _buildJokerBadge(context, ref),
          const SizedBox(width: 12),
          // Streak
          _buildStreakBadge(ref),
          const SizedBox(width: 12),
          // User Avatar
          _buildUserAvatar(context, ref),
        ],
      ),
    );
  }

  Widget _buildJokerBadge(BuildContext context, WidgetRef ref) {
    final jokers = ref.watch(jokerProvider);
    final totalJokers = jokers.vowelJokers + jokers.consonantJokers + jokers.extraGuessJokers;

    return GestureDetector(
      onTap: () => context.push('/store'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text(
              totalJokers > 999 ? '999+' : totalJokers.toString(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final photoUrl = user?.photoURL;

    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
          image: photoUrl != null && photoUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(photoUrl),
                  fit: BoxFit.cover,
                  onError: (error, stackTrace) {
                    debugPrint('Error loading avatar: $error');
                  },
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: photoUrl == null || photoUrl.isEmpty
            ? Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: AppColors.primary, size: 20),
              )
            : null,
      ),
    );
  }

  int _getDailyLength() {
    final turkeyNow = DateTime.now().toUtc().add(const Duration(hours: 3));
    final seed = turkeyNow.year * 1000 + turkeyNow.month * 100 + turkeyNow.day;
    return 4 + (seed % 4); // 4, 5, 6, 7
  }

  Widget _buildStreakBadge(WidgetRef ref) {
    final dailyLength = _getDailyLength();
    final dailyState = ref.watch(dailyGameProvider(dailyLength));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppColors.glassDecoration(borderRadius: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, color: AppColors.warning, size: 18),
          const SizedBox(width: 4),
          Text(
            '${dailyState.streak}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCard(BuildContext context, WidgetRef ref) {
    final dailyLength = _getDailyLength();
    final dailyState = ref.watch(dailyGameProvider(dailyLength));
    final hasCompleted = dailyState.hasCompletedToday;
    
    return GestureDetector(
      onTap: hasCompleted ? null : () => context.push('/game/daily/$dailyLength'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: hasCompleted ? 0.08 : 0.15),
              AppColors.primary.withValues(alpha: hasCompleted ? 0.02 : 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'GÜNÜN KELİMESİ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (hasCompleted)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 24),
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: AppColors.background, size: 24),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              hasCompleted ? 'Bugünü tamamladın' : '$dailyLength harfli kelimeyi bul',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text( 
              hasCompleted 
                  ? 'Yarın yeni kelime gelecek'
                  : 'Her gün yeni bir kelime seni bekliyor',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Mini preview tiles
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: List.generate(dailyLength, (i) {
                  return Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: hasCompleted ? 0.15 : (i == 0 ? 0.25 : 0.08)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: hasCompleted ? 0.3 : (i == 0 ? 0.5 : 0.15)),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        hasCompleted ? '✓' : (i == 0 ? '?' : ''),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppColors.glassDecoration(borderRadius: 18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
