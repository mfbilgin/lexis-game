import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/word_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../core/utils/turkish_utils.dart';

// Current language provider
final languageProvider = StateProvider<String>((ref) => 'tr');

// Word service provider
final wordServiceProvider = Provider<WordService>((ref) {
  return WordService();
});

// Daily play check provider (backed by Firestore)
final dailyPlayProvider =
    StateNotifierProvider<DailyPlayNotifier, Map<String, bool>>((ref) {
      final firestoreService = ref.read(firestoreServiceProvider);
      final user = ref.watch(currentUserProvider);
      return DailyPlayNotifier(firestoreService, user);
    });

class DailyPlayNotifier extends StateNotifier<Map<String, bool>> {
  final FirestoreService _firestoreService;
  final User? _user;

  DailyPlayNotifier(this._firestoreService, this._user) : super({}) {
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (_user == null) {
      state = {'5': false, '6': false};
      return;
    }
    state = await _firestoreService.getDailyPlayStatus(_user.uid);
  }

  bool hasPlayedToday(int wordLength) {
    return state[wordLength.toString()] ?? false;
  }

  Future<void> markAsPlayed(int wordLength) async {
    state = {...state, wordLength.toString(): true};
    if (_user != null) {
      await _firestoreService.markDailyPlayed(_user.uid, wordLength);
    }
  }
}

// Joker inventory provider — watches current user so jokers reload on login/logout
final jokerProvider = StateNotifierProvider<JokerNotifier, JokerInventory>((
  ref,
) {
  final firestoreService = ref.read(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  return JokerNotifier(firestoreService, user);
});

class JokerInventory {
  final int vowelJokers;
  final int consonantJokers;
  final int extraGuessJokers;

  const JokerInventory({
    this.vowelJokers = 3,
    this.consonantJokers = 3,
    this.extraGuessJokers = 1,
  });

  JokerInventory copyWith({
    int? vowelJokers,
    int? consonantJokers,
    int? extraGuessJokers,
  }) {
    return JokerInventory(
      vowelJokers: vowelJokers ?? this.vowelJokers,
      consonantJokers: consonantJokers ?? this.consonantJokers,
      extraGuessJokers: extraGuessJokers ?? this.extraGuessJokers,
    );
  }
}

class JokerNotifier extends StateNotifier<JokerInventory> {
  final User? _user;

  JokerNotifier(FirestoreService _, this._user)
    : super(const JokerInventory()) {
    _load();
  }

  // ── Loading ──────────────────────────────────────────────────────────────

  Future<void> _load() async {
    // Try Firestore first (account-level, device-independent)
    final user = _user;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data()?['jokers'] as Map<String, dynamic>?;
        if (data != null) {
          state = JokerInventory(
            vowelJokers: (data['vowel'] as int?) ?? 3,
            consonantJokers: (data['consonant'] as int?) ?? 3,
            extraGuessJokers: (data['extra'] as int?) ?? 1,
          );
          return;
        }
      } catch (_) {
        // Firestore unavailable — fall through to local cache
      }
    }
    // Fall back to SharedPreferences (offline / not logged in)
    final prefs = await SharedPreferences.getInstance();
    state = JokerInventory(
      vowelJokers: prefs.getInt('joker_vowel') ?? 3,
      consonantJokers: prefs.getInt('joker_consonant') ?? 3,
      extraGuessJokers: prefs.getInt('joker_extra') ?? 1,
    );
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> _save() async {
    // 1. Local cache (always)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('joker_vowel', state.vowelJokers);
    await prefs.setInt('joker_consonant', state.consonantJokers);
    await prefs.setInt('joker_extra', state.extraGuessJokers);

    // 2. Firestore (best-effort, account-level)
    final user = _user;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'jokers': {
                'vowel': state.vowelJokers,
                'consonant': state.consonantJokers,
                'extra': state.extraGuessJokers,
              },
            });
      } catch (_) {
        // Best-effort — local cache serves as backup
      }
    }
  }

  // ── Use ──────────────────────────────────────────────────────────────────

  bool useVowelJoker() {
    if (state.vowelJokers <= 0) return false;
    state = state.copyWith(vowelJokers: state.vowelJokers - 1);
    _save();
    return true;
  }

  bool useConsonantJoker() {
    if (state.consonantJokers <= 0) return false;
    state = state.copyWith(consonantJokers: state.consonantJokers - 1);
    _save();
    return true;
  }

  bool useExtraGuessJoker() {
    if (state.extraGuessJokers <= 0) return false;
    state = state.copyWith(extraGuessJokers: state.extraGuessJokers - 1);
    _save();
    return true;
  }

  void addJokers({int vowel = 0, int consonant = 0, int extra = 0}) {
    state = state.copyWith(
      vowelJokers: state.vowelJokers + vowel,
      consonantJokers: state.consonantJokers + consonant,
      extraGuessJokers: state.extraGuessJokers + extra,
    );
    _save();
  }
}

