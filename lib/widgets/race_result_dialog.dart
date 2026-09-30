import 'package:flutter/material.dart';

import '../models/bet.dart';
import '../models/race_result.dart';
import '../services/betting_system.dart';
import '../theme.dart';

/// End of race report. Pops `true` when the player wants to run the next race
/// right away, `false` when they want to re-bet first.
class RaceResultDialog extends StatelessWidget {
  const RaceResultDialog({super.key, required this.result});

  final RaceResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winner = result.winner;
    final title = !result.hasBet
        ? 'NO BET'
        : result.isWin
            ? 'YOU WIN'
            : 'BET LOST';
    final color = !result.hasBet
        ? theme.colorScheme.primary
        : result.isWin
            ? AppTheme.winColor
            : theme.colorScheme.error;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      title: Column(
        children: [
          Icon(
            result.isWin ? Icons.emoji_events_rounded : Icons.flag_rounded,
            size: 52,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Race #${result.raceNumber} · lowest total wins',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: winner.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Text(winner.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${winner.name} takes the race',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Total ${winner.totalTime} · best stop '
                          '${result.bestStopOf(winner)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildStandings(context, theme),
            const SizedBox(height: 14),
            _buildMoney(context, theme),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Change Bet'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Race Again'),
        ),
      ],
    );
  }

  Widget _buildStandings(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FINAL STANDS',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey[600],
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ...result.standings.map((racer) {
          final place = result.placeOf(racer);
          final covered = result.bet?.covers(racer.id) ?? false;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text(
                    '$place.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: racer.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    racer.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: place == 1 ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                if (covered) ...[
                  const Icon(Icons.bookmark_rounded, size: 14, color: Colors.deepPurple),
                  const SizedBox(width: 6),
                ],
                Text(
                  '${racer.totalTime}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: place == 1 ? AppTheme.winColor : Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'low ${result.bestStopOf(racer)}',
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMoney(BuildContext context, ThemeData theme) {
    final bet = result.bet;
    final net = result.netProfit;
    final netColor = net >= 0 ? AppTheme.winColor : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          if (bet != null) ...[
            _moneyRow(theme, 'Stake · ${_betLabel(bet)}',
                '-${BettingSystem.money(bet.stake)}', theme.colorScheme.error),
            const SizedBox(height: 6),
            _moneyRow(
              theme,
              'Payout',
              result.payout > 0
                  ? '+${BettingSystem.money(result.payout)}'
                  : BettingSystem.money(0),
              result.payout > 0 ? AppTheme.winColor : const Color(0xFF616161),
            ),
            const Divider(height: 18),
          ],
          _moneyRow(
            theme,
            net >= 0 ? 'Profit' : 'Loss',
            '${net >= 0 ? '+' : '-'}${BettingSystem.money(net.abs())}',
            netColor,
            bold: true,
          ),
          _moneyRow(theme, 'Balance', BettingSystem.money(result.balanceAfter),
              const Color(0xFF212121), bold: true),
        ],
      ),
    );
  }

  Widget _moneyRow(ThemeData theme, String label, String value, Color color,
      {bool bold = false}) {
    final style = (bold
            ? theme.textTheme.titleMedium
            : theme.textTheme.bodyMedium)
        ?.copyWith(fontWeight: FontWeight.w800, color: color);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
        Text(value, style: style),
      ],
    );
  }

  static String _betLabel(Bet bet) {
    final names = bet.selectedRacerIds.length;
    return bet.isMultiple ? '$names racers' : '1 racer';
  }
}
