import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

/// Matchmaking service provider
final matchmakingServiceProvider = Provider<MatchmakingService>((ref) {
  return MatchmakingService(ref);
});

/// Current matchmaking state
final matchmakingStateProvider = StateProvider<MatchmakingState>((ref) {
  return MatchmakingState.idle;
});

/// Matchmaking states
enum MatchmakingState {
  idle,
  searching,
  matched,
  error
}

/// Matchmaking service for online 1v1
class MatchmakingService {
  final Ref _ref;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  String? _currentQueueId;
  
  MatchmakingService(this._ref);

  /// Join matchmaking queue
  Future<String?> joinQueue(String language) async {
    final user = _ref.read(currentUserProvider);
    print('[Matchmaking] joinQueue called, user: ${user?.uid ?? "NULL"}');
    
    if (user == null) {
      print('[Matchmaking] ERROR: User not authenticated!');
      return null;
    }

    // Get user rating from Firestore
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final rating = userDoc.data()?['rating'] ?? 200;
    print('[Matchmaking] User rating: $rating');

    // Check if already in queue
    final existingQuery = await _db
        .collection('matchmaking')
        .doc(language)
        .collection('queue')
        .where('uid', isEqualTo: user.uid)
        .get();
    
    // Remove existing entries
    for (final doc in existingQuery.docs) {
      await doc.reference.delete();
    }

    // Add to queue
    final queueRef = _db.collection('matchmaking').doc(language).collection('queue');
    final docRef = await queueRef.add({
      'uid': user.uid,
      'displayName': user.displayName ?? 'Player',
      'rating': rating,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    _currentQueueId = docRef.id;
    _ref.read(matchmakingStateProvider.notifier).state = MatchmakingState.searching;
    
    return docRef.id;
  }

  /// Leave queue
  Future<void> leaveQueue(String language) async {
    if (_currentQueueId == null) return;
    
    try {
      await _db
        .collection('matchmaking')
        .doc(language)
        .collection('queue')
        .doc(_currentQueueId)
        .delete();
    } catch (e) {
      // Ignore errors
    }
    
    _currentQueueId = null;
    _ref.read(matchmakingStateProvider.notifier).state = MatchmakingState.idle;
  }

  /// Find opponent - simpler query without composite index requirement
  Future<Map<String, dynamic>?> findOpponent(String language, int myRating) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return null;

    final queueRef = _db.collection('matchmaking').doc(language).collection('queue');
    
    // Simple query: just get all players in queue, sorted by timestamp (first come first serve)
    final snapshot = await queueRef
      .orderBy('timestamp')
      .limit(20)
      .get();

    // Find first player that isn't me and has similar rating (±200)
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final uid = data['uid'] as String?;
      final oppRating = data['rating'] as int? ?? 200;
      
      if (uid != null && uid != user.uid) {
        // Check rating difference
        if ((oppRating - myRating).abs() <= 200) {
          return {
            'docId': doc.id,
            ...data,
          };
        }
      }
    }
    
    // If no similar rating found, try anyone
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final uid = data['uid'] as String?;
      
      if (uid != null && uid != user.uid) {
        return {
          'docId': doc.id,
          ...data,
        };
      }
    }
    
    return null;
  }

  /// Create game with opponent (with transaction to prevent race condition)
  Future<String?> createGame({
    required String language,
    required Map<String, dynamic> player1,
    required Map<String, dynamic> player2,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return null;

    try {
      // Use transaction to prevent race conditions
      final result = await _db.runTransaction<String?>((transaction) async {
        final queueRef = _db.collection('matchmaking').doc(language).collection('queue');
        
        // Check if opponent is still in queue
        final opponentDoc = await transaction.get(queueRef.doc(player2['docId']));
        if (!opponentDoc.exists) {
          // Opponent already matched with someone else
          return null;
        }
        
        // Create game
        final gameRef = _db.collection('games').doc();
        transaction.set(gameRef, {
          'player1': {
            'uid': player1['uid'],
            'displayName': player1['displayName'],
            'rating': player1['rating'],
          },
          'player2': {
            'uid': player2['uid'],
            'displayName': player2['displayName'],
            'rating': player2['rating'],
          },
          'players': [player1['uid'], player2['uid']],
          'language': language,
          'currentRound': 1,
          'totalRounds': 3,
          'status': 'playing',
          'createdAt': FieldValue.serverTimestamp(),
          'rounds': {},
        });
        
        // Remove both players from queue
        if (_currentQueueId != null) {
          transaction.delete(queueRef.doc(_currentQueueId));
        }
        transaction.delete(queueRef.doc(player2['docId']));
        
        return gameRef.id;
      });
      
      if (result != null) {
        _currentQueueId = null;
        _ref.read(matchmakingStateProvider.notifier).state = MatchmakingState.matched;
      }
      
      return result;
    } catch (e) {
      print('Error creating game: $e');
      return null;
    }
  }
}
