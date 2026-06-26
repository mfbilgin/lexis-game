import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Timer state for per-guess countdown
class GuessTimerState {
  final int remainingSeconds;
  final int totalSeconds;
  final bool isRunning;
  final bool isExpired;

  const GuessTimerState({
    this.remainingSeconds = 20,
    this.totalSeconds = 20,
    this.isRunning = false,
    this.isExpired = false,
  });

  double get progress => totalSeconds > 0 
      ? remainingSeconds / totalSeconds 
      : 0;

  String get displayTime => '$remainingSeconds';

  GuessTimerState copyWith({
    int? remainingSeconds,
    int? totalSeconds,
    bool? isRunning,
    bool? isExpired,
  }) {
    return GuessTimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      isRunning: isRunning ?? this.isRunning,
      isExpired: isExpired ?? this.isExpired,
    );
  }
}

/// Timer notifier for per-guess countdown (20 seconds)
class GuessTimerNotifier extends StateNotifier<GuessTimerState> {
  Timer? _timer;
  final void Function()? onExpired;

  GuessTimerNotifier({this.onExpired}) : super(const GuessTimerState());

  /// Start a new 20-second timer for current guess
  void startGuessTimer() {
    _timer?.cancel();
    state = const GuessTimerState(
      remainingSeconds: 20,
      totalSeconds: 20,
      isRunning: true,
      isExpired: false,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 1) {
        timer.cancel();
        state = state.copyWith(
          remainingSeconds: 0,
          isRunning: false,
          isExpired: true,
        );
        onExpired?.call();
      } else {
        state = state.copyWith(
          remainingSeconds: state.remainingSeconds - 1,
        );
      }
    });
  }

  /// Reset timer for next guess
  void resetForNextGuess() {
    startGuessTimer();
  }

  /// Pause the timer
  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  /// Stop and reset the timer
  void stop() {
    _timer?.cancel();
    state = const GuessTimerState();
  }

  /// Disable timer (for daily mode)
  void disable() {
    _timer?.cancel();
    state = const GuessTimerState(
      remainingSeconds: 0,
      totalSeconds: 0,
      isRunning: false,
      isExpired: false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Timer provider
final guessTimerProvider = StateNotifierProvider<GuessTimerNotifier, GuessTimerState>((ref) {
  return GuessTimerNotifier();
});
