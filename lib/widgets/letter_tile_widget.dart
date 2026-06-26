import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/models.dart';

class LetterTileWidget extends StatefulWidget {
  final LetterTile tile;
  final double size;
  final int delay;

  const LetterTileWidget({
    super.key,
    required this.tile,
    this.size = 56,
    this.delay = 0,
  });

  @override
  State<LetterTileWidget> createState() => _LetterTileWidgetState();
}

class _LetterTileWidgetState extends State<LetterTileWidget>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _popController;
  late Animation<double> _flipAnimation;
  late Animation<double> _popAnimation;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    
    // Flip animation for revealing results
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _flipController.addListener(() {
      if (_flipController.value > 0.5 && !_showResult) {
        setState(() => _showResult = true);
      }
    });

    // Pop animation for typing letters
    _popController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _popAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _popController, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(LetterTileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset animation when state becomes empty (new game or clear)
    if (widget.tile.state == LetterState.empty && oldWidget.tile.state != LetterState.empty) {
      _showResult = false;
      _flipController.reset();
    }

    // Pop when letter is typed
    if (oldWidget.tile.state == LetterState.empty &&
        widget.tile.state == LetterState.filled) {
      _popController.forward().then((_) {
        if (mounted) _popController.reverse();
      });
    }

    // Flip animation when state changes to evaluated
    if (oldWidget.tile.state == LetterState.filled &&
        widget.tile.state != LetterState.filled &&
        widget.tile.state != LetterState.empty) {
      Future.delayed(Duration(milliseconds: widget.delay * 120), () {
        if (mounted) _flipController.forward();
      });
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _popController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    if (!_showResult && widget.tile.state != LetterState.correct &&
        widget.tile.state != LetterState.wrongPosition &&
        widget.tile.state != LetterState.wrong) {
      if (widget.tile.state == LetterState.filled) {
        return AppColors.surfaceLight;
      }
      return AppColors.letterEmpty;
    }

    switch (widget.tile.state) {
      case LetterState.correct:
        return AppColors.letterCorrect;
      case LetterState.wrongPosition:
        return AppColors.letterWrongPosition;
      case LetterState.wrong:
        return AppColors.letterWrong;
      case LetterState.filled:
        return AppColors.surfaceLight;
      case LetterState.empty:
        return AppColors.letterEmpty;
    }
  }

  Color _getBorderColor() {
    if (widget.tile.state == LetterState.filled) {
      return AppColors.primary.withValues(alpha: 0.6);
    }
    if (widget.tile.state == LetterState.empty) {
      return AppColors.letterBorder;
    }
    return Colors.transparent;
  }

  List<BoxShadow>? _getBoxShadow() {
    if (_showResult && widget.tile.state == LetterState.correct) {
      return [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flipAnimation, _popAnimation]),
      builder: (context, child) {
        final angle = _flipAnimation.value * 3.14159;
        final scale = _popAnimation.value;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(angle);

        return Transform.scale(
          scale: scale,
          child: Transform(
            alignment: Alignment.center,
            transform: transform,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _getBorderColor(),
                  width: widget.tile.state == LetterState.filled ? 2 : 1.5,
                ),
                boxShadow: _getBoxShadow(),
              ),
              child: Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateX(angle),
                  child: Text(
                    widget.tile.letter,
                    style: TextStyle(
                      fontSize: widget.size * 0.45,
                      fontWeight: FontWeight.w700,
                      color: _showResult &&
                              widget.tile.state == LetterState.wrongPosition
                          ? AppColors.background
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
