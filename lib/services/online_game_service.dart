import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import 'word_service.dart';
import 'firestore_service.dart';
import '../models/models.dart';
import '../core/utils/turkish_utils.dart';

/// Online game service provider
final onlineGameServiceProvider = Provider<OnlineGameService>((ref) {
  return OnlineGameService(ref);
});

String obfuscateWord(String word, String gameId) {
  final keyBytes = utf8.encode(gameId);
  final wordBytes = utf8.encode(word);
  final result = List<int>.generate(wordBytes.length, (i) => wordBytes[i] ^ keyBytes[i % keyBytes.length]);
  return base64Encode(result);
}

String deobfuscateWord(String encoded, String gameId) {
  final keyBytes = utf8.encode(gameId);
  final decoded = base64Decode(encoded);
  final result = List<int>.generate(decoded.length, (i) => decoded[i] ^ keyBytes[i % keyBytes.length]);
  return utf8.decode(result);
}

/// Current online game ID
final currentOnlineGameIdProvider = StateProvider<String?>((ref) => null);

/// Online game session state
final onlineGameSessionProvider = StreamProvider.family<OnlineGameSession?, String>((ref, gameId) {
  final service = ref.watch(onlineGameServiceProvider);
  return service.watchGame(gameId);
});

/// Online game states
enum OnlineGameStatus {
  waiting,
  playing,
  roundEnd,
  finished,
  disconnected
}

/// Online game session model
class OnlineGameSession {
  final String gameId;
  final PlayerInfo player1;
  final PlayerInfo player2;
  final String language;
  final int currentRound;
  final int totalRounds;
  final OnlineGameStatus status;
  final Map<int, RoundData> rounds;
  final GameResult? result;

  OnlineGameSession({
    required this.gameId,
    required this.player1,
    required this.player2,
    required this.language,
    required this.currentRound,
    required this.totalRounds,
    required this.status,
    required this.rounds,
    this.result,
  });

  factory OnlineGameSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final roundsData = data['rounds'] as Map<String, dynamic>? ?? {};
    final rounds = <int, RoundData>{};
    roundsData.forEach((key, value) {
      rounds[int.parse(key)] = RoundData.fromMap(value, doc.id);
    });

    return OnlineGameSession(
      gameId: doc.id,
      player1: PlayerInfo.fromMap(data['player1']),
      player2: PlayerInfo.fromMap(data['player2']),
      language: data['language'] ?? 'tr',
      currentRound: data['currentRound'] ?? 1,
      totalRounds: data['totalRounds'] ?? 3,
      status: _parseStatus(data['status']),
      rounds: rounds,
      result: data['result'] != null ? GameResult.fromMap(data['result']) : null,
    );
  }

  static OnlineGameStatus _parseStatus(String? status) {
    switch (status) {
      case 'waiting': return OnlineGameStatus.waiting;
      case 'playing': return OnlineGameStatus.playing;
      case 'roundEnd': return OnlineGameStatus.roundEnd;
      case 'finished': return OnlineGameStatus.finished;
      case 'disconnected': return OnlineGameStatus.disconnected;
      default: return OnlineGameStatus.waiting;
    }
  }

  bool get isMyTurn => true; // Simplified - both play simultaneously
  
  RoundData? get currentRoundData => rounds[currentRound];
}

/// Player info
class PlayerInfo {
  final String uid;
  final String displayName;
  final int rating;

  PlayerInfo({
    required this.uid,
    required this.displayName,
    required this.rating,
  });

  factory PlayerInfo.fromMap(Map<String, dynamic> map) {
    return PlayerInfo(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? 'Player',
      rating: map['rating'] ?? 200,
    );
  }
}

/// Round data
class RoundData {
  final int wordLength;
  final String? targetWord; // Only visible after round ends
  final PlayerRoundData player1;
  final PlayerRoundData player2;

  RoundData({
    required this.wordLength,
    this.targetWord,
    required this.player1,
    required this.player2,
  });

  factory RoundData.fromMap(Map<String, dynamic> map, String gameId) {
    return RoundData(
      wordLength: map['wordLength'] ?? 5,
      targetWord: map['targetWord'] != null ? deobfuscateWord(map['targetWord'], gameId) : null,
      player1: PlayerRoundData.fromMap(map['player1'] ?? {}),
      player2: PlayerRoundData.fromMap(map['player2'] ?? {}),
    );
  }

