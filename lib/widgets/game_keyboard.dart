import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/turkish_utils.dart';
import '../models/models.dart';

class GameKeyboard extends StatelessWidget {
  final Map<String, LetterState> keyboardState;
  final VoidCallback onEnter;
  final VoidCallback onBackspace;
  final Function(String) onKeyPressed;
  final String language;
  final bool enabled;

  const GameKeyboard({
    super.key,
    required this.keyboardState,
    required this.onEnter,
    required this.onBackspace,
    required this.onKeyPressed,
    this.language = 'en',
    this.enabled = true,
  });

  // English keyboard layout (QWERTY)
  static const List<List<String>> _englishKeyRows = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '⌫'],
  ];

  // Turkish keyboard layout
  static const List<List<String>> _turkishKeyRows = [
    ['E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
    ['ENTER', 'Z', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç', '⌫'],
  ];

  List<List<String>> get _keyRows {
    return language == 'tr' ? _turkishKeyRows : _englishKeyRows;
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: AbsorbPointer(
        absorbing: !enabled,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Column(
            children: _keyRows.map((row) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: row.map((key) {
                    return Expanded(
                      flex: (key == 'ENTER' || key == '⌫') ? 3 : 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _buildKey(key),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String key) {
    final isEnter = key == 'ENTER';
    final isBackspace = key == '⌫';
    final isSpecial = isEnter || isBackspace;

    final stateKey = _normalizeKey(key);
    final state = keyboardState[stateKey];
    final backgroundColor = _getKeyColor(state);

    double keyWidth;
    if (isSpecial) {
      keyWidth = 52;
    } else if (language == 'tr') {
      keyWidth = 30;
    } else {
      keyWidth = 34;
    }

    return Semantics(
      label: isEnter ? 'Onayla' : isBackspace ? 'Sil' : key,
      button: true,
      child: GestureDetector(
        onTap: enabled ? () {
          HapticFeedback.lightImpact();
          if (isEnter) {
            onEnter();
          } else if (isBackspace) {
            onBackspace();
          } else {
            onKeyPressed(key);
          }
        } : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: state == LetterState.correct
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        child: Center(
          child: isBackspace
              ? const Icon(Icons.backspace_outlined, color: AppColors.textPrimary, size: 20)
              : isEnter
                  ? const Icon(Icons.keyboard_return, color: AppColors.primary, size: 20)
                  : Text(
                      key,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _getTextColor(state),
                      ),
                    ),
        ),
        ),
      ),
    );
  }

  String _normalizeKey(String key) {
    return turkishUpperCase(key);
  }

  Color _getKeyColor(LetterState? state) {
    switch (state) {
      case LetterState.correct:
        return AppColors.letterCorrect;
      case LetterState.wrongPosition:
        return AppColors.letterWrongPosition;
      case LetterState.wrong:
        return AppColors.letterWrong;
      default:
        return AppColors.surfaceLight;
    }
  }

  Color _getTextColor(LetterState? state) {
    if (state == LetterState.wrongPosition) {
      return AppColors.background;
    }
    return AppColors.textPrimary;
  }
}