// Game session notifier
class GameNotifier extends StateNotifier<GameSession> {
  final WordService _wordService;
  final FirestoreService _firestoreService;
  final User? _currentUser;
  final Ref _ref;

  bool _statsRecorded = false;

  GameNotifier(
    this._wordService,
    this._firestoreService,
    this._currentUser,
    this._ref,
  ) : super(GameSession(targetWord: '', wordLength: 5));

  /// Start a new game (practice mode - no timer)
  Future<void> startGame({int wordLength = 5, String language = 'tr'}) async {
    _statsRecorded = false;
    await _wordService.loadWords(wordLength, language: language);
    final targetWord = _wordService.getRandomWord(wordLength);

    state = GameSession(
      targetWord: targetWord,
      wordLength: wordLength,
      maxGuesses: 6,
      status: GameStatus.playing,
      startTime: DateTime.now(),
      mode: GameMode.practice,
      language: language,
    );
  }

  /// Restore a previously saved session (for daily mode persistence)
  void restoreSession(GameSession session) {
    state = session;
  }

  /// Start daily challenge (no timer)
  Future<void> startDailyChallenge({
    int wordLength = 5,
    String language = 'tr',
  }) async {
    _statsRecorded = false;
    await _wordService.loadWords(wordLength, language: language);
    final targetWord = _wordService.getDailyWord(
      wordLength,
      language: language,
    );

    state = GameSession(
      targetWord: targetWord,
      wordLength: wordLength,
      maxGuesses: 6,
      status: GameStatus.playing,
      startTime: DateTime.now(),
      mode: GameMode.daily,
      language: language,
    );
  }

  /// Start scored series mode (20 sec per guess, 5 words)
  Future<void> startScoredMode({
    int wordLength = 5,
    String language = 'tr',
  }) async {
    _statsRecorded = false;
    await _wordService.loadWords(wordLength, language: language);
    final targetWord = _wordService.getRandomWord(wordLength);

    state = GameSession(
      targetWord: targetWord,
      wordLength: wordLength,
      maxGuesses: 6,
      status: GameStatus.playing,
      startTime: DateTime.now(),
      mode: GameMode.scored,
      language: language,
      currentWordIndex: 0,
      totalWordsInSession: 5,
      sessionScore: 0,
    );
  }

  /// Start hint mode - pre-fills first letter of target word in every guess row
  Future<void> startHintMode({
    int wordLength = 5,
    String language = 'tr',
  }) async {
    _statsRecorded = false;
    await _wordService.loadWords(wordLength, language: language);
    final targetWord = _wordService.getRandomWord(wordLength);

    // Pre-fill the first letter in row 0
    final guesses = List<WordGuess>.generate(
      6,
      (i) => i == 0
          ? _prefillHintLetter(WordGuess(length: wordLength), targetWord)
          : WordGuess(length: wordLength),
    );

    state = GameSession(
      targetWord: targetWord,
      wordLength: wordLength,
      maxGuesses: 6,
      guesses: guesses,
      status: GameStatus.playing,
      startTime: DateTime.now(),
      mode: GameMode.hint,
      language: language,
    );
  }

  /// Fills index 0 of [guess] with the first letter of [targetWord].
  WordGuess _prefillHintLetter(WordGuess guess, String targetWord) {
    if (targetWord.isEmpty) return guess;
    final letters = List<LetterTile>.from(guess.letters);
    letters[0] = LetterTile(
      letter: turkishUpperCase(targetWord[0]),
      state: LetterState.filled,
    );
    return guess.copyWith(letters: letters);
  }

