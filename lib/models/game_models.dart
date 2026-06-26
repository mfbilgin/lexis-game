/// Game state enumeration
enum GameStatus {
  idle,
  playing,
  won,
  lost,
}

/// Letter evaluation result
enum LetterState {
  empty,      // Not yet evaluated
  filled,     // Filled but not submitted
  correct,    // Correct letter, correct position (green)
  wrongPosition, // Correct letter, wrong position (yellow)
  wrong,      // Letter not in word (gray)
}

/// A single letter in a guess
class LetterTile {
  final String letter;
  final LetterState state;

  const LetterTile({
    this.letter = '',
    this.state = LetterState.empty,
  });

  LetterTile copyWith({
    String? letter,
    LetterState? state,
  }) {
    return LetterTile(
      letter: letter ?? this.letter,
      state: state ?? this.state,
    );
  }

  bool get isEmpty => letter.isEmpty;
  bool get isFilled => letter.isNotEmpty;
}

/// A single guess (row of letters)
class WordGuess {
  final List<LetterTile> letters;
  final bool isSubmitted;

  WordGuess({
    required int length,
    List<LetterTile>? letters,
    this.isSubmitted = false,
  }) : letters = letters ?? List.generate(length, (_) => const LetterTile());

  String get word => letters.map((l) => l.letter).join();

  bool get isComplete => letters.every((l) => l.isFilled);

  bool get isCorrect => letters.every((l) => l.state == LetterState.correct);

  WordGuess copyWith({
    List<LetterTile>? letters,
    bool? isSubmitted,
  }) {
    return WordGuess(
      length: this.letters.length,
      letters: letters ?? this.letters,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }
}
