import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import '../models/badge_models.dart';

/// Firestore service provider
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// User stats provider (auto-updates when auth state changes)
final userStatsProvider = StreamProvider<UserStats?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).watchUserStats(user.uid);
});

/// Badges provider (fetches all badges from Firestore)
final badgesProvider = FutureProvider<List<BadgeDefinition>>((ref) async {
  final service = ref.watch(firestoreServiceProvider);
  return await service.getBadges();
});

/// Firestore database service
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Users collection reference
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Game scores collection — one doc per completed single-player game
  CollectionReference<Map<String, dynamic>> get _gameScores =>
      _db.collection('game_scores');

  /// Badges collection
  CollectionReference<Map<String, dynamic>> get _badges =>
      _db.collection('badges');

  /// Fetch all badges from Firestore
  Future<List<BadgeDefinition>> getBadges() async {
    final querySnapshot = await _badges.get();
    return querySnapshot.docs.map((doc) {
      return BadgeDefinition.fromJson(doc.data(), doc.id);
    }).toList();
  }

  /// Initial badge seeding: If badges collection is empty, populates it.
  Future<void> seedBadgesIfEmpty() async {
    final snap = await _badges.limit(1).get();
    if (snap.docs.isEmpty) {
      final initialBadges = [
        {
          'id': 'first_win',
          'emoji': '🏆',
          'name': {'tr': 'İlk Zafer'},
          'description': {'tr': 'Herhangi bir modda ilk oyununu kazan'},
          'condition': {'metric': 'gamesWon', 'threshold': 1},
        },
        {
          'id': 'streak_3',
          'emoji': '🔥',
          'name': {'tr': '3 Günlük Seri'},
          'description': {'tr': '3 gün üst üste günlük oyunu tamamla'},
          'condition': {'metric': 'currentStreak', 'threshold': 3},
        },
        {
          'id': 'streak_7',
          'emoji': '⚡',
          'name': {'tr': 'Haftalık Seri'},
          'description': {'tr': '7 gün üst üste günlük oyunu tamamla'},
          'condition': {'metric': 'currentStreak', 'threshold': 7},
        },
        {
          'id': 'streak_30',
          'emoji': '💎',
          'name': {'tr': 'Aylık Seri'},
          'description': {'tr': '30 gün üst üste günlük oyunu tamamla'},
          'condition': {'metric': 'currentStreak', 'threshold': 30},
        },
        {
          'id': 'perfect',
          'emoji': '🎯',
          'name': {'tr': 'Mükemmel Tahmin'},
          'description': {'tr': 'Toplam 100 veya daha fazla puan kazan'},
          'condition': {'metric': 'totalScore', 'threshold': 100},
        },
        {
          'id': 'games_10',
          'emoji': '🎮',
          'name': {'tr': '10 Oyun'},
          'description': {'tr': 'Herhangi bir modda 10 oyun tamamla'},
          'condition': {'metric': 'gamesPlayed', 'threshold': 10},
        },
        {
          'id': 'games_50',
          'emoji': '🌟',
          'name': {'tr': '50 Oyun'},
          'description': {'tr': 'Herhangi bir modda 50 oyun tamamla'},
          'condition': {'metric': 'gamesPlayed', 'threshold': 50},
        },
        {
          'id': 'games_100',
          'emoji': '👑',
          'name': {'tr': 'Yüzüncü Oyun'},
          'description': {'tr': 'Herhangi bir modda 100 oyun tamamla'},
          'condition': {'metric': 'gamesPlayed', 'threshold': 100},
        },
      ];

      final batch = _db.batch();
      for (final b in initialBadges) {
        final id = b['id'] as String;
        final docRef = _badges.doc(id);
        batch.set(docRef, b);
      }
      await batch.commit();
    }
  }

  /// Create or update user profile
  Future<void> createOrUpdateUser(User user) async {
    final docRef = _users.doc(user.uid);
    final doc = await docRef.get();

    // Treat null and empty string the same
    final authDisplayName = (user.displayName?.isNotEmpty == true)
        ? user.displayName
        : null;

    if (!doc.exists) {
      // Create new user
      await docRef.set({
        'displayName': authDisplayName ?? 'Player',
        'email': user.email,
        'authProvider': 'google',
        'createdAt': FieldValue.serverTimestamp(),
        'rating': 200, // Starting rating
        'stats': {
          'gamesPlayed': 0,
          'gamesWon': 0,
          'currentStreak': 0,
          'maxStreak': 0,
          'totalScore': 0,
        },
        'hasRemovedAds': false,
      });
    } else {
      // Update existing user — keep the existing displayName if Firebase Auth has none
      final existingName = doc.data()?['displayName'] as String?;
      final hasName = existingName != null && existingName.isNotEmpty;
      await docRef.update({
        'displayName': authDisplayName ?? (hasName ? existingName : 'Player'),
        'email': user.email,
        'authProvider': 'google',
      });
    }
  }

  /// Watch user stats stream
  Stream<UserStats?> watchUserStats(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserStats.fromFirestore(doc);
    });
  }

  /// Update game stats after completing a game
  Future<void> updateGameStats({
    required String uid,
    required bool won,
    required int score,
  }) async {
    final docRef = _users.doc(uid);
    final doc = await docRef.get();
    
    if (!doc.exists) return;
    
    final data = doc.data()!;
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    
    final gamesPlayed = (stats['gamesPlayed'] ?? 0) + 1;
    final gamesWon = (stats['gamesWon'] ?? 0) + (won ? 1 : 0);
    final currentStreak = won ? (stats['currentStreak'] ?? 0) + 1 : 0;
    final maxStreak = currentStreak > (stats['maxStreak'] ?? 0) 
        ? currentStreak 
        : (stats['maxStreak'] ?? 0);
    final totalScore = (stats['totalScore'] ?? 0) + score;

    await docRef.update({
      'stats': {
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'currentStreak': currentStreak,
        'maxStreak': maxStreak,
        'totalScore': totalScore,
      },
    });

    // Record individual game score for time-based leaderboards
    if (score > 0) {
      await _gameScores.add({
        'uid': uid,
        'displayName': data['displayName'] ?? 'Player',
        'score': score,
        'won': won,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> setHasRemovedAds(String uid, bool value) async {
    await _users.doc(uid).update({'hasRemovedAds': value});
  }

  /// Update user display name
  Future<void> updateDisplayName(String uid, String displayName) async {
    await _users.doc(uid).update({'displayName': displayName});
  }

  /// Get daily play status for today
  Future<Map<String, bool>> getDailyPlayStatus(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return {'5': false, '6': false};

      final data = doc.data()!;
      final dailyPlays = data['dailyPlays'] as Map<String, dynamic>? ?? {};
      final today = _todayKey();
      final todayData = dailyPlays[today] as Map<String, dynamic>? ?? {};

      return {
        '5': todayData['5'] == true,
        '6': todayData['6'] == true,
      };
    } catch (e) {
      print('Error getting daily play status: $e');
      return {'5': false, '6': false};
    }
  }

  /// Mark daily game as played for today
  Future<void> markDailyPlayed(String uid, int wordLength) async {
    try {
      final today = _todayKey();
      await _users.doc(uid).set({
        'dailyPlays': {
          today: {wordLength.toString(): true},
        },
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error marking daily played: $e');
    }
  }

  /// Today's date key
  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ──────────────────────────────────────────────
  // Leaderboard queries
  // ──────────────────────────────────────────────

  /// All-time leaderboard — total single-player scores from user stats
  Future<List<LeaderboardEntry>> getAllTimeLeaderboard({int limit = 50}) async {
    try {
      // Try to get ordered by score first
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _users
            .orderBy('stats.totalScore', descending: true)
            .limit(limit)
            .get();
      } catch (e) {
        // Fallback if index is missing: get latest users and sort in memory
        // This is not ideal for production but works for testing
        print('Index missing for stats.totalScore, falling back to simple query');
        snapshot = await _users.limit(limit).get();
      }
      
      final entries = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final stats = data['stats'] as Map<String, dynamic>? ?? {};
            final photoUrl = data['photoUrl'] as String?;
            return LeaderboardEntry(
              rank: 0,
              uid: doc.id,
              displayName: data['displayName'] ?? 'Player',
              photoUrl: photoUrl,
              score: (stats['totalScore'] as num?)?.toInt() ?? 0,
            );
          })
          .toList();

      // Ensure sorted desc (if fallback was used)
      entries.sort((a, b) => b.score.compareTo(a.score));
      
      // Assign ranks
      for (int i = 0; i < entries.length; i++) {
        entries[i] = LeaderboardEntry(
          rank: i + 1,
          uid: entries[i].uid,
          displayName: entries[i].displayName,
          photoUrl: entries[i].photoUrl,
          score: entries[i].score,
        );
      }
      return entries;
    } catch (e) {
      print('Error getting all-time leaderboard: $e');
      return [];
    }
  }

  /// Monthly leaderboard — scores from 1st of current month
  Future<List<LeaderboardEntry>> getMonthlyLeaderboard({int limit = 50}) async {
    return _getTimeBasedLeaderboard(_startOfMonth(), limit: limit);
  }

  /// Weekly leaderboard — scores from Monday 00:00
  Future<List<LeaderboardEntry>> getWeeklyLeaderboard({int limit = 50}) async {
    return _getTimeBasedLeaderboard(_startOfWeek(), limit: limit);
  }

  /// Online ratings leaderboard — users sorted by Elo rating
  Future<List<LeaderboardEntry>> getOnlineRatingsLeaderboard({int limit = 50}) async {
    try {
      final snapshot = await _users
          .orderBy('rating', descending: true)
          .limit(limit)
          .get();
      final entries = snapshot.docs
          .where((doc) {
            final data = doc.data();
            // Only include users who have a rating set (played online)
            return data.containsKey('rating');
          })
          .map((doc) {
            final data = doc.data();
            return LeaderboardEntry(
              rank: 0,
              uid: doc.id,
              displayName: data['displayName'] ?? 'Player',
              photoUrl: data['photoUrl'] as String?,
              score: data['rating'] ?? 200,
            );
          })
          .toList();

      entries.sort((a, b) => b.score.compareTo(a.score));
      for (int i = 0; i < entries.length; i++) {
        entries[i] = LeaderboardEntry(
          rank: i + 1,
          uid: entries[i].uid,
          displayName: entries[i].displayName,
          photoUrl: entries[i].photoUrl,
          score: entries[i].score,
        );
      }
      return entries;
    } catch (e) {
      print('Error getting online ratings leaderboard: $e');
      return [];
    }
  }

  /// Shared helper: aggregate game_scores since a given date
  Future<List<LeaderboardEntry>> _getTimeBasedLeaderboard(
    DateTime since, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _gameScores
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .orderBy('timestamp', descending: true)
          .get();

      // Aggregate scores per user
      final userScores = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final uid = data['uid'] as String;
        final score = data['score'] as int? ?? 0;
        userScores[uid] = (userScores[uid] ?? 0) + score;
      }

      // Sort and pick top N
      final sortedUids = userScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sortedUids.take(limit).toList();

      final entries = <LeaderboardEntry>[];
      for (var i = 0; i < top.length; i++) {
        final uid = top[i].key;
        final totalScore = top[i].value;
        
        // Fetch user details for displayName and photoUrl
        final userDoc = await _users.doc(uid).get();
        final userData = userDoc.data();
        final displayName = userData?['displayName']?.toString() ?? 'Player';
        final photoUrl = userData?['photoUrl'] as String?;

        entries.add(LeaderboardEntry(
          rank: i + 1,
          uid: uid,
          displayName: displayName,
          photoUrl: photoUrl,
          score: totalScore,
        ));
      }
      return entries;
    } catch (e) {
      print('Error getting time-based leaderboard: $e');
      return [];
    }
  }

  /// Start of current month (1st day, 00:00 local time)
  DateTime _startOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Start of current week (Monday 00:00 local time)
  DateTime _startOfWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }
}