  /// Move to next word in scored mode
  Future<void> nextWordInScoredMode() async {
    if (state.mode != GameMode.scored) return;
    if (!state.hasMoreWords) return;

    _statsRecorded = false;

    final newScore = state.sessionScore + state.wordScore;
    final targetWord = _wordService.getRandomWord(state.wordLength);

    state = GameSession(
      targetWord: targetWord,
      wordLength: state.wordLength,
      maxGuesses: 6,
      status: GameStatus.playing,
      startTime: DateTime.now(),
      mode: GameMode.scored,
      language: state.language,
      currentWordIndex: state.currentWordIndex + 1,
      totalWordsInSession: state.totalWordsInSession,
      sessionScore: newScore,
    );
  }

  /// Handle timer expired — game over for all modes
  void onTimerExpired() {
    if (state.isGameOver) return;

    state = state.copyWith(status: GameStatus.lost, endTime: DateTime.now());

    final jokers = _ref.read(jokerProvider);
    final canUseJoker =
        state.mode != GameMode.online &&
        state.usedExtraGuessJokers == 0 &&
        jokers.extraGuessJokers > 0;
    if (!canUseJoker) {
      _updateStats(won: false, score: state.score);
    }
  }

  /// Reveal a vowel from the target word into the first empty slot of the
  /// current guess row (skipping any index already filled or already revealed).
  /// Returns the column index where the letter was placed, or null if none found.
  int? revealVowel() {
    if (state.isGameOver) return null;
    const vowels = ['A', 'E', 'I', 'İ', 'O', 'Ö', 'U', 'Ü'];
    final target = turkishUpperCase(state.targetWord);

    for (int i = 0; i < target.length; i++) {
      if (!vowels.contains(target[i])) continue;
      if (state.revealedLetterIndices.contains(i)) continue;
      // Check the tile isn't already filled by user input
      if (state.currentGuess.letters[i].isFilled) continue;

      // Place the letter into the tile
      final newLetters = List<LetterTile>.from(state.currentGuess.letters);
      newLetters[i] = LetterTile(letter: target[i], state: LetterState.filled);
      final newGuesses = List<WordGuess>.from(state.guesses);
      newGuesses[state.currentGuessIndex] = state.currentGuess.copyWith(
        letters: newLetters,
      );

      final newRevealed = [...state.revealedLetterIndices, i];
      state = state.copyWith(
        guesses: newGuesses,
        revealedLetterIndices: newRevealed,
      );
      return i;
    }
    return null; // No unrevealed vowel available
  }

  /// Reveal a consonant from the target word into the first empty slot of the
  /// current guess row.
  int? revealConsonant() {
    if (state.isGameOver) return null;
    const vowels = ['A', 'E', 'I', 'İ', 'O', 'Ö', 'U', 'Ü'];
    final target = turkishUpperCase(state.targetWord);

    for (int i = 0; i < target.length; i++) {
      if (vowels.contains(target[i])) continue;
      if (state.revealedLetterIndices.contains(i)) continue;
      if (state.currentGuess.letters[i].isFilled) continue;

      final newLetters = List<LetterTile>.from(state.currentGuess.letters);
      newLetters[i] = LetterTile(letter: target[i], state: LetterState.filled);
      final newGuesses = List<WordGuess>.from(state.guesses);
      newGuesses[state.currentGuessIndex] = state.currentGuess.copyWith(
        letters: newLetters,
      );

      final newRevealed = [...state.revealedLetterIndices, i];
      state = state.copyWith(
        guesses: newGuesses,
        revealedLetterIndices: newRevealed,
      );
      return i;
    }
    return null;
  }

  /// Get revealed letter at index (for UI — legacy, kept for compatibility)
  String? getRevealedLetter(int index) {
    if (state.revealedLetterIndices.contains(index)) {
      return turkishUpperCase(state.targetWord[index]);
    }
    return null;
  }

