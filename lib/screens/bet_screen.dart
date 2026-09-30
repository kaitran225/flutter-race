import 'package:flutter/material.dart';

import '../models/bet.dart';
import '../models/racer.dart';
import '../models/user.dart';
import '../services/betting_system.dart';

/// Bet slip. Pops a [Bet] with the confirmed ticket, or null when the player
/// backs out. The money is only moved when the race actually starts.
class BetScreen extends StatefulWidget {
  const BetScreen({super.key, required this.user, required this.racers});

  final User user;
  final List<Racer> racers;

  @override
  State<BetScreen> createState() => _BetScreenState();
}

class _BetScreenState extends State<BetScreen> {
  final TextEditingController _amountController = TextEditingController();
  final Set<int> _selected = <int>{};
  String? _error;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = BettingSystem.minBet.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _stake => double.tryParse(_amountController.text.trim()) ?? 0;

  double get _maxBet => BettingSystem.maxBet(widget.user.balance);

  double get _payout =>
      BettingSystem.potentialPayout(_stake, _selected, widget.racers);

  double get _multiplier =>
      BettingSystem.multiplierFor(_selected, widget.racers);

  void _setStake(double value) {
    final clamped = value.clamp(0.0, _maxBet).toDouble();
    _amountController.text = clamped.toStringAsFixed(0);
    setState(() => _error = null);
  }

  void _toggle(int id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
      _error = null;
    });
  }

  void _confirm() {
    if (_selected.isEmpty) {
      setState(() => _error = 'Pick at least one racer');
      return;
    }
    if (_stake < BettingSystem.minBet) {
      setState(() => _error =
          'Minimum bet is ${BettingSystem.money(BettingSystem.minBet)}');
      return;
    }
    if (_stake > _maxBet) {
      setState(() => _error =
          'Maximum bet is ${BettingSystem.money(_maxBet)} (${(BettingSystem.maxBetFraction * 100).round()}% of balance)');
      return;
    }
    if (_stake > widget.user.balance) {
      setState(() => _error = 'Insufficient balance');
      return;
    }
    Navigator.of(context).pop(
      Bet(
        stake: double.parse(_stake.toStringAsFixed(2)),
        selectedRacerIds: _selected.toList(),
        potential: _payout,
        multiplier: _multiplier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final oddsTable = BettingSystem.odds(widget.racers);
    final probabilities = BettingSystem.winProbabilities(widget.racers);

    return Scaffold(
      appBar: AppBar(title: const Text('Place Your Bet')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  _buildWallet(context, theme),
                  const SizedBox(height: 18),
                  _buildAmount(context, theme),
                  const SizedBox(height: 20),
                  _buildPicks(context, theme, oddsTable, probabilities),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            _buildFooter(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWallet(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _walletItem(context, 'BALANCE',
              BettingSystem.money(widget.user.balance), Colors.white),
          _walletItem(context, 'MAX BET',
              BettingSystem.money(_maxBet), Colors.white70),
          _walletItem(
            context,
            'PICK',
            '${_selected.length}/${widget.racers.length}',
            Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _walletItem(BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, letterSpacing: 1, fontSize: 9),
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

  Widget _buildAmount(BuildContext context, ThemeData theme) {
    final quick = <double>{
      ...BettingSystem.quickBets(widget.user.balance),
      ...[widget.user.balance * 0.1, widget.user.balance * 0.25].where(
        (value) => value >= BettingSystem.minBet && value <= _maxBet,
      ),
    }.toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Stake',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
            hintText: '0',
            errorText: _error,
            helperText: 'Min ${BettingSystem.money(BettingSystem.minBet)} · max ${BettingSystem.money(_maxBet)}',
          ),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in quick)
              ActionChip(
                label: Text(BettingSystem.money(value)),
                onPressed: () => _setStake(value),
              ),
            ActionChip(
              avatar: const Icon(Icons.functions_rounded, size: 16),
              label: const Text('Max'),
              onPressed: _maxBet <= 0 ? null : () => _setStake(_maxBet),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPicks(BuildContext context, ThemeData theme,
      Map<int, double> oddsTable, Map<int, double> probabilities) {
    final sorted = List<Racer>.from(widget.racers)
      ..sort((a, b) =>
          (probabilities[b.id] ?? 0).compareTo(probabilities[a.id] ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Pick your racers',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                if (_selected.length == widget.racers.length) {
                  _selected.clear();
                } else {
                  _selected.addAll(widget.racers.map((racer) => racer.id));
                }
                _error = null;
              }),
              child: Text(_selected.length == widget.racers.length ? 'Clear' : 'Select all'),
            ),
          ],
        ),
        Text(
          'Each racer posts 10 random stops and the lowest total wins. '
          'Pick one racer, or stack several into a multiple bet that only pays '
          'when every pick wins.',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 10),
        for (final racer in sorted) ...[
          _buildPickTile(context, theme, racer,
              oddsTable[racer.id] ?? 0, probabilities[racer.id] ?? 0),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        if (!_showAll)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showAll = true),
              icon: const Icon(Icons.help_outline_rounded, size: 18),
              label: const Text('How the odds work'),
            ),
          )
        else
          _buildOddsExplainer(context, theme),
      ],
    );
  }

  Widget _buildPickTile(BuildContext context, ThemeData theme, Racer racer,
      double odds, double probability) {
    final selected = _selected.contains(racer.id);
    return InkWell(
      onTap: () => _toggle(racer.id),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? racer.color.withValues(alpha: 0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? racer.color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: racer.color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: racer.color, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(racer.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(racer.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${odds.toStringAsFixed(2)}x  ·  '
                    '${(probability * 100).toStringAsFixed(0)}% to win',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? racer.color : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ThemeData theme) {
    final multiple = _selected.length > 1;
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        multiple ? 'Multiple bet' : 'Single bet',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      Text(
                        _selected.isEmpty
                            ? 'Select a racer'
                            : '${_multiplier.toStringAsFixed(2)}x · returns '
                                '${BettingSystem.money(_payout)}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  if (_selected.isNotEmpty && _stake > 0)
                    Text(
                      'EV ${BettingSystem.money(BettingSystem.expectedProfit(_stake, _selected, widget.racers))}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    _selected.isEmpty
                        ? 'Pick a racer'
                        : 'Bet ${BettingSystem.money(_stake)}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOddsExplainer(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Each racer has a hidden rating, and a racer with a low rating posts a '
        'low total more often, so it gets the shorter price. A multiple bet '
        'multiplies the prices and needs every pick to win. The house keeps '
        '${(BettingSystem.houseEdge * 100).round()}% of each leg, so stacking '
        'picks raises the price and the edge at the same time.',
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
      ),
    );
  }
}
