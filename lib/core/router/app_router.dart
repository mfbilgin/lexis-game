import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../screens/screens.dart';
import '../../services/auth_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final authStream = ref.watch(authStateProvider.stream);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authStream),
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.uri.path == '/login';
      final isSplash = state.uri.path == '/';

      if (isSplash) {
        return null; // Let splash screen handle initial navigation
      }

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/modes',
        builder: (context, state) => const ModeSelectionScreen(),
      ),
      GoRoute(
        path: '/store',
        builder: (context, state) => const StoreScreen(),
      ),
      // Daily mode with variable length (5 or 6)
      GoRoute(
        path: '/game/daily/:length',
        builder: (context, state) {
          final length = int.tryParse(state.pathParameters['length'] ?? '5') ?? 5;
          return GameScreen(
            mode: 'daily',
            wordLength: length,
          );
        },
      ),
      GoRoute(
        path: '/game/practice/:length',
        builder: (context, state) {
          final length = int.tryParse(state.pathParameters['length'] ?? '5') ?? 5;
          return GameScreen(
            mode: 'practice',
            wordLength: length,
          );
        },
      ),
      GoRoute(
        path: '/game/scored/:length',
        builder: (context, state) {
          final length = int.tryParse(state.pathParameters['length'] ?? '5') ?? 5;
          return GameScreen(
            mode: 'scored',
            wordLength: length,
          );
        },
      ),
      GoRoute(
        path: '/game/hint/:length',
        builder: (context, state) {
          final length = int.tryParse(state.pathParameters['length'] ?? '5') ?? 5;
          return GameScreen(
            mode: 'hint',
            wordLength: length,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MatchResultScreen(
            isVictory: extra['isVictory'] ?? false,
            word: extra['word'] ?? 'LEXIS',
            score: extra['score'] ?? 0,
            ratingChange: extra['ratingChange'] ?? 0,
            duration: extra['duration'] ?? 0,
            nextDailyReset: extra['nextDailyReset'],
            definition: extra['definition'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/badges',
        builder: (context, state) => const BadgesScreen(),
      ),
      GoRoute(
        path: '/game/online',
        builder: (context, state) {
          final gameId = state.uri.queryParameters['gameId'];
          return OnlineGameScreen(gameId: gameId);
        },
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
