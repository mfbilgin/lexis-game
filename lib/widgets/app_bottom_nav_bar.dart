import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';

class AppBottomNavBar extends StatelessWidget {
  final int activeIndex;

  const AppBottomNavBar({super.key, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final items = [
      _BottomNavItem(Icons.home_rounded, 'Ana Sayfa', '/home'),
      _BottomNavItem(Icons.extension_outlined, 'Oyna', '/modes'),
      _BottomNavItem(Icons.bar_chart_rounded, 'Sıralama', '/leaderboard'),
      _BottomNavItem(Icons.person_outline, 'Profil', '/profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = i == activeIndex;
              return GestureDetector(
                onTap: () => context.go(items[i].route),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].icon,
                        color: isActive ? AppColors.primary : AppColors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          color: isActive ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final IconData icon;
  final String label;
  final String route;

  _BottomNavItem(this.icon, this.label, this.route);
}
