import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

/// Turkey timezone helper (UTC+3)
DateTime _turkeyNow() => DateTime.now().toUtc().add(const Duration(hours: 3));

String _turkeyDateKey() {
  final now = _turkeyNow();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// State for daily game persistence
class DailyGameState {
  final bool hasCompletedToday;
  final int streak;
  final GameSession? savedSession;
  final bool isLoading;

  const DailyGameState({
    this.hasCompletedToday = false,
    this.streak = 0,
    this.savedSession,
    this.isLoading = true,
  });

  DailyGameState copyWith({
    bool? hasCompletedToday,
    int? streak,
    GameSession? savedSession,
    bool? isLoading,
    bool clearSession = false,
  }) {
    return DailyGameState(
      hasCompletedToday: hasCompletedToday ?? this.hasCompletedToday,
      streak: streak ?? this.streak,
      savedSession: clearSession ? null : (savedSession ?? this.savedSession),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Manages daily game persistence with a DUAL lock:
///   1. SharedPreferences (device-level) — survives account switches
///   2. Firestore (account-level) — survives storage wipes / reinstalls
///
/// A player is locked out if EITHER source says "completed today".
class DailyGameNotifier extends StateNotifier<DailyGameState> {
  final FirestoreService _firestoreService;
  final User? _user;
  final int _wordLength;

  DailyGameNotifier(this._firestoreService, this._user, {int wordLength = 5})
      : _wordLength = wordLength, super(const DailyGameState()) {
    _load();
  }

  String get _localCompletedKey => 'daily_completed_date';
  String get _localStreakKey => 'daily_streak';
  String _sessionKey(String dateKey) => 'daily_session_$dateKey';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _turkeyDateKey();

    // ── 1. Local (device) check ──────────────────────────────────────────────
    final localCompleted = prefs.getString(_localCompletedKey) == todayKey;
    final streak = prefs.getInt(_localStreakKey) ?? 0;

    // ── 2. Remote (Firestore) check ──────────────────────────────────────────
    bool remoteCompleted = false;
    final user = _user;
    if (user != null && !localCompleted) {
      // Only hit Firestore when local says "not done" to save reads.
      try {
        final status = await _firestoreService.getDailyPlayStatus(user.uid);
        remoteCompleted = status.containsValue(true); // check if any length was completed today
      } catch (_) {
        // Network unavailable — fall back to local only.
      }
    }

    final hasCompleted = localCompleted || remoteCompleted;

    // If Firestore says completed but local doesn't know yet, sync local.
    if (remoteCompleted && !localCompleted) {
      await prefs.setString(_localCompletedKey, todayKey);
    }

    // ── 3. Load saved in-progress session ────────────────────────────────────
    GameSession? saved;
    if (!hasCompleted) {
      final savedJson = prefs.getString(_sessionKey(todayKey));
      if (savedJson != null) {
        saved = _deserializeSession(savedJson);
      }
    }

    state = DailyGameState(
      hasCompletedToday: hasCompleted,
      streak: streak,
      savedSession: saved,
      isLoading: false,
    );
  }

  /// Save current game session progress
  Future<void> saveSession(GameSession session) async {
    if (session.mode != GameMode.daily) return;

    final prefs = await SharedPreferences.getInstance();
    final todayKey = _turkeyDateKey();
    final json = _serializeSession(session);
    await prefs.setString(_sessionKey(todayKey), json);

    state = state.copyWith(savedSession: session);
  }

  /// Mark daily game as completed — writes to BOTH SharedPreferences & Firestore
  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _turkeyDateKey();

    // Check yesterday for streak
    final yesterday = _turkeyNow().subtract(const Duration(days: 1));
    final yesterdayKey =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final lastPlayDate = prefs.getString(_localCompletedKey);
    int newStreak;

    if (lastPlayDate == yesterdayKey) {
      newStreak = (prefs.getInt(_localStreakKey) ?? 0) + 1;
    } else if (lastPlayDate == todayKey) {
      newStreak = prefs.getInt(_localStreakKey) ?? 1;
    } else {
      newStreak = 1;
    }

    // ── 1. Write to SharedPreferences ────────────────────────────────────────
    await prefs.setString(_localCompletedKey, todayKey);
    await prefs.setInt(_localStreakKey, newStreak);
    await prefs.remove(_sessionKey(todayKey));

    // ── 2. Write to Firestore ─────────────────────────────────────────────────
    final user = _user;
    if (user != null) {
      try {
        await _firestoreService.markDailyPlayed(user.uid, _wordLength);
      } catch (_) {
        // Best-effort — if offline, Firestore will sync when back online
        // due to Firebase's offline persistence.
      }
    }

    state = DailyGameState(
      hasCompletedToday: true,
      streak: newStreak,
      savedSession: null,
      isLoading: false,
    );
  }

  /// Check if there's a saved session to restore
  bool get hasSavedSession => state.savedSession != null;

  /// Refresh state (e.g., when returning to home)
  Future<void> refresh() async => _load();

  // ── Serialization ───────────────────────────────────────────────────────────

  String _serializeSession(GameSession session) {
    final guessesJson = session.guesses.map((g) => {
          'letters': g.letters
              .map((l) => {
                    'letter': l.letter,
                    'state': l.state.index,
                  })
              .toList(),
          'isSubmitted': g.isSubmitted,
        }).toList();

    final kbState = session.keyboardState.map(
      (k, v) => MapEntry(k, v.index),
    );

    return jsonEncode({
      'targetWord': session.targetWord,
      'wordLength': session.wordLength,
      'maxGuesses': session.maxGuesses,
      'currentGuessIndex': session.currentGuessIndex,
      'status': session.status.index,
      'keyboardState': kbState,
      'startTime': session.startTime?.toIso8601String(),
      'language': session.language,
      'guesses': guessesJson,
      'usedExtraGuessJokers': session.usedExtraGuessJokers,
      'revealedLetterIndices': session.revealedLetterIndices,
    });
  }

  GameSession? _deserializeSession(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;

      final guesses = (map['guesses'] as List).map((g) {
        final letters = (g['letters'] as List).map((l) {
          return LetterTile(
            letter: l['letter'] as String,
            state: LetterState.values[l['state'] as int],
          );
        }).toList();
        return WordGuess(
          length: letters.length,
          letters: letters,
          isSubmitted: g['isSubmitted'] as bool,
        );
      }).toList();

      final kbState = (map['keyboardState'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, LetterState.values[v as int]),
      );

      return GameSession(
        targetWord: map['targetWord'] as String,
        wordLength: map['wordLength'] as int,
        maxGuesses: map['maxGuesses'] as int,
        guesses: guesses,
        currentGuessIndex: map['currentGuessIndex'] as int,
        status: GameStatus.values[map['status'] as int],
        keyboardState: kbState,
        startTime: map['startTime'] != null
            ? DateTime.parse(map['startTime'] as String)
            : null,
        mode: GameMode.daily,
        language: map['language'] as String,
        usedExtraGuessJokers: map['usedExtraGuessJokers'] as int? ?? 0,
        revealedLetterIndices:
            (map['revealedLetterIndices'] as List?)?.cast<int>() ?? [],
      );
    } catch (e) {
      return null;
    }
  }
}

/// Provider for daily game state — passes FirestoreService and current user
/// so that both the device lock and the account lock are enforced.
final dailyGameProvider =
    StateNotifierProviderFamily<DailyGameNotifier, DailyGameState, int>((ref, wordLength) {
  final firestoreService = ref.read(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  return DailyGameNotifier(firestoreService, user, wordLength: wordLength);
});
