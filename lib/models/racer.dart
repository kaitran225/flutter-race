import 'dart:ui';

class Racer {
  final int id;
  final String name;
  final Color color;
  final String emoji;

  /// Hidden rating in the 0..1 range. It never changes between races, so the
  /// odds shown before a race stay meaningful while the generated stops of the
  /// upcoming race are still secret.
  final double skill;

  List<int> stops;
  int currentStopIndex;
  int totalTime;
  bool isFinished;

  Racer({
    required this.id,
    required this.name,
    required this.color,
    required this.emoji,
    required this.skill,
    List<int>? stops,
  })  : stops = stops ?? <int>[],
        currentStopIndex = 0,
        totalTime = 0,
        isFinished = false;

  bool get hasPendingStop => currentStopIndex < stops.length;

  bool get hasStops => stops.isNotEmpty;

  int get lastStop => currentStopIndex == 0 ? 0 : stops[currentStopIndex - 1];

  int get stopCount => stops.length;

  /// Reveals the next stop and adds it to the running total.
  void applyNextStop() {
    if (!hasPendingStop) {
      isFinished = true;
      return;
    }
    totalTime += stops[currentStopIndex];
    currentStopIndex++;
    if (!hasPendingStop) isFinished = true;
  }

  void reset() {
    currentStopIndex = 0;
    totalTime = 0;
    isFinished = false;
  }

  static List<Racer> defaultRacers() => <Racer>[
        Racer(
          id: 0,
          name: 'Blaze',
          emoji: '🔥',
          color: const Color(0xFFFF7043),
          skill: 0.84,
        ),
        Racer(
          id: 1,
          name: 'Nimbus',
          emoji: '⚡',
          color: const Color(0xFF26C6DA),
          skill: 0.62,
        ),
        Racer(
          id: 2,
          name: 'Rex',
          emoji: '🐺',
          color: const Color(0xFF66BB6A),
          skill: 0.44,
        ),
        Racer(
          id: 3,
          name: 'Echo',
          emoji: '🌪️',
          color: const Color(0xFFAB47BC),
          skill: 0.26,
        ),
      ];
}