  // Helper getters
  List<String> get player1Guesses => player1.guesses;
  List<String> get player2Guesses => player2.guesses;
  bool get player1Complete => player1.finished;
  bool get player2Complete => player2.finished;
}

/// Player round data
class PlayerRoundData {
  final List<String> guesses;
  final int score;
  final bool finished;
  final bool won;

  PlayerRoundData({
    required this.guesses,
    required this.score,
    required this.finished,
    required this.won,
  });

  factory PlayerRoundData.fromMap(Map<String, dynamic> map) {
    return PlayerRoundData(
      guesses: List<String>.from(map['guesses'] ?? []),
      score: map['score'] ?? 0,
      finished: map['finished'] ?? false,
      won: map['won'] ?? false,
    );
  }
}

/// Game result
class GameResult {
  final String? winnerUid;
  final int player1Score;
  final int player2Score;
  final int ratingChange1;
  final int ratingChange2;

  GameResult({
    this.winnerUid,
    required this.player1Score,
    required this.player2Score,
    required this.ratingChange1,
    required this.ratingChange2,
  });

  factory GameResult.fromMap(Map<String, dynamic> map) {
    return GameResult(
      winnerUid: map['winnerUid'],
      player1Score: map['player1Score'] ?? 0,
      player2Score: map['player2Score'] ?? 0,
      ratingChange1: map['ratingChange1'] ?? 0,
      ratingChange2: map['ratingChange2'] ?? 0,
    );
  }
}

/// Online game service
class OnlineGameService {
  final Ref _ref;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final WordService _wordService = WordService();
  
  OnlineGameService(this._ref);