  /// Add a letter to current guess
  void addLetter(String letter) {
    if (state.isGameOver) return;
    if (state.status != GameStatus.playing) return;

    final currentGuess = state.currentGuess;
    final emptyIndex = currentGuess.letters.indexWhere((l) => l.isEmpty);

    if (emptyIndex == -1) return; // Row is full

    final newLetters = List<LetterTile>.from(currentGuess.letters);
    newLetters[emptyIndex] = LetterTile(
      letter: turkishUpperCase(letter),
      state: LetterState.filled,
    );

    final newGuesses = List<WordGuess>.from(state.guesses);
    newGuesses[state.currentGuessIndex] = currentGuess.copyWith(
      letters: newLetters,
    );

    state = state.copyWith(guesses: newGuesses);
  }

  /// Remove last letter from current guess.
  /// Blocked for:
  ///  - index 0 in hint mode (pre-filled first letter)
  ///  - any index in [revealedLetterIndices] (joker-revealed letters)
  void removeLetter() {
    if (state.isGameOver) return;
    if (state.status != GameStatus.playing) return;

    final currentGuess = state.currentGuess;

    // Scan backward to find the last letter that can be removed
    int removeIndex = -1;
    for (int i = currentGuess.letters.length - 1; i >= 0; i--) {
      if (!currentGuess.letters[i].isFilled) continue;

      // Lock: hint mode index 0 (pre-filled first letter)
      if (state.mode == GameMode.hint && i == 0) continue;

      // Lock: any joker-revealed position
      if (state.revealedLetterIndices.contains(i)) continue;

      removeIndex = i;
      break;
    }

    if (removeIndex == -1) return; // No removable letter found

    final newLetters = List<LetterTile>.from(currentGuess.letters);
    newLetters[removeIndex] = const LetterTile();

    final newGuesses = List<WordGuess>.from(state.guesses);
    newGuesses[state.currentGuessIndex] = currentGuess.copyWith(
      letters: newLetters,
    );

    state = state.copyWith(guesses: newGuesses);
  }

  /// Submit current guess - returns true if successful
  bool submitGuess() {
    if (state.isGameOver) return false;
    if (state.status != GameStatus.playing) return false;
    if (!state.canSubmit) return false;

    final guess = state.currentGuess.word;

    // Check if word is valid
    if (!_wordService.isValidWord(guess)) {
      return false;
    }

    // Evaluate the guess
    final results = _wordService.evaluateGuess(guess, state.targetWord);

    // Update letter tiles with results
    final newLetters = <LetterTile>[];
    for (int i = 0; i < guess.length; i++) {
      newLetters.add(
        LetterTile(letter: guess[i], state: _resultToState(results[i])),
      );
    }

    // Update keyboard state
    final newKeyboardState = Map<String, LetterState>.from(state.keyboardState);
    for (int i = 0; i < guess.length; i++) {
      final letter = guess[i];
      final newState = _resultToState(results[i]);
      final existingState = newKeyboardState[letter];

      // Only upgrade state (correct > wrongPosition > wrong)
      if (existingState == null ||
          _stateRank(newState) > _stateRank(existingState)) {
        newKeyboardState[letter] = newState;
      }
    }

    final newGuesses = List<WordGuess>.from(state.guesses);
    newGuesses[state.currentGuessIndex] = WordGuess(
      length: state.wordLength,
      letters: newLetters,
      isSubmitted: true,
    );

    // Check win/lose condition
    GameStatus newStatus = state.status;
    int newGuessIndex = state.currentGuessIndex;

    if (results.every((r) => r == LetterResult.correct)) {
      newStatus = GameStatus.won;
    } else if (state.currentGuessIndex >= state.maxGuesses - 1) {
      newStatus = GameStatus.lost;
    } else {
      newGuessIndex++;

      if (newGuessIndex < newGuesses.length) {
        var nextRow = newGuesses[newGuessIndex];

        // Pre-fill hint mode first letter
        if (state.mode == GameMode.hint) {
          nextRow = _prefillHintLetter(nextRow, state.targetWord);
        }

        // Pre-fill ALL joker-revealed letters into the new row
        // so the user cannot type something else in those positions
        if (state.revealedLetterIndices.isNotEmpty) {
          final letters = List<LetterTile>.from(nextRow.letters);
          final target = turkishUpperCase(state.targetWord);
          for (final idx in state.revealedLetterIndices) {
            if (idx < letters.length) {
              letters[idx] = LetterTile(
                letter: target[idx],
                state: LetterState.filled,
              );
            }
          }
          nextRow = nextRow.copyWith(letters: letters);
        }

        newGuesses[newGuessIndex] = nextRow;
      }
    }

    state = state.copyWith(
      guesses: newGuesses,
      currentGuessIndex: newGuessIndex,
      status: newStatus,
      keyboardState: newKeyboardState,
      endTime: newStatus != GameStatus.playing ? DateTime.now() : null,
    );

    if (newStatus == GameStatus.won) {
      _updateStats(won: true, score: state.score);
    } else if (newStatus == GameStatus.lost) {
      final jokers = _ref.read(jokerProvider);
      final canUseJoker =
          state.mode != GameMode.online &&
          state.usedExtraGuessJokers == 0 &&
          jokers.extraGuessJokers > 0;
      if (!canUseJoker) {
        _updateStats(won: false, score: state.score);
      }
    }

    return true;
  }

