import 'package:flutter_test/flutter_test.dart';
import 'package:game/models/bet.dart';
import 'package:game/models/racer.dart';
import 'package:game/services/betting_system.dart';
import 'package:game/services/stop_generation.dart';

void main() {
  group('StopGenerationService', () {
    test('gives every racer 10 stops and 40 distinct values', () {
      final racers = Racer.defaultRacers();
      StopGenerationService.generateForRace(racers, seed: 1234);

      final all = <int>{};
      for (final racer in racers) {
        expect(racer.stops.length, StopGenerationService.stopsPerRacer);
        expect(racer.stops.toSet().length, StopGenerationService.stopsPerRacer);
        all.addAll(racer.stops);
      }
      expect(all.length, racers.length * StopGenerationService.stopsPerRacer);
      for (final stop in all) {
        expect(stop,
            inInclusiveRange(StopGenerationService.minStop, StopGenerationService.maxStop));
      }
    });

    test('is reproducible for a seed and different across seeds', () {
      final first = Racer.defaultRacers();
      final second = Racer.defaultRacers();
      StopGenerationService.generateForRace(first, seed: 99);
      StopGenerationService.generateForRace(second, seed: 99);
      expect(first[0].stops, second[0].stops);

      final third = Racer.defaultRacers();
      StopGenerationService.generateForRace(third, seed: 100);
      expect(third[0].stops, isNot(first[0].stops));
    });

    test('the winner is the lowest total', () {
      final racers = Racer.defaultRacers();
      StopGenerationService.generateForRace(racers, seed: 7);
      for (final racer in racers) {
        while (racer.hasPendingStop) {
          racer.applyNextStop();
        }
      }
      final winner = StopGenerationService.winnerOf(racers);
      final lowest = racers.map((r) => r.totalTime).reduce((a, b) => a < b ? a : b);
      expect(winner.totalTime, lowest);
    });

    test('a strong racer usually posts a lower total than a weak one', () {
      var strongWins = 0;
      for (var seed = 0; seed < 40; seed++) {
        final racers = Racer.defaultRacers();
        StopGenerationService.generateForRace(racers, seed: seed);
        for (final racer in racers) {
          racer.totalTime = racer.stops.reduce((a, b) => a + b);
          racer.currentStopIndex = racer.stopCount;
        }
        final strong = racers.firstWhere((r) => r.skill == 0.84);
        final weak = racers.firstWhere((r) => r.skill == 0.26);
        if (strong.totalTime < weak.totalTime) strongWins++;
      }
      expect(strongWins, greaterThan(30));
    });

    test('track progress keeps every racer inside the track', () {
      expect(StopGenerationService.trackProgress(0, 0), 0);
      expect(StopGenerationService.trackProgress(StopGenerationService.trackMin, 1),
          closeTo(1, 0.0001));
      expect(StopGenerationService.trackProgress(StopGenerationService.trackMax, 10), 0);
      expect(StopGenerationService.trackProgress(99999, 10), 0);
    });
  });

  group('BettingSystem', () {
    final racers = Racer.defaultRacers();

    test('prices carry the house edge on every leg', () {
      final odds = BettingSystem.odds(racers);
      final overround =
          odds.values.fold<double>(0, (sum, price) => sum + 1 / price);
      expect(overround, closeTo(1 / (1 - BettingSystem.houseEdge), 0.01));
    });

    test('the best racer is the shortest price', () {
      final odds = BettingSystem.odds(racers);
      expect(odds[0]!, lessThan(odds[3]!));
    });

    test('win probabilities are normalised', () {
      final probabilities = BettingSystem.winProbabilities(racers);
      final total = probabilities.values.fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(1, 0.0001));
    });

    test('a multiple ticket multiplies the prices', () {
      final odds = BettingSystem.odds(racers);
      expect(
        BettingSystem.multiplierFor({0, 1}, racers),
        closeTo(odds[0]! * odds[1]!, 0.01),
      );
    });

    test('every ticket has a negative expected value', () {
      for (var mask = 1; mask < 1 << racers.length; mask++) {
        final selected = <int>{
          for (var i = 0; i < racers.length; i++)
            if (mask & (1 << i) != 0) racers[i].id,
        };
        expect(
          BettingSystem.expectedProfit(100, selected, racers),
          lessThan(0),
          reason: 'selection $selected should not be profitable',
        );
      }
    });

    test('limits follow the balance', () {
      expect(BettingSystem.maxBet(1000), 500);
      expect(BettingSystem.maxBet(15), 0);
      expect(BettingSystem.canPlaceBet(10, 1000), isTrue);
      expect(BettingSystem.canPlaceBet(5, 1000), isFalse);
      expect(BettingSystem.canPlaceBet(600, 1000), isFalse);
    });
  });

  group('Bet', () {
    final racers = Racer.defaultRacers();

    test('a single ticket pays the winner price only', () {
      final bet = Bet(
        stake: 100,
        selectedRacerIds: [0],
        potential: 100 * BettingSystem.oddsFor(0, racers),
        multiplier: BettingSystem.oddsFor(0, racers),
      );
      expect(bet.kind, BetKind.single);

      expect(bet.settle(racers, 0), greaterThan(0));
      expect(bet.settled, isTrue);
      expect(bet.payout, closeTo(bet.potential, 0.01));
      expect(bet.profit, greaterThan(0));

      final loser = Bet(
        stake: 100,
        selectedRacerIds: [0],
        potential: 100 * BettingSystem.oddsFor(0, racers),
        multiplier: BettingSystem.oddsFor(0, racers),
      );
      expect(loser.settle(racers, 1), 0);
      expect(loser.profit, -100);
    });

    test('a multiple ticket needs every pick and only settles once', () {
      final expected =
          BettingSystem.potentialPayout(50, {2, 3}, racers);
      final bet = Bet(
        stake: 50,
        selectedRacerIds: [2, 3],
        potential: expected,
        multiplier: BettingSystem.multiplierFor({2, 3}, racers),
      );
      expect(bet.kind, BetKind.multiple);

      expect(bet.settle(racers, 1), 0, reason: 'winner is not a pick');
      expect(bet.payout, 0);
    });

    test('a multiple ticket pays the product when the winner is a pick', () {
      final bet = Bet(
        stake: 50,
        selectedRacerIds: [2, 3],
        potential: BettingSystem.potentialPayout(50, {2, 3}, racers),
        multiplier: BettingSystem.multiplierFor({2, 3}, racers),
      );
      final payout = bet.settle(racers, 3);
      expect(payout, greaterThan(0));
      expect(bet.settle(racers, 3), 0, reason: 'a ticket cannot pay twice');
    });
  });
}
