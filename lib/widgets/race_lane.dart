import 'package:flutter/material.dart';

import '../models/racer.dart';
import '../services/stop_generation.dart';
import '../theme.dart';

/// One horizontal lane of the track.
///
/// The flag sits on the left and the start gate on the right: every stop burns
/// a share of the remaining route, so a racer with the lowest total ends up
/// closest to the flag. The token is driven by a [TweenAnimationBuilder] so the
/// move from one stop to the next is always a smooth slide.
class RaceLane extends StatelessWidget {
  const RaceLane({
    super.key,
    required this.laneIndex,
    required this.racer,
    required this.isWinner,
    required this.isFinished,
    this.place,
  });

  final int laneIndex;
  final Racer racer;
  final bool isWinner;
  final bool isFinished;
  final int? place;

  static const double tokenSize = 40;

  @override
  Widget build(BuildContext context) {
    final progress = StopGenerationService.trackProgress(
      racer.totalTime,
      racer.currentStopIndex,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 640),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) => _buildLane(context, value),
    );
  }

  Widget _buildLane(BuildContext context, double progress) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      height: 86,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: laneBackground(laneIndex),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner ? AppTheme.winColor : Colors.white.withValues(alpha: 0.08),
          width: isWinner ? 2.5 : 1,
        ),
        boxShadow: isWinner
            ? [
                BoxShadow(
                  color: AppTheme.winColor.withValues(alpha: 0.35),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          _buildIdentity(context, theme),
          const SizedBox(width: 8),
          Expanded(child: _buildTrack(context, progress)),
          const SizedBox(width: 8),
          _buildTotals(context, theme),
        ],
      ),
    );
  }

  Widget _buildIdentity(BuildContext context, ThemeData theme) {
    return SizedBox(
      width: 58,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LANE ${laneIndex + 1}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 9,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            racer.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: racer.color,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (isFinished && place != null)
            Text(
              _ordinal(place!),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isWinner ? Colors.amber : Colors.white54,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrack(BuildContext context, double progress) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final travel = width - tokenSize;
        final tokenLeft = (travel * (1 - progress)).clamp(0.0, travel);
        final chipOnLeft = progress > 0.55;

        return SizedBox(
          height: tokenSize + 4,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DashedLinePainter(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 18,
                      color: isWinner
                          ? Colors.amber
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 2),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Icon(
                  Icons.play_circle_outline,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              // Route already burned, drawn behind the token.
              Positioned(
                left: tokenLeft + tokenSize / 2,
                right: 0,
                top: tokenSize / 2 - 3,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [
                        racer.color.withValues(alpha: 0.45),
                        racer.color.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: tokenLeft,
                top: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chipOnLeft) ...[
                      _buildStopChip(context),
                      const SizedBox(width: 4),
                    ],
                    _buildToken(context),
                    if (!chipOnLeft) ...[
                      const SizedBox(width: 4),
                      _buildStopChip(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToken(BuildContext context) {
    return Container(
      width: tokenSize,
      height: tokenSize,
      decoration: BoxDecoration(
        color: racer.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isWinner ? Colors.amber : Colors.white.withValues(alpha: 0.85),
          width: isWinner ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: racer.color.withValues(alpha: 0.5),
            blurRadius: 10,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(racer.emoji, style: const TextStyle(fontSize: 20)),
    );
  }

  Widget _buildStopChip(BuildContext context) {
    final hasStop = racer.currentStopIndex > 0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: hasStop
          ? Container(
              key: ValueKey<int>(racer.lastStop * 100 + racer.currentStopIndex),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '+${racer.lastStop}',
                style: TextStyle(
                  color: racer.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey<String>('empty')),
    );
  }

  Widget _buildTotals(BuildContext context, ThemeData theme) {
    final started = racer.currentStopIndex > 0;
    return SizedBox(
      width: 54,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            started ? '${racer.totalTime}' : '--',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'TOTAL',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 9,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${racer.currentStopIndex}/${racer.stopCount}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  static String _ordinal(int value) {
    if (value == 1) return '1st';
    if (value == 2) return '2nd';
    if (value == 3) return '3rd';
    return '${value}th';
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 5.0;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
