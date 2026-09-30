import 'dart:math';

import 'package:flutter/material.dart';

import '../models/bet.dart';
import '../models/race_result.dart';
import '../models/racer.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/betting_system.dart';
import '../services/session.dart';
import '../services/stop_generation.dart';
import '../theme.dart';
import '../widgets/race_lane.dart';
import '../widgets/race_result_dialog.dart';
import 'bet_screen.dart';

enum RacePhase { idle, running, finished }

class RaceScreen extends StatefulWidget {
  const RaceScreen({super.key, required this.user});

  final User user;

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  late User _user = widget.user;
  final List<Racer> _racers = Racer.defaultRacers();
  final Random _rng = Random();

  Bet? _bet;
  RacePhase _phase = RacePhase.idle;
  int _raceNumber = 0;
  int _revealedStops = 0;
  RaceResult? _lastResult;
  int? _winnerId;

  double get _balance => _user.balance;

  bool get _isRunning => _phase == RacePhase.running;

  bool get _canBet =>
      !_isRunning && _balance >= BettingSystem.minBet;

  int _placeOf(Racer racer) {
    final result = _lastResult;
    if (result == null) return 0;
    return result.placeOf(racer);
  }

  // ---------------------------------------------------------------- race flow

  Future<void> _openBetScreen() async {
    if (_isRunning) return;
    final bet = await Navigator.of(context).push<Bet>(
      MaterialPageRoute(
        builder: (_) => BetScreen(user: _user, racers: _racers),
      ),
    );
    if (bet == null || !mounted) return;
    setState(() {
      _bet = bet;
      _phase = RacePhase.idle;
      _lastResult = null;
      _winnerId = null;
    });
  }

  void _clearBet() {
    if (_isRunning || _bet == null) return;
    setState(() => _bet = null);
  }

  Future<void> _startRace() async {
    if (_isRunning) return;
    final bet = _bet;
    if (bet != null && bet.stake > _balance) {
      _showMessage('Not enough balance for that bet. Clear it and try again.');
      setState(() => _bet = null);
      return;
    }

    final balanceBefore = _balance;
    if (bet != null) {
      // The stake leaves the balance now, the payout only comes back on settle.
      await AuthService.saveBalance(balanceBefore - bet.stake);
    }

    StopGenerationService.generateForRace(_racers);
    setState(() {
      _user = _user.copyWith(balance: balanceBefore - (bet?.stake ?? 0));
      _phase = RacePhase.running;
      _revealedStops = 0;
      _winnerId = null;
      _lastResult = null;
    });

    await _runRace();
    if (!mounted) return;
    await _settleRace(balanceBefore, bet);
  }

  /// Reveals one stop per racer, staggered so the four tokens never move in
  /// lockstep, and lets each token slide to its new position.
  Future<void> _runRace() async {
    final total = _racers.isEmpty ? 0 : _racers.first.stopCount;
    for (var step = 0; step < total; step++) {
      if (!mounted) return;
      final order = List<int>.generate(_racers.length, (i) => i)..shuffle(_rng);
      final moves = <Future<void>>[
        for (final index in order)
          Future<void>.delayed(Duration(milliseconds: 30 + _rng.nextInt(170))).then((_) {
            if (!mounted) return;
            final racer = _racers[index];
            if (!racer.hasPendingStop) return;
            setState(() {
              racer.applyNextStop();
              _revealedStops = step + 1;
            });
          }),
      ];
      await Future.wait(moves);
      if (!mounted) return;
      await Future<void>.delayed(Duration(milliseconds: 220 + _rng.nextInt(180)));
    }
  }

