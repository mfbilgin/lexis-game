import 'package:flutter/material.dart';
import '../models/models.dart';
import 'letter_tile_widget.dart';

class GameBoard extends StatelessWidget {
  final List<WordGuess> guesses;
  final int currentGuessIndex;
  final int wordLength;

  const GameBoard({
    super.key,
    required this.guesses,
    required this.currentGuessIndex,
    required this.wordLength,
  });

  @override
  Widget build(BuildContext context) {
    // Determine which guesses to display. If we have more than 6 guesses
    // (due to extra guess joker), only show the last 6.
    final displayGuesses = guesses.length > 6 
        ? guesses.sublist(guesses.length - 6) 
        : guesses;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(displayGuesses.length, (rowIndex) {
        final guess = displayGuesses[rowIndex];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(wordLength, (colIndex) {
              final tile = guess.letters[colIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: LetterTileWidget(
                  tile: tile,
                  size: _calculateTileSize(context),
                  delay: colIndex,
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  double _calculateTileSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 48;
    final tileWidth = (availableWidth - (wordLength - 1) * 6) / wordLength;
    return tileWidth.clamp(42.0, 62.0);
  }
}
