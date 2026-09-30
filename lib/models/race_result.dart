import 'bet.dart';
import 'racer.dart';

/// Everything the result dialog needs to explain a finished race.
class RaceResult {
  final int raceNumber;
  final List<Racer> racers;
  final int winnerId;
  final Bet? bet;
  final double payout;
  final double balanceBefore;
  final double balanceAfter;
  final DateTime timestamp;

  RaceResult({
    required this.raceNumber,
    required this.racers,
    required this.winnerId,
    required this.bet,
    required this.payout,
    required this.balanceBefore,
    required this.balanceAfter,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get hasBet => bet != null;

  bool get isWin => bet != null && bet!.covers(winnerId);

  bool get isPush => bet != null && !isWin && bet!.payout > 0;

  double get netProfit => balanceAfter - balanceBefore;

  Racer get winner => racers.firstWhere((racer) => racer.id == winnerId);

  /// Final standings, best total first.
  List<Racer> get standings {
    final sorted = List<Racer>.from(racers);
    sorted.sort((a, b) {
      final byTotal = a.totalTime.compareTo(b.totalTime);
      return byTotal != 0 ? byTotal : a.id.compareTo(b.id);
    });
    return sorted;
  }

  int placeOf(Racer racer) => standings.indexWhere((r) => r.id == racer.id) + 1;

  /// Best stop posted by a racer, used for the small stats row.
  int bestStopOf(Racer racer) => racer.stops.isEmpty
      ? 0
      : racer.stops.reduce((a, b) => a < b ? a : b);

  int worstStopOf(Racer racer) => racer.stops.isEmpty
      ? 0
      : racer.stops.reduce((a, b) => a > b ? a : b);
}