/// Helper class for aggregating scores
class _AggregatedScore {
  final String displayName;
  final String? photoUrl;
  int totalScore;

  _AggregatedScore({
    required this.displayName, 
    this.photoUrl,
    required this.totalScore,
  });
}

/// User statistics model
class UserStats {
  final String uid;
  final String displayName;
  final String? email;
  final String authProvider;
  final int gamesPlayed;
  final int gamesWon;
  final int currentStreak;
  final int maxStreak;
  final int totalScore;
  final bool hasRemovedAds;

  UserStats({
    required this.uid,
    required this.displayName,
    this.email,
    required this.authProvider,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.currentStreak,
    required this.maxStreak,
    required this.totalScore,
    required this.hasRemovedAds,
  });

  double get winRate => gamesPlayed > 0 ? gamesWon / gamesPlayed : 0;

  factory UserStats.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    
    return UserStats(
      uid: doc.id,
      displayName: data['displayName'] ?? 'Player',
      email: data['email'],
      authProvider: data['authProvider'] ?? 'anonymous',
      gamesPlayed: stats['gamesPlayed'] ?? 0,
      gamesWon: stats['gamesWon'] ?? 0,
      currentStreak: stats['currentStreak'] ?? 0,
      maxStreak: stats['maxStreak'] ?? 0,
      totalScore: stats['totalScore'] ?? 0,
      hasRemovedAds: data['hasRemovedAds'] ?? false,
    );
  }
}

/// Leaderboard entry model
class LeaderboardEntry {
  final int rank;
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int score;

  LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.score,
  });

  factory LeaderboardEntry.fromFirestore(DocumentSnapshot doc, int rank) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaderboardEntry(
      rank: rank,
      uid: data['uid'] ?? doc.id,
      displayName: data['displayName'] ?? 'Player',
      photoUrl: data['photoUrl'],
      score: data['score'] ?? 0,
    );
  }
}
