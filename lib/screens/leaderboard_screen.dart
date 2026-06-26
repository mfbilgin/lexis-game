import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/widgets.dart';

// Leaderboard data provider - autoDispose ensures fresh data on each visit
final leaderboardProvider = FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>((ref, type) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  switch (type) {
    case 'allTime':
      return firestoreService.getAllTimeLeaderboard();
    case 'monthly':
      return firestoreService.getMonthlyLeaderboard();
    case 'weekly':
      return firestoreService.getWeeklyLeaderboard();
    case 'online':
      return firestoreService.getOnlineRatingsLeaderboard();
    default:
      return firestoreService.getAllTimeLeaderboard();
  }
});

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _refreshController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  static const _tabTypes = ['allTime', 'monthly', 'weekly', 'online'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(Theme.of(context).brightness),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildTabBar(),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabTypes.map((t) => _buildLeaderboardContent(t)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(activeIndex: 2),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          const Text(
            'Sıralama',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              // Refresh current tab with animation
              _refreshController.repeat();
              final type = _tabTypes[_tabController.index];
              ref.invalidate(leaderboardProvider(type));
              // Wait a bit to show animation
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) {
                _refreshController.stop();
                _refreshController.reset();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: AppColors.glassDecoration(borderRadius: 20),
              child: RotationTransition(
                turns: _refreshController,
                child: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1c3024),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / 4;
            return Stack(
              children: [
                // Sliding indicator
                AnimatedBuilder(
                  animation: _tabController.animation!,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_tabController.animation!.value * tabWidth, 0),
                      child: Container(
                        width: tabWidth,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Tab labels
                Row(
                  children: [
                    _buildTabItem('Genel', 0),
                    _buildTabItem('Bu Ay', 1),
                    _buildTabItem('Hafta', 2),
                    _buildTabItem('Online', 3),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _tabController.animation!,
          builder: (context, child) {
            final selected = _tabController.index == index;
            // Calculate selection process for text color transition
            // Determine if this tab is the target or current selection
            final value = _tabController.animation!.value;
            final isTarget = (value - index).abs() < 0.5;
            
            return Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isTarget ? FontWeight.bold : FontWeight.w500,
                  color: isTarget ? const Color(0xFF102216) : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            );
          },
        ),
      ),
    );
  }



  String _emptyMessage(String type) {
    switch (type) {
      case 'weekly':
        return 'Bu hafta henüz sıralama yok';
      case 'monthly':
        return 'Bu ay henüz sıralama yok';
      case 'online':
        return 'Online sıralama henüz yok';
      default:
        return 'Henüz sıralama yok';
    }
  }

  String _emptySubMessage(String type) {
    if (type == 'online') {
      return 'Online oyun oynayarak sıralamaya girin!';
    }
    return 'Oyun kazanın ve sıralamaya girin!';
  }

  Widget _buildPodium(List<LeaderboardEntry> top3, bool isOnline) {
    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 2nd Place
          if (top3.length > 1)
            Positioned(
              left: 20,
              bottom: 20,
              child: _buildPodiumItem(top3[1], 2, isOnline),
            ),
          // 3rd Place
          if (top3.length > 2)
            Positioned(
              right: 20,
              bottom: 20,
              child: _buildPodiumItem(top3[2], 3, isOnline),
            ),
          // 1st Place (Center and highest)
          if (top3.isNotEmpty)
            Positioned(
              bottom: 50,
              child: _buildPodiumItem(top3[0], 1, isOnline),
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(LeaderboardEntry entry, int rank, bool isOnline) {
    final isFirst = rank == 1;
    final color = rank == 1 ? const Color(0xFFFFD700) : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
    final double avatarSize = isFirst ? 80 : 64;
    final double badgeSize = isFirst ? 28 : 24;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for 1st place
        if (isFirst)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Icon(Icons.emoji_events, color: color, size: 32),
          ),
          
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Avatar Glow for 1st place
            if (isFirst)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              
            // Avatar
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: isFirst ? 4 : 2),
                color: const Color(0xFF1A2C20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: entry.photoUrl != null
                      ? Image.network(entry.photoUrl!, fit: BoxFit.cover)
                      : const Icon(Icons.person, color: Colors.white, size: 40),
                ),
              ),
            ),
            
            // Rank Badge
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF102216), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: isFirst ? 14 : 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Name
        Text(
          entry.displayName,
          style: TextStyle(
            fontSize: isFirst ? 14 : 12,
            fontWeight: isFirst ? FontWeight.bold : FontWeight.w600,
            color: isFirst ? AppColors.primary : AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        // Score
        Text(
          '${entry.score}',
          style: TextStyle(
            fontSize: isFirst ? 18 : 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRankItem(LeaderboardEntry entry, int rank, bool isOnline) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1c3024), // Dark card background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B9E94), // Muted text color
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A4034),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ClipOval(
              child: entry.photoUrl != null
                  ? Image.network(entry.photoUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.person, color: Colors.white70, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              entry.displayName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            '${entry.score}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardContent(String type) {
    final leaderboardAsync = ref.watch(leaderboardProvider(type));
    final isOnline = type == 'online';
    final user = ref.watch(currentUserProvider); // specific user object to get photoUrl

    return leaderboardAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 100),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      _emptyMessage(type),
                      style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _emptySubMessage(type),
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final userEntry = _getUserRank(entries, ref);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (entries.isNotEmpty) _buildPodium(entries.take(3).toList(), isOnline),
                    const SizedBox(height: 20),
                    ...List.generate(
                      entries.length > 3 ? entries.length - 3 : 0,
                      (i) => _buildRankItem(entries[i + 3], i + 4, isOnline),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildUserFooter(userEntry, user, entries.length),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => ListView(
        children: [
          const SizedBox(height: 100),
          Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text('Sıralama yüklenemedi', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(leaderboardProvider(type)),
                  child: const Text('Tekrar Dene', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to find valid user rank
  LeaderboardEntry? _getUserRank(List<LeaderboardEntry> entries, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    if (user == null) return null;
    try {
      return entries.firstWhere((e) => e.uid == user.uid);
    } catch (_) {
      return null;
    }
  }

  Widget _buildUserFooter(LeaderboardEntry? userEntry, User? user, int totalPlayers) {
    if (userEntry == null) return const SizedBox.shrink();

    int percentage = 100;
    if (totalPlayers > 0) {
      percentage = ((userEntry.rank / totalPlayers) * 100).ceil();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102216).withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea( // Ensure it respects safe area if bottom nav is not present or transparent
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sıralamanız',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                     Icon(Icons.arrow_upward, size: 14, color: AppColors.primary),
                     const SizedBox(width: 4),
                     Text(
                       'Top %$percentage',
                       style: const TextStyle(
                         fontSize: 12,
                         color: AppColors.primary,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${userEntry.rank}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                      color: const Color(0xFF2A4034),
                      image: user?.photoURL != null 
                          ? DecorationImage(
                              image: NetworkImage(user!.photoURL!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: user?.photoURL == null 
                        ? const Icon(Icons.person, color: Colors.white70, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Siz',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${userEntry.score}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
