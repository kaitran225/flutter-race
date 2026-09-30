import '../models/racer.dart';
import 'stop_generation.dart';

/// Owns every number the betting flow depends on.
///
/// The odds are derived from each racer's hidden [Racer.skill] rating, never
/// from the stops of the race that is about to run, so a bet can be placed
/// before the stops exist without giving the player free information.
class BettingSystem {
  /// Smallest stake accepted for a single bet.
  static const double minBet = 10.0;

  /// A player may never risk more than this fraction of the balance in one bet.
  static const double maxBetFraction = 0.5;

  /// Fraction of the theoretical payout that is kept by the house.
  static const double houseEdge = 0.10;

  /// Largest stake allowed for a given balance, rounded down to whole units.
  static double maxBet(double balance) {
    final raw = balance * maxBetFraction;
    if (raw < minBet) return 0;
    return raw.floorToDouble();
  }

  /// Quick-pick amounts offered on the bet screen.
  static List<double> quickBets(double balance) {
    final cap = maxBet(balance);
    final candidates = <double>[10, 25, 50, 100, 250, 500];
    return candidates.where((value) => value <= cap).toList();
  }

  static bool canPlaceBet(double amount, double balance) {
    return amount >= minBet && amount <= maxBet(balance) && amount <= balance;
  }

  /// How much a racer is expected to spend per stop. Lower is better: a racer
  /// with a low expected mean usually posts a low total and therefore wins.
  static double expectedMean(Racer racer) =>
      StopGenerationService.expectedMean(racer);

  /// Win probabilities, normalised so that the whole field adds up to 1.
  static Map<int, double> winProbabilities(List<Racer> racers) {
    if (racers.isEmpty) return <int, double>{};
    final weights = <int, double>{
      for (final racer in racers) racer.id: 1 / expectedMean(racer),
    };
    final total = weights.values.fold<double>(0, (sum, value) => sum + value);
    return weights.map((id, value) => MapEntry(id, value / total));
  }

  /// Payout multiplier for each racer, e.g. `1.80` means an 1.80x return of the
  /// stake. Every price is priced off the same model, so the reciprocal of all
  /// prices adds up to `1 / (1 - houseEdge)`: a single ticket always has a
  /// negative expected value.
  static Map<int, double> odds(List<Racer> racers) {
    final probabilities = winProbabilities(racers);
    return probabilities.map((id, probability) {
      if (probability <= 0) return MapEntry(id, 0.0);
      final multiplier = (1 - houseEdge) / probability;
      return MapEntry(id, double.parse(multiplier.toStringAsFixed(2)));
    });
  }

  static double oddsFor(int racerId, List<Racer> racers) =>
      odds(racers)[racerId] ?? 0;

  /// Price of a ticket: the product of the selected prices, because a multiple
  /// bet only pays when every pick wins.
  static double multiplierFor(Set<int> selectedIds, List<Racer> racers) {
    if (selectedIds.isEmpty) return 0;
    final table = odds(racers);
    var product = 1.0;
    for (final id in selectedIds) {
      final price = table[id] ?? 0;
      if (price <= 0) return 0;
      product *= price;
    }
    return double.parse(product.toStringAsFixed(2));
  }

  /// Money returned for [stake] if every racer in [selectedIds] wins.
  static double potentialPayout(
    double stake,
    Set<int> selectedIds,
    List<Racer> racers,
  ) {
    if (stake <= 0 || selectedIds.isEmpty) return 0;
    return double.parse(
      (stake * multiplierFor(selectedIds, racers)).toStringAsFixed(2),
    );
  }

  /// Payout of a ticket whose picks include [winnerId], otherwise zero.
  static double payoutFor(
    double stake,
    Set<int> selectedIds,
    List<Racer> racers,
    int winnerId,
  ) =>
      selectedIds.contains(winnerId)
          ? potentialPayout(stake, selectedIds, racers)
          : 0.0;

  /// Expected value of a ticket: positive means the player is favoured. It is
  /// always negative here, and it gets worse with every extra pick.
  static double expectedProfit(
    double stake,
    Set<int> selectedIds,
    List<Racer> racers,
  ) {
    if (stake <= 0 || selectedIds.isEmpty) return 0;
    final probabilities = winProbabilities(racers);
    final table = odds(racers);
    var joint = 1.0;
    for (final id in selectedIds) {
      joint *= (table[id] ?? 0) * (probabilities[id] ?? 0);
    }
    return double.parse((stake * joint - stake).toStringAsFixed(2));
  }

  static String money(double amount) {
    final sign = amount < 0 ? '-' : '';
    return '$sign\$${amount.abs().toStringAsFixed(2)}';
  }
}
