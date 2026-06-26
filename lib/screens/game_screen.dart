import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../services/services.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String mode;
  final int wordLength;

  const GameScreen({
    super.key,
    required this.mode,
    required this.wordLength,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _showInvalid = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGame();
    });
  }

  void _startGame() {
    _hasNavigated = false;
    final gameMode = _getGameMode();
    final lang = ref.read(languageProvider);
    final notifier = ref.read(gameProvider.notifier);

    if (gameMode == GameMode.daily) {
      // Check for saved daily session
      final dailyState = ref.read(dailyGameProvider(widget.wordLength));
      if (dailyState.savedSession != null && 
          dailyState.savedSession!.status == GameStatus.playing) {
        // Restore saved session
        notifier.restoreSession(dailyState.savedSession!);
        ref.read(guessTimerProvider.notifier).disable();
        return;
      }
      notifier.startDailyChallenge(wordLength: widget.wordLength, language: lang);
    } else if (gameMode == GameMode.scored) {
      notifier.startScoredMode(wordLength: widget.wordLength, language: lang);
    } else if (gameMode == GameMode.hint) {
      notifier.startHintMode(wordLength: widget.wordLength, language: lang);
    } else {
      notifier.startGame(wordLength: widget.wordLength, language: lang);
    }

    // Start timer for scored and hint modes
    if (gameMode == GameMode.scored || gameMode == GameMode.hint) {
      ref.read(guessTimerProvider.notifier).startGuessTimer();
    } else {
      ref.read(guessTimerProvider.notifier).disable();
    }
  }

  GameMode _getGameMode() {
    switch (widget.mode) {
      case 'daily':
        return GameMode.daily;
      case 'scored':
        return GameMode.scored;
      case 'practice':
        return GameMode.practice;
      case 'hint':
        return GameMode.hint;
      default:
        return GameMode.practice;
    }
  }

  void _onKeyPressed(String key) {
    ref.read(gameProvider.notifier).addLetter(key);
  }

  void _onEnter() {
    final game = ref.read(gameProvider);
    final currentGuess = game.currentGuess;
    
    // Block if word is not full length
    if (currentGuess.letters.any((l) => l.isEmpty)) {
      _shakeBoard(); // Visual feedback (optional/future)
      return; 
    }

    final success = ref.read(gameProvider.notifier).submitGuess();
    if (success) {
      // Valid guess — reset timer for scored and hint modes
      if (game.mode == GameMode.scored || game.mode == GameMode.hint) {
        ref.read(guessTimerProvider.notifier).resetForNextGuess();
      }
      // Save daily progress
      if (game.mode == GameMode.daily) {
        ref.read(dailyGameProvider(game.wordLength).notifier).saveSession(ref.read(gameProvider));
      }
    } else {
      // Check if game is still playing (it wasn't a game-over submit)
      final updatedGame = ref.read(gameProvider);
      if (updatedGame.status == GameStatus.playing) {
        // Invalid word — show warning
        _showInvalidWordWarning();
      }
    }
  }

  void _onBackspace() {
    ref.read(gameProvider.notifier).removeLetter();
  }

  void _showInvalidWordWarning() {
    setState(() => _showInvalid = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showInvalid = false);
    });
  }

  void _shakeBoard() {
    setState(() => _showInvalid = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showInvalid = false);
    });
  }

  void _showJokerPanel() {
    final jokers = ref.read(jokerProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => JokerPanelSheet(
        vowelJokers: jokers.vowelJokers,
        consonantJokers: jokers.consonantJokers,
        onRevealVowel: () {
          Navigator.pop(ctx);
          final idx = ref.read(gameProvider.notifier).revealVowel();
          if (idx != null) {
            ref.read(jokerProvider.notifier).useVowelJoker();
          }
        },
        onRevealConsonant: () {
          Navigator.pop(ctx);
          final idx = ref.read(gameProvider.notifier).revealConsonant();
          if (idx != null) {
            ref.read(jokerProvider.notifier).useConsonantJoker();
          }
        },
      ),
    );
  }

  void _navigateToResult(GameSession next) {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // Increment session games counter
    if (next.mode != GameMode.online) {
      ref.read(sessionGamesPlayedProvider.notifier).state++;
    }

    // Mark daily as complete
    if (next.mode == GameMode.daily) {
      ref.read(dailyGameProvider(next.wordLength).notifier).markCompleted();
    }
    final duration = (next.startTime != null && next.endTime != null)
        ? next.endTime!.difference(next.startTime!).inSeconds
        : 0;
        
    void proceedToResult() {
      Future.delayed(const Duration(milliseconds: 800), () async {
        if (mounted) {
          final shouldReplay = await context.push<bool>('/result', extra: {
            'isVictory': next.status == GameStatus.won,
            'word': next.targetWord,
            'score': next.score,
            'ratingChange': 0,
            'duration': duration,
            'nextDailyReset': next.mode == GameMode.daily
                ? ref.read(wordServiceProvider).getNextDailyResetTime()
                : null,
            'definition': ref.read(wordServiceProvider).getDefinition(next.targetWord) ?? '',
          });
          
          if (shouldReplay == true && mounted) {
            _startGame();
          }
        }
      });
    }

    // Show Interstitial ad every 5 single-player games
    final playedGames = ref.read(sessionGamesPlayedProvider);
    if (next.mode != GameMode.online && playedGames % 5 == 0) {
      final adService = ref.read(adServiceProvider);
      adService.showInterstitialAd(
        onAdDismissed: () => proceedToResult(),
      );
    } else {
      proceedToResult();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameSession = ref.watch(gameProvider);
    final timerState = ref.watch(guessTimerProvider);
    final isOnline = widget.mode == 'online';

    // Listen for timer expiry → end game
    ref.listen(guessTimerProvider, (prev, next) {
      if (next.isExpired) {
        final currentGame = ref.read(gameProvider);
        if (!currentGame.isGameOver) {
          ref.read(gameProvider.notifier).onTimerExpired();
        }
      }
    });

    // Handle game over → navigate to result
    ref.listen(gameProvider, (prev, next) {
      if (next.status == GameStatus.won || next.status == GameStatus.lost) {
        ref.read(guessTimerProvider.notifier).stop();
        
        // ── Extra Guess Joker Dialog on Game Lost ──
        if (next.status == GameStatus.lost && next.mode != GameMode.online) {
          final jokers = ref.read(jokerProvider);
          if (jokers.extraGuessJokers > 0 && next.usedExtraGuessJokers == 0) {
            // Wait a brief moment before showing dialog
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!context.mounted) return;
              showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('Oyun Bitti! 😢', style: TextStyle(color: AppColors.textPrimary)),
                  content: Text(
                    '${jokers.extraGuessJokers} adet Ekstra Tahmin jokerin var. Kullanarak oyuna devam etmek ister misin?',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hayır', style: TextStyle(color: AppColors.textMuted)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Evet, Joker Kullan', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ).then((useSelected) {
                if (useSelected == true && mounted) {
                  // Resume game with extra guess
                  final used = ref.read(jokerProvider.notifier).useExtraGuessJoker();
                  if (used) {
                    ref.read(gameProvider.notifier).useExtraGuessJoker();
                    if (next.hasTimer) {
                      ref.read(guessTimerProvider.notifier).resetForNextGuess();
                    }
                  }
                } else {
                  // User declined, proceed to result screen
                  _navigateToResult(next);
                }
              });
            });
            return; // Wait for dialog response, don't navigate yet
          }
        }

        // Proceed to result screen normally
        _navigateToResult(next);
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(Theme.of(context).brightness),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildGameHeader(context, gameSession, timerState),
              const SizedBox(height: 8),
              // Guess count / round info
              _buildInfoBar(gameSession),
              const SizedBox(height: 4),
              // Joker button above board (only for single player modes)
              if (!isOnline && gameSession.status == GameStatus.playing)
                _buildJokerButton(),
              const Spacer(),
              // Game Board with Overlay
              Stack(
                alignment: Alignment.center,
                children: [
                  GameBoard(
                    guesses: gameSession.guesses,
                    currentGuessIndex: gameSession.currentGuessIndex,
                    wordLength: gameSession.wordLength,
                  ),
                  // Invalid word overlay
                  if (_showInvalid)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
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
              const Spacer(),
              // Keyboard (bigger now that joker is above)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: GameKeyboard(
                  keyboardState: gameSession.keyboardState,
                  onEnter: _onEnter,
                  onBackspace: _onBackspace,
                  onKeyPressed: _onKeyPressed,
                  language: ref.read(languageProvider),
                  enabled: gameSession.status == GameStatus.playing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameHeader(BuildContext context, GameSession gameSession,
      GuessTimerState timerState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showExitDialog(),
            child: Container(
              width: 40,
              height: 40,
              decoration: AppColors.glassDecoration(borderRadius: 20),
              child: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
            ),
          ),
          const Spacer(),
          // Mode label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: AppColors.glassDecoration(borderRadius: 12),
            child: Text(
              _getModeLabel(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ),
          const Spacer(),
          // Timer (for scored and hint modes)
          if (gameSession.hasTimer)
            _buildCircularTimer(timerState),
        ],
      ),
    );
  }

  Widget _buildCircularTimer(GuessTimerState timerState) {
    final progress = timerState.totalSeconds > 0
        ? timerState.remainingSeconds / timerState.totalSeconds
        : 1.0;
    final isLow = timerState.remainingSeconds <= 3;

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation(
                isLow ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
          Text(
            '${timerState.remainingSeconds}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isLow ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar(GameSession gameSession) {
    final currentGuess = gameSession.currentGuessIndex + 1;
    final maxGuesses = gameSession.maxGuesses;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Guess counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: AppColors.glassDecoration(borderRadius: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.grid_view_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  '$currentGuess / $maxGuesses',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (gameSession.mode == GameMode.scored ||
              gameSession.mode == GameMode.hint) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: AppColors.glassDecoration(borderRadius: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${gameSession.sessionScore}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJokerButton() {
    return GestureDetector(
      onTap: _showJokerPanel,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              'Joker Kullan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getModeLabel() {
    switch (widget.mode) {
      case 'daily':
        return 'GÜNLÜK';
      case 'scored':
        return 'PUANLI';
      case 'practice':
        return 'PRATİK';
      case 'hint':
        return 'İPUÇLU';
      default:
        return 'OYUN';
    }
  }

  void _showExitDialog() {
    final game = ref.read(gameProvider);
    final isDaily = game.mode == GameMode.daily;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Oyundan çık?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          isDaily ? 'Kaldığınız yerden devam edebilirsiniz.' : 'İlerlemeniz kaybolacak.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Devam et', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(guessTimerProvider.notifier).stop();
              // Save daily progress before exiting
              if (isDaily && game.status == GameStatus.playing) {
                ref.read(dailyGameProvider(game.wordLength).notifier).saveSession(game);
              }
              context.go('/home');
            },
            child: Text('Çık', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
