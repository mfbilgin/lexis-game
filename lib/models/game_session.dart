import 'game_models.dart';

/// Game mode enum
enum GameMode {
  daily,      // Günlük Kelime Modu - no timer
  scored,     // Puanlı Seri Modu - 20 sec per guess, 5 words
  practice,   // Practice mode - no timer, no score
  online,     // Online Mod - 20 sec per guess
  hint,       // İpuçlu Mod - shows first letter, no timer
}

/// Complete game session state
class GameSession {
  final String targetWord;
  final int wordLength;
  final int maxGuesses;
  final List<WordGuess> guesses;
  final int currentGuessIndex;
  final GameStatus status;
  final Map<String, LetterState> keyboardState;
  final DateTime? startTime;
  final DateTime? endTime;
  final GameMode mode;
  final String language; // 'tr' or 'en'
  
  // For scored mode: 5 words per game
  final int currentWordIndex;  // 0-4 for scored mode
  final int totalWordsInSession; // 5 for scored mode
  final int sessionScore;  // Total score across all words
  
  // For joker system
  final int usedExtraGuessJokers;
  final List<int> revealedLetterIndices;

  GameSession({
    required this.targetWord,
    this.wordLength = 5,
    this.maxGuesses = 6,
    List<WordGuess>? guesses,
    this.currentGuessIndex = 0,
    this.status = GameStatus.idle,
    Map<String, LetterState>? keyboardState,
    this.startTime,
    this.endTime,
    this.mode = GameMode.practice,
    this.language = 'tr',
    this.currentWordIndex = 0,
    this.totalWordsInSession = 1,
    this.sessionScore = 0,
    this.usedExtraGuessJokers = 0,
    this.revealedLetterIndices = const [],
  })  : guesses = guesses ??
            List.generate(maxGuesses, (_) => WordGuess(length: wordLength)),
        keyboardState = keyboardState ?? {};

  WordGuess get currentGuess => guesses[currentGuessIndex];

  bool get canSubmit => currentGuess.isComplete;

  bool get isGameOver =>
      status == GameStatus.won || status == GameStatus.lost;

  bool get hasTimer =>
      mode == GameMode.scored ||
      mode == GameMode.online ||
      mode == GameMode.hint;

  /// Scoring for Scored/Daily modes:
  /// 1st guess: 100, 2nd: 90, 3rd: 75, 4th: 55, 5th: 30, 6th: 10
  /// Extra guess joker: 50
  static const List<int> _scoredScoreByGuess = [100, 90, 75, 55, 30, 10];

  /// Scoring for Hint mode (first letter given as hint):
  /// 1st guess: 100, 2nd: 80, 3rd: 60, 4th: 40, 5th: 25, 6th: 10
  static const List<int> _hintScoreByGuess = [100, 80, 60, 40, 25, 10];

  /// Score for current word based on guess count and mode
  int get wordScore {
    // Practice mode never awards points
    if (mode == GameMode.practice) return 0;
    if (status != GameStatus.won) return 0;

    // currentGuessIndex is the index where we won (0-based)
    final guessNumber = currentGuessIndex; // 0-5 for normal, 6+ for joker

    if (mode == GameMode.hint) {
      if (guessNumber < _hintScoreByGuess.length) {
        return _hintScoreByGuess[guessNumber];
      }
      return 10; // fallback for extra guess joker in hint mode
    }

    if (guessNumber < _scoredScoreByGuess.length) {
      return _scoredScoreByGuess[guessNumber];
    } else {
      // Won with extra guess joker
      return 50;
    }
  }

  /// Alias for backward compatibility
  int get score => wordScore;

  /// Whether there are more words in scored mode
  bool get hasMoreWords => 
      mode == GameMode.scored && currentWordIndex < totalWordsInSession - 1;
  
  /// Whether we're at 6th guess and about to lose (can offer extra guess joker)
  bool get canUseExtraGuessJoker =>
      currentGuessIndex >= maxGuesses - 1 && 
      status == GameStatus.playing &&
      usedExtraGuessJokers == 0;

  GameSession copyWith({
    String? targetWord,
    int? wordLength,
    int? maxGuesses,
    List<WordGuess>? guesses,
    int? currentGuessIndex,
    GameStatus? status,
    Map<String, LetterState>? keyboardState,
    DateTime? startTime,
    DateTime? endTime,
    GameMode? mode,
    String? language,
    int? currentWordIndex,
    int? totalWordsInSession,
    int? sessionScore,
    int? usedExtraGuessJokers,
    List<int>? revealedLetterIndices,
    bool clearEndTime = false,
  }) {
    return GameSession(
      targetWord: targetWord ?? this.targetWord,
      wordLength: wordLength ?? this.wordLength,
      maxGuesses: maxGuesses ?? this.maxGuesses,
      guesses: guesses ?? this.guesses,
      currentGuessIndex: currentGuessIndex ?? this.currentGuessIndex,
      status: status ?? this.status,
      keyboardState: keyboardState ?? this.keyboardState,
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      mode: mode ?? this.mode,
      language: language ?? this.language,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      totalWordsInSession: totalWordsInSession ?? this.totalWordsInSession,
      sessionScore: sessionScore ?? this.sessionScore,
      usedExtraGuessJokers: usedExtraGuessJokers ?? this.usedExtraGuessJokers,
      revealedLetterIndices: revealedLetterIndices ?? this.revealedLetterIndices,
    );
  }
}
