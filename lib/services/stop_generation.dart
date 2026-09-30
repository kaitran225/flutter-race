import 'dart:math';

import '../models/racer.dart';

/// Generates the hidden stop values for a race.
///
/// Rules enforced by [generateForRace]:
/// * every racer receives exactly [stopsPerRacer] stops;
/// * the ten stops of a racer are all different from each other;
/// * no value is shared between two racers, so the field always shows 40
///   distinct stops;
/// * every racer draws around its own mean, which comes from its hidden skill
///   rating, so each racer carries its own "luck" into the race and no two
///   races with the same field look alike.
class StopGenerationService {
  static const int minStop = 10;
  static const int maxStop = 99;
  static const int stopsPerRacer = 10;

  /// Standard deviation of a racer's stop distribution, in stop points.
  static const double spread = 21.0;

  /// Largest total a racer can possibly reach.
  static const int trackMax = stopsPerRacer * maxStop;

  /// Smallest total a racer can possibly reach.
  static const int trackMin = stopsPerRacer * minStop;

  static int _seed = DateTime.now().microsecondsSinceEpoch;

  /// Resets the generator. Passing a seed makes the race reproducible.
  static void reseed([int? seed]) {
    _seed = seed ?? DateTime.now().microsecondsSinceEpoch;
  }

  static int get currentSeed => _seed;

  /// Average stop a racer is expected to post. The hidden skill rating maps to
  /// a mean, and that mean is the only thing the betting system is allowed to
  /// know before the race.
  static double expectedMean(Racer racer) =>
      (100.0 - racer.skill * 68.0).clamp(34.0, 96.0);

  /// Total distance a racer covers on the track, 0..1. Each stop burns a share
  /// of the remaining route, so a low total keeps a racer closest to the flag.
  static double trackProgress(int totalTime, int revealedStops) {
    if (revealedStops <= 0) return 0;
    final window = trackMax - trackMin;
    final progress = 1.0 - (totalTime - trackMin) / window;
    return progress.clamp(0.0, 1.0);
  }

  /// Rolls a brand new set of stops for the whole field.
  static void generateForRace(List<Racer> racers, {int? seed}) {
    reseed(seed);
    final rng = Random(_seed);
    for (final racer in racers) {
      racer.reset();
    }
    if (racers.isEmpty) return;

    // A single shared pool sampled without replacement guarantees distinct
    // values everywhere. The strongest racers draft first so the best values
    // stay available to the racers that can actually make use of them.
    final pool = List<int>.generate(maxStop - minStop + 1, (i) => minStop + i)
      ..shuffle(rng);
    final draftOrder = List<Racer>.from(racers)
      ..sort((a, b) => b.skill.compareTo(a.skill));

    for (final racer in draftOrder) {
      final mean = expectedMean(racer) + _luckJitter(rng);
      final picked = <int>[];
      for (var i = 0; i < stopsPerRacer; i++) {
        if (pool.isEmpty) {
          picked.add(minStop + rng.nextInt(maxStop - minStop + 1));
          continue;
        }
        picked.add(_weightedPick(pool, mean, rng));
      }
      racer.stops = picked;
    }
  }

  /// Small per-race shift that keeps two identically skilled racers from
  /// producing the same shape of race twice in a row.
  static double _luckJitter(Random rng) => (rng.nextDouble() - 0.5) * 12.0;

  static int _weightedPick(List<int> pool, double mean, Random rng) {
    var total = 0.0;
    final weights = List<double>.generate(pool.length, (i) {
      final delta = pool[i] - mean;
      final weight = exp(-(delta * delta) / (2 * spread * spread));
      total += weight;
      return weight;
    });

    var roll = rng.nextDouble() * total;
    for (var i = 0; i < pool.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return pool.removeAt(i);
    }
    return pool.removeLast();
  }

  /// Lowest total in the field. Ties are broken by the racer order so a race
  /// always has exactly one winner.
  static Racer winnerOf(List<Racer> racers) {
    final sorted = List<Racer>.from(racers)
      ..sort((a, b) {
        final byTotal = a.totalTime.compareTo(b.totalTime);
        return byTotal != 0 ? byTotal : a.id.compareTo(b.id);
      });
    return sorted.first;
  }
}