  void recordLoss() {
    if (state.status == GameStatus.lost) {
      _updateStats(won: false, score: state.score);
    }
  }

  Future<void> _updateStats({required bool won, required int score}) async {
    if (_statsRecorded) return;
    _statsRecorded = true;

    final user = _currentUser;
    if (user == null) return;

    await _firestoreService.updateGameStats(
      uid: user.uid,
      won: won,
      score: score,
    );
  }

  LetterState _resultToState(LetterResult result) {
    switch (result) {
      case LetterResult.correct:
        return LetterState.correct;
      case LetterResult.wrongPosition:
        return LetterState.wrongPosition;
      case LetterResult.wrong:
        return LetterState.wrong;
    }
  }

  int _stateRank(LetterState state) {
    switch (state) {
      case LetterState.correct:
        return 3;
      case LetterState.wrongPosition:
        return 2;
      case LetterState.wrong:
        return 1;
      default:
        return 0;
    }
  }

  /// Use an extra guess joker to continue playing after reaching the limit
  bool useExtraGuessJoker() {
    if (state.status == GameStatus.won) return false;
    if (state.status == GameStatus.playing) return false;
    if (state.usedExtraGuessJokers > 0) return false;

    bool ranOutOfGuesses = state.currentGuessIndex >= state.maxGuesses - 1 && state.currentGuess.isSubmitted;

    if (ranOutOfGuesses) {
      // Add a new row
      final newGuesses = List<WordGuess>.from(state.guesses);
      var nextRow = WordGuess(length: state.wordLength);

      if (state.mode == GameMode.hint) {
        nextRow = _prefillHintLetter(nextRow, state.targetWord);
      }
      if (state.revealedLetterIndices.isNotEmpty) {
        final letters = List<LetterTile>.from(nextRow.letters);
        final target = turkishUpperCase(state.targetWord);
        for (final idx in state.revealedLetterIndices) {
          if (idx < letters.length) {
            letters[idx] = LetterTile(
              letter: target[idx],
              state: LetterState.filled,
            );
          }
        }
        nextRow = nextRow.copyWith(letters: letters);
      }

      newGuesses.add(nextRow);

      state = state.copyWith(
        status: GameStatus.playing,
        maxGuesses: state.maxGuesses + 1,
        guesses: newGuesses,
        usedExtraGuessJokers: state.usedExtraGuessJokers + 1,
        clearEndTime: true,
      );
    } else {
      // We lost due to timeout. Just resume on the current row.
      state = state.copyWith(
        status: GameStatus.playing,
        usedExtraGuessJokers: state.usedExtraGuessJokers + 1,
        clearEndTime: true,
      );
    }

    return true;
  }
}

// Game provider
/// Global counter for games played in this session (used for Interstitial Ads)
final sessionGamesPlayedProvider = StateProvider<int>((ref) => 0);

/// Provider to manage game state
final gameProvider = StateNotifierProvider<GameNotifier, GameSession>((ref) {
  final wordService = ref.watch(wordServiceProvider);
  final firestoreService = ref.read(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider);
  return GameNotifier(wordService, firestoreService, user, ref);
});
