import 'dart:async';
import 'package:flutter/material.dart';
import '../core/utils/turkish_utils.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_colors.dart';
import '../services/matchmaking_service.dart';
import '../services/online_game_service.dart';
import '../services/word_service.dart';
import '../services/auth_service.dart';
import '../widgets/game_keyboard.dart';
import '../models/models.dart';
import '../providers/game_provider.dart';

class OnlineGameScreen extends ConsumerStatefulWidget {
  final String? gameId;
  
  const OnlineGameScreen({super.key, this.gameId});

  @override
  ConsumerState<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends ConsumerState<OnlineGameScreen> with WidgetsBindingObserver {
  String? _gameId;
  bool _isSearching = false;
  Timer? _searchTimer;
  int _searchSeconds = 0;
  
  // Game state
  String _currentGuess = '';
  Map<String, LetterState> _keyboardState = {};
  String _language = 'tr';
  
  // Timer for each guess (20 seconds)
  Timer? _guessTimer;
  int _remainingSeconds = 20;
  static const int _maxGuessTime = 20;
  
  // Disconnect handling
  Timer? _disconnectCheckTimer;
  bool _opponentDisconnected = false;
  
  // Validation state
  bool _showInvalid = false;
  bool _matchFound = false;
  bool _isRoundDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameId = widget.gameId;
    if (_gameId == null) {
      _startMatchmaking();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchTimer?.cancel();
    _guessTimer?.cancel();
    _disconnectCheckTimer?.cancel();
    _gameInviteSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // User backgrounded the app - update last activity
      _updateMyActivity();
    } else if (state == AppLifecycleState.resumed) {
      // User returned to the app
      _updateMyActivity();
    }
  }

  void _updateMyActivity() async {
    if (_gameId == null) return;
    final onlineGame = ref.read(onlineGameServiceProvider);
    await onlineGame.updateActivity(_gameId!);
  }