  /// Watch game stream
  Stream<OnlineGameSession?> watchGame(String gameId) {
    return _db.collection('games').doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return OnlineGameSession.fromFirestore(doc);
    });
  }

  /// Start a round (set target word)
  Future<void> startRound(String gameId, int roundNumber) async {
    // Random word length 4-6
    final random = Random();
    final wordLength = 4 + random.nextInt(3); // 4, 5, or 6
    
    // Get game for language
    final gameDoc = await _db.collection('games').doc(gameId).get();
    final language = gameDoc.data()?['language'] ?? 'tr';
    
    // Load words and pick random
    await _wordService.loadWords(wordLength, language: language);
    final targetWord = _wordService.getRandomWord(wordLength);

    await _db.collection('games').doc(gameId).update({
      'rounds.$roundNumber': {
        'wordLength': wordLength,
        'targetWord': obfuscateWord(targetWord, gameId),
        'player1': {'guesses': [], 'score': 0, 'finished': false, 'won': false},
        'player2': {'guesses': [], 'score': 0, 'finished': false, 'won': false},
      },
      'currentRound': roundNumber, // Update current round
      'status': 'playing',
    });
  }


  Future<GuessResult> submitGuess(String gameId, String guess) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      return GuessResult(valid: false, message: 'Not authenticated');
    }

    final gameDoc = await _db.collection('games').doc(gameId).get();
    final data = gameDoc.data();
    if (data == null) {
      return GuessResult(valid: false, message: 'Game not found');
    }

    final isPlayer1 = data['player1']['uid'] == user.uid;
    final playerKey = isPlayer1 ? 'player1' : 'player2';
    final currentRound = data['currentRound'];
    final roundData = data['rounds']['$currentRound'];
    
    if (roundData == null) {
      return GuessResult(valid: false, message: 'Round not started');
    }

    // NORMALIZE STRINGS
    final rawTarget = deobfuscateWord(roundData['targetWord'] as String, gameId);
    final targetWord = turkishUpperCase(rawTarget);
    final normalizedGuess = guess.isEmpty ? '' : turkishUpperCase(guess);
    
    final guesses = List<String>.from(roundData[playerKey]['guesses'] ?? []);
    
    // Check if already finished
    if (roundData[playerKey]['finished'] == true) {
      return GuessResult(valid: false, message: 'Already finished this round');
    }

    // Check if duplicate guess (unless empty/timeout)
    // Note: stored guesses might be mixed case, so we should check normalized
    if (normalizedGuess.isNotEmpty && guesses.any((g) => turkishUpperCase(g) == normalizedGuess)) {
      return GuessResult(valid: false, message: 'Already guessed this word');
    }

    // Handle timeout/giveup (empty guess)
    if (normalizedGuess.isEmpty) {
      await _db.collection('games').doc(gameId).update({
        'rounds.$currentRound.$playerKey.finished': true,
        // Keep existing score (likely 0 if they timed out)
      });
      
      await _checkRoundComplete(gameId, currentRound);
      
      return GuessResult(
        valid: true, 
        correct: false,
        message: 'Time expired',
      );
    }

    // Validate guess length
    if (normalizedGuess.length != targetWord.length) {
      return GuessResult(valid: false, message: 'Invalid word length');
    }

    // Add guess (store original or normalized? Storing normalized is safer for consistent display)
    guesses.add(normalizedGuess);
    
    // Check if won
    final won = normalizedGuess == targetWord;
    final finished = won || guesses.length >= 6;
    final score = won ? _calculateScore(guesses.length) : 0;

    // Update Firestore
    await _db.collection('games').doc(gameId).update({
      'rounds.$currentRound.$playerKey.guesses': guesses,
      'rounds.$currentRound.$playerKey.won': won,
      'rounds.$currentRound.$playerKey.finished': finished,
      'rounds.$currentRound.$playerKey.score': score,
    });

    // Check if both players finished
    await _checkRoundComplete(gameId, currentRound);

    return GuessResult(
      valid: true,
      correct: won,
      letterStates: _getLetterStates(normalizedGuess, targetWord),
    );
  }

  /// Calculate score based on guess number
  int _calculateScore(int guessNumber) {
    const scores = [100, 90, 75, 55, 30, 10];
    if (guessNumber <= 0 || guessNumber > 6) return 0;
    return scores[guessNumber - 1];
  }

  /// Get letter states for guess
  Map<int, LetterState> _getLetterStates(String guess, String target) {
    final states = <int, LetterState>{};
    final targetChars = target.split('');
    final guessChars = guess.split('');
    final used = List<bool>.filled(target.length, false);

    // First pass: correct positions
    for (var i = 0; i < guessChars.length; i++) {
      if (guessChars[i] == targetChars[i]) {
        states[i] = LetterState.correct;
        used[i] = true;
      }
    }

    // Second pass: wrong positions
    for (var i = 0; i < guessChars.length; i++) {
      if (states[i] == LetterState.correct) continue;
      
      var found = false;
      for (var j = 0; j < targetChars.length; j++) {
        if (!used[j] && guessChars[i] == targetChars[j]) {
          states[i] = LetterState.wrongPosition;
          used[j] = true;
          found = true;
          break;
        }
      }
      
      if (!found) {
        states[i] = LetterState.wrong;
      }
    }

    return states;
  }

  /// Check if round is complete
  Future<void> _checkRoundComplete(String gameId, int roundNumber) async {
    final gameDoc = await _db.collection('games').doc(gameId).get();
    final data = gameDoc.data();
    if (data == null) return;

    final roundData = data['rounds']['$roundNumber'];
    final p1Finished = roundData['player1']['finished'] == true;
    final p2Finished = roundData['player2']['finished'] == true;

    if (p1Finished && p2Finished) {
      final totalRounds = data['totalRounds'];
      
      if (roundNumber >= totalRounds) {
        // Game over
        await completeGame(gameId);
      } else {
        // Next round
        await _db.collection('games').doc(gameId).update({
          'currentRound': roundNumber + 1,
          'status': 'roundEnd',
        });
        
        // Start next round after delay
        Future.delayed(const Duration(seconds: 3), () {
          startRound(gameId, roundNumber + 1);
        });
      }
    }
  }

  /// Finish game and calculate ratings
  Future<void> completeGame(String gameId) async {
    bool newlyFinished = false;
    Map<String, dynamic> finalData = {};
    String? winnerUid;
    int p1Total = 0;
    int p2Total = 0;

    await _db.runTransaction((transaction) async {
      final gameRef = _db.collection('games').doc(gameId);
      final gameDoc = await transaction.get(gameRef);
      final data = gameDoc.data();
      if (data == null) return;
      if (data['status'] == 'finished') return;

      newlyFinished = true;
      finalData = data;

      // Calculate total scores
      final rounds = data['rounds'] as Map<String, dynamic>;
      rounds.forEach((key, value) {
        p1Total += (value['player1']['score'] as int?) ?? 0;
        p2Total += (value['player2']['score'] as int?) ?? 0;
      });

      // Determine winner
      if (p1Total > p2Total) {
        winnerUid = data['player1']['uid'];
      } else if (p2Total > p1Total) {
        winnerUid = data['player2']['uid'];
      }
      // If equal, winnerUid is null (Draw)

      // Calculate rating changes
      final p1Rating = data['player1']['rating'] as int;
      final p2Rating = data['player2']['rating'] as int;
      
      int ratingChange1;
      int ratingChange2;
      
      if (winnerUid == null) {
        ratingChange1 = 0;
        ratingChange2 = 0;
      } else {
        final p1Won = winnerUid == data['player1']['uid'];
        ratingChange1 = _calculateRatingChange(p1Rating, p2Rating, p1Won ? 1.0 : 0.0);
        ratingChange2 = _calculateRatingChange(p2Rating, p1Rating, !p1Won ? 1.0 : 0.0);
      }

      final p1NewRating = ((data['player1']['rating'] as int? ?? 200) + ratingChange1).clamp(0, 999999);
      final p2NewRating = ((data['player2']['rating'] as int? ?? 200) + ratingChange2).clamp(0, 999999);

      transaction.update(gameRef, {
        'status': 'finished',
        'result': {
          'winnerUid': winnerUid,
          'player1Score': p1Total,
          'player2Score': p2Total,
          'ratingChange1': ratingChange1,
          'ratingChange2': ratingChange2,
          'draw': winnerUid == null,
        },
      });

      final user1Ref = _db.collection('users').doc(data['player1']['uid']);
      final user2Ref = _db.collection('users').doc(data['player2']['uid']);
      transaction.update(user1Ref, {'rating': p1NewRating});
      transaction.update(user2Ref, {'rating': p2NewRating});
    });

    if (newlyFinished) {
      final firestoreService = _ref.read(firestoreServiceProvider);
      await firestoreService.updateGameStats(
        uid: finalData['player1']['uid'],
        won: winnerUid == finalData['player1']['uid'], 
        score: p1Total,
      );
      await firestoreService.updateGameStats(
        uid: finalData['player2']['uid'],
        won: winnerUid == finalData['player2']['uid'],
        score: p2Total,
      );
    }
  }

  /// Simplified Elo rating change
  /// [actualScore]: 1.0 for win, 0.0 for loss, 0.5 for draw
  int _calculateRatingChange(int myRating, int opponentRating, double actualScore) {
    const k = 32;
    final expected = 1 / (1 + pow(10, (opponentRating - myRating) / 400));
    return (k * (actualScore - expected)).round();
  }

  /// Forfeit game
  Future<void> forfeit(String gameId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final gameDoc = await _db.collection('games').doc(gameId).get();
    final data = gameDoc.data();
    if (data == null) return;

    final isPlayer1 = data['player1']['uid'] == user.uid;
    final opponentUid = isPlayer1 ? data['player2']['uid'] : data['player1']['uid'];

    // Calculate forfeit rating change (loser loses more)
    final myRating = isPlayer1 ? data['player1']['rating'] : data['player2']['rating'];
    final oppRating = isPlayer1 ? data['player2']['rating'] : data['player1']['rating'];
    
    final ratingChange = _calculateRatingChange(myRating, oppRating, 0.0);
    final oppRatingChange = (_calculateRatingChange(oppRating, myRating, 1.0) * 2 / 3).round();

    int p1Total = 0;
    int p2Total = 0;
    final rounds = data['rounds'] as Map<String, dynamic>? ?? {};
    rounds.forEach((key, value) {
      p1Total += (value['player1']['score'] as int?) ?? 0;
      p2Total += (value['player2']['score'] as int?) ?? 0;
    });

    await _db.collection('games').doc(gameId).update({
      'status': 'finished',
      'result': {
        'winnerUid': opponentUid,
        'player1Score': isPlayer1 ? p1Total : 999,
        'player2Score': isPlayer1 ? 999 : p2Total,
        'ratingChange1': isPlayer1 ? ratingChange : oppRatingChange,
        'ratingChange2': isPlayer1 ? oppRatingChange : ratingChange,
        'forfeit': true,
      },
    });

    // Update ratings
    await _db.collection('users').doc(user.uid).update({
      'rating': FieldValue.increment(ratingChange),
    });
    await _db.collection('users').doc(opponentUid).update({
      'rating': FieldValue.increment(oppRatingChange),
    });

    // Update user stats
    final firestoreService = _ref.read(firestoreServiceProvider);
    await firestoreService.updateGameStats(
      uid: user.uid,
      won: false,
      score: 0,
    );
    await firestoreService.updateGameStats(
      uid: opponentUid,
      won: true,
      score: isPlayer1 ? p2Total : p1Total,
    );
  }

  /// Update player's last activity timestamp
  Future<void> updateActivity(String gameId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final gameDoc = await _db.collection('games').doc(gameId).get();
    final data = gameDoc.data();
    if (data == null) return;

    final isPlayer1 = data['player1']['uid'] == user.uid;
    final playerKey = isPlayer1 ? 'player1Activity' : 'player2Activity';

    await _db.collection('games').doc(gameId).update({
      playerKey: FieldValue.serverTimestamp(),
    });
  }

  /// Check if opponent is still active (last activity within 30 seconds)
  Future<bool> checkOpponentActivity(String gameId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return true;

    final gameDoc = await _db.collection('games').doc(gameId).get();
    final data = gameDoc.data();
    if (data == null) return true;

    final isPlayer1 = data['player1']['uid'] == user.uid;
    final opponentActivityKey = isPlayer1 ? 'player2Activity' : 'player1Activity';

    final opponentActivity = data[opponentActivityKey] as Timestamp?;
    if (opponentActivity == null) return true; // No activity recorded yet

    final lastActiveSeconds = DateTime.now().difference(opponentActivity.toDate()).inSeconds;
    return lastActiveSeconds <= 30; // Consider disconnected if no activity for 30 seconds
  }

  /// Claim win due to opponent disconnect
  Future<void> claimDisconnectWin(String gameId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final gameDoc = await _db.collection('games').doc(gameId).get();
    final data = gameDoc.data();
    if (data == null) return;

    // Check game is still active
    if (data['status'] == 'finished') return;

    final isPlayer1 = data['player1']['uid'] == user.uid;
    final opponentUid = isPlayer1 ? data['player2']['uid'] : data['player1']['uid'];

    // Calculate reduced rating change for disconnect win (2/3 of normal)
    final myRating = isPlayer1 ? data['player1']['rating'] as int : data['player2']['rating'] as int;
    final oppRating = isPlayer1 ? data['player2']['rating'] as int : data['player1']['rating'] as int;
    
    final fullRatingChange = _calculateRatingChange(myRating, oppRating, 1.0);
    final reducedRatingChange = (fullRatingChange * 2 / 3).round();
    final oppRatingChange = _calculateRatingChange(oppRating, myRating, 0.0);

    await _db.collection('games').doc(gameId).update({
      'status': 'finished',
      'result': {
        'winnerUid': user.uid,
        'player1Score': isPlayer1 ? 999 : 0,
        'player2Score': isPlayer1 ? 0 : 999,
        'ratingChange1': isPlayer1 ? reducedRatingChange : oppRatingChange,
        'ratingChange2': isPlayer1 ? oppRatingChange : reducedRatingChange,
        'disconnectWin': true,
      },
    });

    // Update ratings
    await _db.collection('users').doc(user.uid).update({
      'rating': FieldValue.increment(reducedRatingChange),
    });
    await _db.collection('users').doc(opponentUid).update({
      'rating': FieldValue.increment(oppRatingChange),
    });

    // Update user stats
    final firestoreService = _ref.read(firestoreServiceProvider);
    await firestoreService.updateGameStats(
      uid: user.uid,
      won: true,
      score: 0, // Or some default disconnect win score?
    );
    await firestoreService.updateGameStats(
      uid: opponentUid,
      won: false,
      score: 0,
    );
  }
}

/// Guess result
class GuessResult {
  final bool valid;
  final bool correct;
  final String? message;
  final Map<int, LetterState> letterStates;

  GuessResult({
    required this.valid,
    this.correct = false,
    this.message,
    this.letterStates = const {},
  });
}

