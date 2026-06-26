import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';

// Settings providers
final themeSettingProvider = StateProvider<String>((ref) => 'dark');
final soundEnabledProvider = StateProvider<bool>((ref) => true);
final musicEnabledProvider = StateProvider<bool>((ref) => true);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSetting = ref.watch(themeSettingProvider);
    final soundEnabled = ref.watch(soundEnabledProvider);
    final musicEnabled = ref.watch(musicEnabledProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, Color(0xFF081410)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 64),
                      _buildSectionHeader('GÖRÜNÜM'),
                      const SizedBox(height: 12),
                      _buildThemeSelector(ref, themeSetting),
                      const SizedBox(height: 64),
                      _buildSectionHeader('PREMİUM'),
                      const SizedBox(height: 16),
                      _buildActionItem(
                        icon: Icons.block_rounded,
                        title: 'Reklamları Kaldır',
                        subtitle: 'Reklamsız deneyim',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.background,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu özellik yakında eklenecektir.')));
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildActionItem(
                        icon: Icons.restore,
                        title: 'Satın Alımları Geri Yükle',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu özellik yakında eklenecektir.')));
                        },
                      ),
                      const SizedBox(height: 64),
                      _buildSectionHeader('DESTEK'),
                      const SizedBox(height: 16),
                      _buildActionItem(
                        icon: Icons.mail_outline_rounded,
                        title: 'Bize Ulaşın',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İletişim: support@lexis.com')));
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildActionItem(
                        icon: Icons.shield_outlined,
                        title: 'Gizlilik Politikası',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gizlilik politikası sayfası hazırlanıyor.')));
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildActionItem(
                        icon: Icons.description_outlined,
                        title: 'Kullanım Şartları',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanım şartları sayfası hazırlanıyor.')));
                        },
                      ),
                      const SizedBox(height: 32),
                      // Version + status
                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Çevrimiçi',
                                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lexis v1.0.0',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: AppColors.glassDecoration(borderRadius: 20),
              child: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Ayarlar',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
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

  Widget _buildThemeSelector(WidgetRef ref, String current) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: AppColors.glassDecoration(borderRadius: 14),
      child: Row(
        children: [
          _buildThemeOption(ref, 'Açık', 'light', current),
          _buildThemeOption(ref, 'Koyu', 'dark', current),
          _buildThemeOption(ref, 'Otomatik', 'auto', current),
        ],
      ),
    );
  }

  Widget _buildThemeOption(WidgetRef ref, String label, String value, String current) {
    final isSelected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(themeSettingProvider.notifier).state = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.background : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppColors.glassDecoration(borderRadius: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            inactiveTrackColor: AppColors.surfaceLight,
            inactiveThumbColor: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: AppColors.glassDecoration(borderRadius: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                  if (subtitle != null)
                    Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
