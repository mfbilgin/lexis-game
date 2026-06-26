import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../models/badge_models.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(Theme.of(context).brightness),
        ),
        child: SafeArea(
          child: _buildProfileContent(context, ref),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(activeIndex: 3),
    );
  }



  Widget _buildProfileContent(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(userStatsProvider);
    final stats = statsAsync.asData?.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Header with User Info
          _buildUserHeader(context, ref, user, stats),
          const SizedBox(height: 24),

          // Stats
          _buildSectionHeader('İSTATİSTİKLER'),
          const SizedBox(height: 12),
          statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (_, __) => _buildStatsGrid(null),
            data: (userStats) => _buildStatsGrid(userStats),
          ),
          const SizedBox(height: 24),

          // Badges
          _buildSectionHeader('ROZETLER', trailing: GestureDetector(
            onTap: () => context.push('/badges'),
            child: const Text(
              'Tümünü Gör',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary),
            ),
          )),
          const SizedBox(height: 12),
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => _buildBadgePreview(context, ref, null),
            data: (userStats) => _buildBadgePreview(context, ref, userStats),
          ),
          const SizedBox(height: 24),

          // Store
          _buildSectionHeader('MAĞAZA'),
          const SizedBox(height: 12),
          _buildStoreSection(context),
          const SizedBox(height: 24),

          // Language
          _buildSectionHeader('DİL'),
          const SizedBox(height: 12),
          _buildLanguageSelector(ref),

          const SizedBox(height: 32),
          
          // Sign Out Section
          _buildSignOutSection(context, ref, user),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, WidgetRef ref, User? user, UserStats? stats) {
    final displayName = user?.displayName ?? stats?.displayName ?? 'Kullanıcı';
    final email = user?.email;
    final photoUrl = user?.photoURL;

    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
            image: photoUrl != null
                ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                : null,
          ),
          child: photoUrl == null
              ? const Icon(Icons.person, size: 32, color: AppColors.primary)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showEditNameDialog(context, ref, user, displayName),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
              if (email != null)
                Text(
                  email,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                )

            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showEditNameDialog(BuildContext context, WidgetRef ref, User? user, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Kullanıcı Adını Değiştir', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          style: const TextStyle(color: AppColors.textPrimary),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ0-9 ]')),
          ],
          decoration: InputDecoration(
            hintText: 'Yeni kullanıcı adı',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx, text);
              }
            },
            child: const Text('Kaydet', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName != currentName && user != null) {
      try {
        await ref.read(authServiceProvider).updateDisplayName(newName);
        await ref.read(firestoreServiceProvider).updateDisplayName(user.uid, newName);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Kullanıcı adı güncellendi!'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  Widget _buildSignOutSection(BuildContext context, WidgetRef ref, User? user) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () => _handleSignOut(context, ref, user),
        icon: const Icon(Icons.logout, color: AppColors.error),
        label: const Text(
          'Çıkış Yap',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: AppColors.error.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref, User? user) async {
    final confirm = await _showSignOutConfirmDialog(context);
    if (confirm != true) return;
    await ref.read(authServiceProvider).signOut();
  }

  Future<bool?> _showSignOutConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Çıkış Yapılsın mı?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Google hesabınızdan çıkış yapacaksınız.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: AppColors.textPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Çıkış Yap',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(UserStats? stats) {
    return Row(
      children: [
        _buildStatCard('Oynanan', '${stats?.gamesPlayed ?? 0}'),
        const SizedBox(width: 10),
        _buildStatCard('Kazanılan', '${stats?.gamesWon ?? 0}'),
        const SizedBox(width: 10),
        _buildStatCard('Kazanma', stats != null ? '${(stats.winRate * 100).toInt()}%' : '0%'),
        const SizedBox(width: 10),
        _buildStatCard('Seri', '${stats?.currentStreak ?? 0}'),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: AppColors.glassDecoration(borderRadius: 14),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgePreview(BuildContext context, WidgetRef ref, UserStats? stats) {
    final badgesAsync = ref.watch(badgesProvider);
    
    return badgesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Text('Rozetler yüklenemedi', style: TextStyle(color: AppColors.error)),
      data: (List<BadgeDefinition> badges) {
        if (badges.isEmpty) return const SizedBox.shrink();
        
        // Show first 4 badges
        final previewBadges = badges.take(4).toList();
        return Row(
          children: previewBadges.map((badge) {
            final unlocked = badge.isUnlocked(stats);
            return Expanded(
              child: GestureDetector(
                onTap: () => _showBadgeDialog(context, badge, unlocked),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surface.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: unlocked
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.glassBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        unlocked ? badge.emoji : '🔒',
                        style: const TextStyle(fontSize: 26),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        badge.getName('tr'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: unlocked ? AppColors.textPrimary : AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showBadgeDialog(BuildContext context, BadgeDefinition badge, bool unlocked) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(unlocked ? badge.emoji : '🔒', style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text(
              badge.getName('tr'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              badge.getDescription('tr'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: unlocked ? AppColors.primary.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.1),
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
            child: Text('Kapat', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(WidgetRef ref) {
    final currentLang = ref.watch(languageProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassDecoration(borderRadius: 18),
      child: Row(
        children: [
          const Text('🇹🇷', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Türkçe',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            ),
          ),
          if (currentLang == 'tr')
            const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
        ],
      ),
    );
  }

  Widget _buildStoreSection(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/store'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppColors.glassDecoration(borderRadius: 18),
        child: Row(
          children: [
            const Icon(Icons.shopping_bag, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mağaza',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Joker al, reklamları kaldır',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.textMuted,
          ),
        ),

        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }
}