  Future<void> _settleRace(double balanceBefore, Bet? bet) async {
    if (!mounted) return;
    final winner = StopGenerationService.winnerOf(_racers);
    final payout = bet?.settle(_racers, winner.id) ?? 0;
    final balanceAfter = double.parse((balanceBefore + payout).toStringAsFixed(2));

    final result = RaceResult(
      raceNumber: _raceNumber + 1,
      racers: List<Racer>.from(_racers),
      winnerId: winner.id,
      bet: bet,
      payout: payout,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
    );

    setState(() {
      _user = _user.copyWith(balance: balanceAfter);
      _phase = RacePhase.finished;
      _raceNumber = result.raceNumber;
      _lastResult = result;
      _winnerId = winner.id;
      _bet = null;
    });
    await AuthService.saveBalance(balanceAfter);

    if (!mounted) return;
    final raceAgain = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RaceResultDialog(result: result),
    );
    if (!mounted) return;
    if (raceAgain == true) {
      setState(() {
        _phase = RacePhase.idle;
        _lastResult = null;
        _winnerId = null;
        _revealedStops = 0;
        for (final racer in _racers) {
          racer.reset();
        }
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    if (_isRunning) return;
    await Session.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _resetAccount() async {
    if (_isRunning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset account?'),
        content: Text(
          'This deletes the stored login and resets the balance to '
          '${_money(AuthService.startingBalance)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Session.instance.resetAccount();
    if (!mounted) return;
    await _signOut();
  }

  static String _money(double amount) => BettingSystem.money(amount);

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRunning ? 'Racing…' : 'Race Day · #$_raceNumber'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _money(_balance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'signout') _signOut();
              if (value == 'reset') _resetAccount();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
              PopupMenuItem(value: 'reset', child: Text('Reset account')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                children: [
                  for (var i = 0; i < _racers.length; i++) ...[
                    RaceLane(
                      laneIndex: i,
                      racer: _racers[i],
                      isWinner: _winnerId == _racers[i].id && _phase == RacePhase.finished,
                      isFinished: _phase == RacePhase.finished,
                      place: _lastResult == null ? null : _placeOf(_racers[i]),
                    ),
                  ],
                  const SizedBox(height: 4),
                  _buildLegend(context, theme),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildControls(context, theme),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final potential = _bet == null
        ? 0.0
        : _bet!.potential;
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: _statTile(
              context,
              label: 'BALANCE',
              value: _money(_balance),
              color: _balance > 0 ? AppTheme.winColor : theme.colorScheme.error,
            ),
          ),
          Expanded(
            child: _statTile(
              context,
              label: 'BET',
              value: _bet == null ? '—' : _money(_bet!.stake),
              color: theme.colorScheme.primary,
            ),
          ),
          Expanded(
            child: _statTile(
              context,
              label: 'RETURNS',
              value: _bet == null ? '—' : _money(potential),
              color: _isRunning ? Colors.grey : Colors.deepPurple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(BuildContext context,
      {required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey[600],
                letterSpacing: 1,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context, ThemeData theme) {
    final stepTotal = _racers.isEmpty ? 0 : _racers.first.stopCount;
    final step = _isRunning || _phase == RacePhase.finished
        ? '$_revealedStops / $stepTotal stops'
        : '10 stops each · lowest total wins';
    return Row(
      children: [
        Icon(Icons.flag_rounded, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text('Closest to the flag wins',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.grey[600])),
        const Spacer(),
        Text(step,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildControls(BuildContext context, ThemeData theme) {
    final canStart = !_isRunning && _balance > 0;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBetSummary(context, theme),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _canBet ? _openBetScreen : null,
                      icon: const Icon(Icons.local_atm_rounded, size: 20),
                      label: Text(_bet == null ? 'Place Bet' : 'Edit Bet'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: canStart ? _startRace : null,
                      icon: _isRunning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(_isRunning ? 'Racing' : 'Start Race'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBetSummary(BuildContext context, ThemeData theme) {
    final bet = _bet;
    if (bet == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _canBet
                    ? 'No bet this race. Play safe or pick some racers.'
                    : 'Not enough balance. Reset the account from the menu.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      );
    }

    final names = _racers
        .where((racer) => bet.covers(racer.id))
        .map((racer) => racer.name)
        .join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark_rounded, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_money(bet.stake)} on $names',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  bet.isMultiple
                      ? 'Multiple · all ${bet.selectionCount} must win · '
                          '${bet.multiplier.toStringAsFixed(2)}x'
                      : 'Single · ${bet.multiplier.toStringAsFixed(2)}x if '
                          '${_singleName(bet)} wins',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isRunning ? null : _clearBet,
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Clear bet',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _singleName(Bet bet) {
    final covers = _racers.where((racer) => bet.covers(racer.id));
    return covers.isEmpty ? 'your pick' : covers.first.name;
  }
}
