import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../widgets/widgets.dart';

class ModeSelectionScreen extends ConsumerWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(Theme.of(context).brightness),
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

                      _buildSectionHeader('PUANLI SERİ'),
                      const SizedBox(height: 14),
                      _buildWordLengthCards(context, 'scored'),
                      const SizedBox(height: 28),
                      _buildSectionHeader('İPUÇLU MOD'),
                      const SizedBox(height: 14),
                      _buildWordLengthCards(context, 'hint'),
                      const SizedBox(height: 28),
                      _buildSectionHeader('PRATİK'),
                      const SizedBox(height: 14),
                      _buildWordLengthCards(context, 'practice'),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(activeIndex: 1),
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
            'Oyun Modu',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),

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

  Widget _buildWordLengthCards(BuildContext context, String mode) {
    return Column(
      children: [
        _buildWordCard(context, mode: mode, length: 4, emoji: '⚡', label: '4 Harfli', desc: 'Hızlı tur'),
        const SizedBox(height: 10),
        _buildWordCard(context, mode: mode, length: 5, emoji: '🎯', label: '5 Harfli', desc: 'Klasik mod'),
        const SizedBox(height: 10),
        _buildWordCard(context, mode: mode, length: 6, emoji: '🧠', label: '6 Harfli', desc: 'Zorlu deneyim'),
      ],
    );
  }

  Widget _buildWordCard(
    BuildContext context, {
    required String mode,
    required int length,
    required String emoji,
    required String label,
    required String desc,
  }) {
    return GestureDetector(
      onTap: () => context.push('/game/$mode/$length'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: AppColors.glassDecoration(borderRadius: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Letter boxes preview
            Row(
              children: List.generate(length, (i) {
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.letterBorder, width: 0.5),
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