  void _startGuessTimer() {
    _guessTimer?.cancel();
    setState(() => _remainingSeconds = _maxGuessTime);
    
    _guessTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _onTimerExpired();
        }
      });
    });
  }

  void _onTimerExpired() {
    // Auto-submit empty guess (counts as failed attempt)
    if (_gameId != null) {
      _submitGuess(forceEmpty: true);
    }
  }

  void _showInvalidWordWarning() {
    setState(() => _showInvalid = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showInvalid = false);
    });
  }

  void _startMatchmaking() async {
    setState(() {
      _isSearching = true;
      _searchSeconds = 0;
    });
    
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _searchSeconds++);
    });

    // Check if user is logged in
    var user = ref.read(currentUserProvider);
    if (user == null) {
      print('[Online] User not logged in, cannot start matchmaking');
      _cancelSearch();
      return;
    }

    final matchmaking = ref.read(matchmakingServiceProvider);
    
    await matchmaking.joinQueue(_language);
    
    // Start both: actively searching AND listening for being matched
    _pollForOpponent(_language);
    _listenForGameInvite();
  }

  StreamSubscription? _gameInviteSubscription;

  void _listenForGameInvite() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    print('[Online] Listening for games where I am a player...');
    
    // Simplified query - only arrayContains, no composite index needed
    _gameInviteSubscription = FirebaseFirestore.instance
        .collection('games')
        .where('players', arrayContains: user.uid)
        .snapshots()
        .listen((snapshot) {
      print('[Online] Games snapshot received: ${snapshot.docs.length} games');
      
      if (snapshot.docs.isNotEmpty && _isSearching && _gameId == null) {
        // Find newest game with status 'playing'
        // ignore zombie games (no activity for > 60s)
        for (final gameDoc in snapshot.docs) {
          final data = gameDoc.data();
          final status = data['status'];
          
          // Check for stale game
          final p1Activity = data['player1Activity'] as Timestamp?;
          final p2Activity = data['player2Activity'] as Timestamp?;
          final now = DateTime.now();
          final lastActivity = p1Activity?.toDate().isAfter(p2Activity?.toDate() ?? DateTime(2000)) == true 
              ? p1Activity?.toDate() 
              : p2Activity?.toDate();
              
          final isStale = lastActivity != null && now.difference(lastActivity).inSeconds > 60;
          
          print('[Online] Found game ${gameDoc.id} with status: $status, stale: $isStale');
          
          if (status == 'playing' && !isStale) {
            if (_matchFound) return;
            _matchFound = true;
            print('[Online] Joining game: ${gameDoc.id}');
            setState(() {
              _gameId = gameDoc.id;
              _isSearching = false;
            });
            _searchTimer?.cancel();
            _gameInviteSubscription?.cancel();
            _startGuessTimer();
            _startDisconnectCheck();
            break;
          }
        }
      }
    }, onError: (e) {
      print('[Online] Game listener error: $e');
    });
  }

  void _pollForOpponent(String language) async {
    final matchmaking = ref.read(matchmakingServiceProvider);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final myRating = userDoc.data()?['rating'] ?? 200;

    while (_isSearching && _gameId == null) {
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if already matched via listener
      if (_gameId != null || !_isSearching) break;
      
      final opponent = await matchmaking.findOpponent(language, myRating);
      
      if (opponent != null && _isSearching && _gameId == null) {
        final gameId = await matchmaking.createGame(
          language: language,
          player1: {
            'uid': user.uid,
            'displayName': user.displayName ?? 'Player',
            'rating': myRating,
            'docId': '',
          },
          player2: opponent,
        );
        
        if (gameId != null) {
          if (_matchFound) return;
          _matchFound = true;
          _gameInviteSubscription?.cancel();
          setState(() {
            _gameId = gameId;
            _isSearching = false;
            _language = language;
          });
          _searchTimer?.cancel();
          
          final onlineGame = ref.read(onlineGameServiceProvider);
          await onlineGame.startRound(gameId, 1);
          _startGuessTimer();
          _startDisconnectCheck();
        }
      }
    }
  }

  void _startDisconnectCheck() {
    _disconnectCheckTimer?.cancel();

    // Periodically send our own heartbeat so the opponent's check passes.
    _disconnectCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_gameId == null) {
        timer.cancel();
        return;
      }

      // Update our own activity
      _updateMyActivity();

      // Check opponent activity (disconnected if silent > 30 s)
      final onlineGame = ref.read(onlineGameServiceProvider);
      final isOpponentActive = await onlineGame.checkOpponentActivity(_gameId!);

      if (!isOpponentActive && !_opponentDisconnected && mounted) {
        setState(() => _opponentDisconnected = true);
        _showOpponentDisconnectedDialog();
      }
    });
  }

  void _showOpponentDisconnectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: AppColors.warning),
            const SizedBox(width: 12),
            Text('Bağlantı Kesildi', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          'Rakibinizin bağlantısı kesildi.\n30 saniye içinde dönmezse kazanırsınız!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _claimDisconnectWin();
            },
            child: Text('Galibiyeti Al', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _claimDisconnectWin() async {
    if (_gameId == null) return;
    final onlineGame = ref.read(onlineGameServiceProvider);
    await onlineGame.claimDisconnectWin(_gameId!);
    if (mounted) context.go('/home');
  }

  void _cancelSearch() {
    final matchmaking = ref.read(matchmakingServiceProvider);
    matchmaking.leaveQueue(_language);
    
    _searchTimer?.cancel();
    setState(() => _isSearching = false);
    
    context.pop();
  }

  void _onKeyPressed(String key) {
    // Disable input if timer expired
    if (_remainingSeconds <= 0) return;
    
    final gameAsync = ref.read(onlineGameSessionProvider(_gameId!));
    final game = gameAsync.value;
    if (game == null) return;
    
    final wordLength = game.currentRoundData?.wordLength ?? 5;
    if (_currentGuess.length < wordLength) {
      setState(() {
        _currentGuess += key; // Don't lowerCase here, let turkishUpperCase handle it later
      });
    }
  }

  void _onBackspace() {
    // Disable input if timer expired
    if (_remainingSeconds <= 0) return;
    
    if (_currentGuess.isNotEmpty) {
      setState(() {
        _currentGuess = _currentGuess.substring(0, _currentGuess.length - 1);
      });
    }
  }

  void _onEnter() {
    // Disable input if timer expired
    if (_remainingSeconds <= 0) return;
    
    final gameAsync = ref.read(onlineGameSessionProvider(_gameId!));
    final game = gameAsync.value;
    if (game == null) return;
    
    final wordLength = game.currentRoundData?.wordLength ?? 5;
    if (_currentGuess.length == wordLength) {
      _submitGuess();
    }
  }

  void _submitGuess({bool forceEmpty = false}) async {
    if (_gameId == null) return;
    
    final onlineGame = ref.read(onlineGameServiceProvider);
    final guessToSubmit = forceEmpty ? '' : _currentGuess;
    
    // Local validation for non-empty guesses
    if (!forceEmpty && guessToSubmit.isNotEmpty) {
      final gameAsync = ref.read(onlineGameSessionProvider(_gameId!));
      final game = gameAsync.value;
      if (game != null) {
        final round = game.currentRoundData;
        final wordLength = round?.wordLength ?? 5;
        
        final wordService = ref.read(wordServiceProvider);
        // Ensure words are loaded
        await wordService.loadWords(wordLength, language: _language);
        
        if (!wordService.isValidWord(guessToSubmit)) {
          _showInvalidWordWarning();
          return;
        }
      }
    }
    
    final result = await onlineGame.submitGuess(_gameId!, guessToSubmit);
    
    if (result.valid) {
      if (!forceEmpty) {
        result.letterStates.forEach((index, state) {
          if (index < _currentGuess.length) {
            final letter = turkishUpperCase(_currentGuess[index]);
            final currentState = _keyboardState[letter];

            // Priority: Correct > WrongPosition > Wrong > null
            if (currentState == LetterState.correct) return;
            if (state == LetterState.correct) {
              _keyboardState[letter] = state;
              return;
            }
            if (state == LetterState.wrongPosition) {
              _keyboardState[letter] = state;
              return;
            }
            if (currentState == null && state == LetterState.wrong) {
              _keyboardState[letter] = state;
            }
          }
        });
      }

      setState(() {
        _currentGuess = '';
      });

      if (result.correct) {
        _guessTimer?.cancel();
        await _handleRoundComplete();
      } else if (forceEmpty) {
        // Timer expired — do NOT restart the timer; just report round-complete
        await _handleRoundComplete();
      } else {
        final gameAsync = ref.read(onlineGameSessionProvider(_gameId!));
        final game = gameAsync.value;
        if (game != null) {
          final round = game.currentRoundData;
          final user = ref.read(currentUserProvider);
          final isPlayer1 = game.player1.uid == user?.uid;
          final myGuesses = isPlayer1 ? round?.player1Guesses : round?.player2Guesses;

          if ((myGuesses?.length ?? 0) >= 6) {
            _guessTimer?.cancel();
            await _handleRoundComplete();
          } else {
            _startGuessTimer();
          }
        } else {
          _startGuessTimer();
        }
      }
    }
  }
  
  Future<void> _handleRoundComplete() async {
    if (_gameId == null) return;
    
    print('[Online] Handling round complete...');
    
    // Wait a moment for Firestore to sync
    await Future.delayed(const Duration(seconds: 2));
    
    final gameAsync = ref.read(onlineGameSessionProvider(_gameId!));
    final game = gameAsync.value;
    if (game == null) return;
    
    // Check if both players finished this round
    final round = game.currentRoundData;
    final player1Done = round?.player1Complete ?? false;
    final player2Done = round?.player2Complete ?? false;
    
    print('[Online] Player1 done: $player1Done, Player2 done: $player2Done');
    
    if (player1Done && player2Done) {
      // Both done - advance to next round or end game
      if (game.currentRound < game.totalRounds) {
        print('[Online] Moving to round ${game.currentRound + 1}');
        final onlineGame = ref.read(onlineGameServiceProvider);
        await onlineGame.startRound(_gameId!, game.currentRound + 1);
        
        // Reset state for new round
        setState(() {
          _currentGuess = '';
          _keyboardState = {};
        });
        _startGuessTimer();
      } else {
        // Game complete!
        print('[Online] Game complete!');
        final onlineGame = ref.read(onlineGameServiceProvider);
        await onlineGame.completeGame(_gameId!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gameId == null || _isSearching) {
      return _buildMatchmakingScreen();
    }
    
    return _buildGameScreen();
  }

  Widget _buildMatchmakingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(Theme.of(context).brightness),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _cancelSearch,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: AppColors.glassDecoration(borderRadius: 20),
                        child: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text('Online Eşleşme', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.primary,
                              ),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.1),
                              ),
                              child: const Icon(Icons.search, size: 32, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Rakip aranıyor...',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatTime(_searchSeconds),
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.w300, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 48),
                      OutlinedButton(
                        onPressed: _cancelSearch,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('İptal'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildGameScreen() {
    final gameAsync = ref.watch(onlineGameSessionProvider(_gameId!));
    
    ref.listen<AsyncValue<OnlineGameSession?>>(
      onlineGameSessionProvider(_gameId!),
      (previous, next) {
        final prevGame = previous?.value;
        final nextGame = next.value;
        
        if (prevGame != null && nextGame != null) {
          // Detect round change
          if (nextGame.currentRound > prevGame.currentRound) {
            // Show answer from previous round
            final prevRoundData = prevGame.rounds[prevGame.currentRound];
            if (prevRoundData != null) {
               final user = ref.read(currentUserProvider);
               final isPlayer1 = prevGame.player1.uid == user?.uid;
               final myData = isPlayer1 ? prevRoundData.player1 : prevRoundData.player2;
               
               _showRoundResultDialog(prevRoundData.targetWord ?? '???', myData.won);
            }

            setState(() {
              _currentGuess = '';
              _keyboardState = {};
              _remainingSeconds = _maxGuessTime;
            });
            _startGuessTimer();
          }
          
          // Detect game finish
          if (prevGame.status != OnlineGameStatus.finished && 
              nextGame.status == OnlineGameStatus.finished) {
            
            // Show answer for the last round if applicable
            // If game finished naturally (not stale/forfeit), show the last round's word
            final lastRoundData = nextGame.rounds[nextGame.currentRound];
            if (lastRoundData != null) {
               final user = ref.read(currentUserProvider);
               final isPlayer1 = nextGame.player1.uid == user?.uid;
               final myData = isPlayer1 ? lastRoundData.player1 : lastRoundData.player2;
               
               // Only show if we haven't shown it yet (round change handles intermediate rounds)
               // This handles the final round
               _showRoundResultDialog(lastRoundData.targetWord ?? '???', myData.won);
            }

            _guessTimer?.cancel();
            _disconnectCheckTimer?.cancel();
          }
        }
      },
    );
    
    return gameAsync.when(
      data: (game) {
        if (game == null) return _buildErrorScreen('Game not found');
        return _buildActiveGame(game);
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => _buildErrorScreen(e.toString()),
    );
  }

  void _showRoundResultDialog(String targetWord, bool won) {
    if (_isRoundDialogShowing) return;
    _isRoundDialogShowing = true;
    
    final definition = ref.read(wordServiceProvider).getDefinition(targetWord) ?? '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
        
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? 'Tebrikler!' : 'Süre Doldu!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: won ? AppColors.primary : AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Doğru Cevap:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(
                turkishUpperCase(targetWord),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              if (definition.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    definition,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) _isRoundDialogShowing = false;
    });
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(Theme.of(context).brightness),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(error, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Ana Sayfa'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveGame(OnlineGameSession game) {
    final user = ref.read(currentUserProvider);
    final isPlayer1 = game.player1.uid == user?.uid;
    final opponentInfo = isPlayer1 ? game.player2 : game.player1;
    final currentRound = game.currentRoundData;
    final myData = currentRound != null ? (isPlayer1 ? currentRound.player1 : currentRound.player2) : null;

    if (game.status == OnlineGameStatus.finished) {
      return _buildResultScreen(game, isPlayer1);
    }

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFF102216), // Match background
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => _showForfeitDialog(game.gameId),
            child: Container(
              width: 40,
              height: 40,
              decoration: AppColors.glassDecoration(borderRadius: 20),
              child: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
            ),
          ),
        ),
        title: Text(
          'Tur ${game.currentRound}/${game.totalRounds}',
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        actions: [
          // Timer display
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _remainingSeconds <= 3 ? AppColors.error.withValues(alpha: 0.2) : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer, 
                  size: 18, 
                  color: _remainingSeconds <= 3 ? AppColors.error : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_remainingSeconds',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _remainingSeconds <= 3 ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(Theme.of(context).brightness),
        ),
        child: currentRound == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  _buildOpponentBar(opponentInfo, currentRound, isPlayer1),
                  const Divider(color: AppColors.surface, height: 1),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _buildGameArea(currentRound, isPlayer1),
                        if (_showInvalid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Kelime Listesinde Yok',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (myData != null && !myData.finished)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: GameKeyboard(
                        keyboardState: _keyboardState,
                        onEnter: _onEnter,
                        onBackspace: _onBackspace,
                        onKeyPressed: _onKeyPressed,
                        language: _language,
                        enabled: !myData.finished,
                      ),
                    )
                  else
                    _buildRoundCompleteMessage(myData),
                ],
              ),
      ),
    );
  }

  Widget _buildRoundCompleteMessage(PlayerRoundData? myData) {
    if (myData == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            myData.won ? Icons.check_circle : Icons.cancel,
            size: 48,
            color: myData.won ? AppColors.primary : AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(
            myData.won ? 'Harika! +${myData.score} puan' : 'Bir dahaki sefere!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: myData.won ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 12),
          const Text(
            'Rakip bekleniyor...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentBar(PlayerInfo opponent, RoundData round, bool isPlayer1) {
    final oppData = isPlayer1 ? round.player2 : round.player1;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surface,
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceLight,
                child: const Icon(Icons.person, color: AppColors.textMuted),
              ),
              if (_opponentDisconnected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent.displayName,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Puan: ${opponent.rating}',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: oppData.finished
                  ? (oppData.won ? AppColors.primary : AppColors.error).withValues(alpha: 0.2)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              oppData.finished
                  ? (oppData.won ? 'Bildi! ✓' : 'Bilemedi')
                  : '${oppData.guesses.length}/6',
              style: TextStyle(
                color: oppData.finished
                    ? (oppData.won ? AppColors.primary : AppColors.error)
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea(RoundData round, bool isPlayer1) {
    final myData = isPlayer1 ? round.player1 : round.player2;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < 6; i++)
            _buildGridRow(
              i < myData.guesses.length 
                  ? myData.guesses[i] 
                  : (i == myData.guesses.length ? _currentGuess : ''),
              round.wordLength,
              i < myData.guesses.length ? round.targetWord : null,
              isCurrentRow: i == myData.guesses.length && !myData.finished,
            ),
        ],
      ),
    );
  }

  Widget _buildGridRow(String guess, int wordLength, String? targetWord, {bool isCurrentRow = false}) {
    // Pre-compute letter states using the same two-pass Wordle algorithm as the server.
    // This ensures duplicate letters are handled correctly and I/İ are compared with
    // turkishUpperCase so that the display always matches what the server computed.
    List<LetterState?> states = List.filled(wordLength, null);

    if (targetWord != null && guess.isNotEmpty) {
      final g = guess.split('').map(turkishUpperCase).toList();
      final t = targetWord.split('').map(turkishUpperCase).toList();
      final used = List<bool>.filled(t.length, false);

      // Pass 1: correct positions
      for (int i = 0; i < g.length && i < t.length; i++) {
        if (g[i] == t[i]) {
          states[i] = LetterState.correct;
          used[i] = true;
        }
      }
      // Pass 2: wrong positions / wrong
      for (int i = 0; i < g.length; i++) {
        if (states[i] == LetterState.correct) continue;
        bool found = false;
        for (int j = 0; j < t.length; j++) {
          if (!used[j] && g[i] == t[j]) {
            states[i] = LetterState.wrongPosition;
            used[j] = true;
            found = true;
            break;
          }
        }
        if (!found) states[i] = LetterState.wrong;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(wordLength, (i) {
          final letter = i < guess.length ? turkishUpperCase(guess[i]) : '';
          Color bgColor = AppColors.surface;
          Color borderColor = isCurrentRow && i == guess.length
              ? AppColors.primary
              : AppColors.surfaceLight;

          if (states[i] != null) {
            switch (states[i]) {
              case LetterState.correct:
                bgColor = AppColors.letterCorrect;
              case LetterState.wrongPosition:
                bgColor = AppColors.letterWrongPosition;
              case LetterState.wrong:
                bgColor = AppColors.letterWrong;
              default:
                break;
            }
            borderColor = bgColor;
          }

          return Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showForfeitDialog(String gameId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Pes Et?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Pes edersen puan kaybedersin.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Devam Et', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _forfeitGame(gameId);
            },
            child: const Text('Pes Et', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _forfeitGame(String gameId) async {
    final onlineGame = ref.read(onlineGameServiceProvider);
    await onlineGame.forfeit(gameId);
    if (mounted) context.go('/home');
  }

  Widget _buildResultScreen(OnlineGameSession game, bool isPlayer1) {
    final result = game.result!;
    final iWon = result.winnerUid == (isPlayer1 ? game.player1.uid : game.player2.uid);
    final myScore = isPlayer1 ? result.player1Score : result.player2Score;
    final oppScore = isPlayer1 ? result.player2Score : result.player1Score;
    final ratingChange = isPlayer1 ? result.ratingChange1 : result.ratingChange2;
    final isDraw = result.winnerUid == null;

    _guessTimer?.cancel();
    _disconnectCheckTimer?.cancel();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(Theme.of(context).brightness),
        ),
        child: SafeArea(
          child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDraw 
                      ? AppColors.surface
                      : (iWon ? AppColors.primary : AppColors.error).withValues(alpha: 0.2),
                ),
                child: Icon(
                  isDraw ? Icons.handshake : (iWon ? Icons.emoji_events : Icons.sentiment_dissatisfied),
                  size: 50,
                  color: isDraw ? AppColors.textMuted : (iWon ? AppColors.primary : AppColors.error),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isDraw ? 'BERABERE' : (iWon ? 'GALİBİYET!' : 'MAĞLUBİYET'),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: isDraw ? AppColors.textPrimary : (iWon ? AppColors.primary : AppColors.error),
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildScoreColumn('Sen', myScore, true),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('vs', style: TextStyle(fontSize: 20, color: AppColors.textMuted)),
                  ),
                  _buildScoreColumn(
                    isPlayer1 ? game.player2.displayName : game.player1.displayName,
                    oppScore,
                    false,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: ratingChange >= 0 
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ratingChange >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: ratingChange >= 0 ? AppColors.primary : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${ratingChange >= 0 ? '+' : ''}$ratingChange Puan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ratingChange >= 0 ? AppColors.primary : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => context.go('/home'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.surface),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    child: const Text('Ana Sayfa', style: TextStyle(color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _gameId = null;
                        _isSearching = false;
                        _currentGuess = '';
                        _keyboardState = {};
                      });
                      _startMatchmaking();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    child: const Text('Tekrar Oyna'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildScoreColumn(String name, int score, bool isMe) {
    return Column(
      children: [
        Text(name, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: isMe ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
