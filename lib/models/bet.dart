import '../models/racer.dart';
import '../services/betting_system.dart';

enum BetKind { single, multiple }

/// A ticket placed before a race starts.
///
/// The stake leaves the balance as soon as the bet is accepted; [settle] moves
/// the payout back in when the race is over, so the balance never counts a win
/// that has not happened yet. A single ticket pays its own price, a multiple
/// ticket pays the product of its prices and therefore needs every pick to win.
class Bet {
  final double stake;
  final List<int> selectedRacerIds;
  final DateTime timestamp;
  final double potential;
  final double multiplier;

  double payout = 0;
  bool settled = false;

  Bet({
    required this.stake,
    required List<int> selectedRacerIds,
    required this.potential,
    required this.multiplier,
    DateTime? timestamp,
  })  : selectedRacerIds = List<int>.unmodifiable(selectedRacerIds),
        timestamp = timestamp ?? DateTime.now();

  BetKind get kind =>
      selectedRacerIds.length > 1 ? BetKind.multiple : BetKind.single;

  bool get isMultiple => kind == BetKind.multiple;

  int get selectionCount => selectedRacerIds.length;

  bool covers(int racerId) => selectedRacerIds.contains(racerId);

  /// Net result once the race is settled. Negative on a losing ticket.
  double get profit => payout - stake;

  /// Resolves the ticket against a winner and returns the money to credit.
  double settle(List<Racer> racers, int winnerId) {
    if (settled) return 0;
    settled = true;
    payout = BettingSystem.payoutFor(
      stake,
      selectedRacerIds.toSet(),
      racers,
      winnerId,
    );
    return payout;
  }
}
