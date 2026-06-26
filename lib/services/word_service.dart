import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../core/utils/turkish_utils.dart';

class WordService {
  final Map<int, List<String>> _targetWords = {};
  final Map<int, Set<String>> _validGuesses = {};
  final Map<String, String> _definitions = {};
  final Random _random = Random();
  bool _isLoaded = false;

  /// Load word list for a specific length
  Future<void> loadWords(int length, {String language = 'tr'}) async {
    if (_isLoaded) return;

    try {
      final targetsStr = await rootBundle.loadString('assets/words/target_words.json');
      final validStr = await rootBundle.loadString('assets/words/valid_guesses.json');
      final defsStr = await rootBundle.loadString('assets/words/definitions.json');

      final Map<String, dynamic> targetsJson = jsonDecode(targetsStr);
      final Map<String, dynamic> validJson = jsonDecode(validStr);
      final Map<String, dynamic> defsJson = jsonDecode(defsStr);

      for (var entry in targetsJson.entries) {
        _targetWords[int.parse(entry.key)] = 
            (entry.value as List).map((e) => turkishUpperCase(e.toString())).toList();
      }
      for (var entry in validJson.entries) {
        _validGuesses[int.parse(entry.key)] = 
            (entry.value as List).map((e) => turkishUpperCase(e.toString())).toSet();
      }
      for (var entry in defsJson.entries) {
        _definitions[turkishUpperCase(entry.key)] = entry.value.toString();
      }
      _isLoaded = true;
    } catch (e) {
      // Fallback words if file not found
      _targetWords[length] = _getFallbackWords(length);
      _validGuesses[length] = _targetWords[length]!.toSet();
    }
  }

  /// Get definition of a word
  String? getDefinition(String word) {
    String? def = _definitions[turkishUpperCase(word)];
    if (def == null) return null;

    final match = RegExp(r'^\d+\s+(.*)$').firstMatch(def);
    if (match != null) {
      return 'Bkz. ${match.group(1)}';
    }

    return def;
  }

  /// Get a random word of specified length
  String getRandomWord(int length) {
    final words = _targetWords[length];
    if (words == null || words.isEmpty) {
      throw Exception('Word list not loaded for length $length');
    }
    return words[_random.nextInt(words.length)];
  }

  /// Get daily word based on date (Turkey timezone UTC+3).
  ///
  /// Uses a **seeded [Random]** so the result is:
  /// - Identical on every device/account for the same calendar day.
  /// - Unpredictable — not tied to the alphabetical order of the word list.
  ///   Consecutive days jump to completely different indices.
  ///
  /// Seed formula: year × 100 000  +  month × 1 000  +  day  +  length × 10 000 000
  /// This guarantees no collision between dates or word lengths.
  String getDailyWord(int length, {String language = 'tr'}) {
    final words = _targetWords[length];
    if (words == null || words.isEmpty) {
      throw Exception('Word list not loaded for length $length');
    }

    // Turkey timezone (UTC+3) — word changes at midnight Istanbul time.
    final turkeyNow = DateTime.now().toUtc().add(const Duration(hours: 3));

    final seed = turkeyNow.year * 100000 +
        turkeyNow.month * 1000 +
        turkeyNow.day +
        length * 10000000;

    return words[Random(seed).nextInt(words.length)];
  }

  /// Check if a word is valid
  bool isValidWord(String word) {
    final length = word.length;
    final validSet = _validGuesses[length];
    if (validSet == null) return false;
    return validSet.contains(turkishUpperCase(word));
  }

  /// Evaluate a guess against the target word
  List<LetterResult> evaluateGuess(String guess, String target) {
    guess = turkishUpperCase(guess);
    target = turkishUpperCase(target);
    
    final results = List<LetterResult>.filled(
      guess.length,
      LetterResult.wrong,
    );
    
    final targetLetters = target.split('').toList();
    final usedPositions = <int>{};

    // First pass: find correct positions
    for (int i = 0; i < guess.length; i++) {
      if (guess[i] == target[i]) {
        results[i] = LetterResult.correct;
        usedPositions.add(i);
      }
    }

    // Second pass: find wrong positions
    for (int i = 0; i < guess.length; i++) {
      if (results[i] == LetterResult.correct) continue;

      for (int j = 0; j < targetLetters.length; j++) {
        if (!usedPositions.contains(j) && guess[i] == targetLetters[j]) {
          results[i] = LetterResult.wrongPosition;
          usedPositions.add(j);
          break;
        }
      }
    }

    return results;
  }

  List<String> _getFallbackWords(int length) {
    switch (length) {
      case 4:
        return ['KALE', 'MASA', 'YAZI', 'OKUL', 'GECE'];
      case 5:
        return ['KALEM', 'ARABA', 'BEYAZ', 'KİTAP', 'GÜNEŞ'];
      case 6:
        return ['KELİME', 'OYUNCU', 'MUTFAK', 'MARKET', 'BALKON'];
      case 7:
        return ['PROGRAM', 'KAPLICA', 'TOPLAMA', 'OTOPARK', 'YAZILIM'];
      default:
        return ['KALEM', 'ARABA', 'BEYAZ', 'KİTAP', 'GÜNEŞ'];
    }
  }

  DateTime getNextDailyResetTime() {
    final turkeyNow = DateTime.now().toUtc().add(const Duration(hours: 3));
    final tomorrow = turkeyNow.add(const Duration(days: 1));
    // Reset at midnight Turkey time
    final resetTime = DateTime.utc(tomorrow.year, tomorrow.month, tomorrow.day)
        .subtract(const Duration(hours: 3)); // Convert back to UTC
    return resetTime;
  }
}

enum LetterResult {
  correct,
  wrongPosition,
  wrong,
}
