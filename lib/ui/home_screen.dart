import 'package:flutter/material.dart';

import '../game/format.dart';
import '../game/game_state.dart';
import '../game/offline.dart';
import '../game/sectors.dart';
import '../game/upgrades.dart';
import '../game_controller.dart';
import 'battle_view.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameController? _controller;
  bool _dialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = GameScope.of(context);
    if (!identical(c, _controller)) {
      _controller?.removeListener(_onTick);
      _controller = c..addListener(_onTick);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onTick());
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    super.dispose();
  }

  /// One-off popups: the offline report, then sector discoveries.
  void _onTick() {
    final c = _controller;
    if (c == null || !mounted || _dialogOpen) return;
    final report = c.pendingReport;
    if (report != null) {
      _dialogOpen = true;
      showDialog<void>(
        context: context,
        builder: (_) => _OfflineDialog(report: report),
      ).whenComplete(() {
        _dialogOpen = false;
        c.dismissReport();
      });
      return;
    }
    final found = c.state.lastDiscovery;
    if (found != null) {
      c.state.lastDiscovery = null;
      final credits = found.credits * c.state.stats.creditMultiplier;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Sector ${found.sector} cleared! ${found.title}: ${found.text} '
              '+${formatNumber(credits)} credits',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 600;
            const battle = _BattlePanel();
            const shop = _UpgradeList();
            if (wide) {
              return const Row(
                children: [
                  Expanded(flex: 3, child: battle),
                  Expanded(flex: 2, child: shop),
                ],
              );
            }
            return const Column(
              children: [
                Expanded(flex: 5, child: battle),
                Expanded(flex: 4, child: shop),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BattlePanel extends StatelessWidget {
  const _BattlePanel();

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final s = c.state;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sectorName(s.sector), style: text.titleLarge),
                    Text(
                      'Sector ${s.sector}  ·  furthest ${s.bestSector}',
                      style: text.bodySmall?.copyWith(color: SpaceColors.muted),
                    ),
                  ],
                ),
              ),
              _Credits(credits: s.credits),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  if (v == 'reset') _confirmReset(context, c);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'reset', child: Text('Reset progress')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SectorProgress(state: s),
          const SizedBox(height: 8),
          Expanded(child: BattleView(state: s)),
          const SizedBox(height: 8),
          _StatBar(
            label: 'Hull',
            value: s.hull,
            max: s.stats.maxHull,
            color: SpaceColors.hull,
          ),
          if (s.stats.maxShield > 0) ...[
            const SizedBox(height: 4),
            _StatBar(
              label: 'Shield',
              value: s.shield,
              max: s.stats.maxShield,
              color: SpaceColors.shield,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, GameController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text('All sectors, credits and upgrades will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) c.reset();
  }
}

class _Credits extends StatelessWidget {
  const _Credits({required this.credits});

  final double credits;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.toll, color: SpaceColors.credits, size: 20),
        const SizedBox(width: 4),
        Text(
          formatNumber(credits),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: SpaceColors.credits,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// "7 / 10 to boss", "BOSS", or the farming notice with a challenge button.
/// Fixed height so the battle view doesn't jump between states.
class _SectorProgress extends StatelessWidget {
  const _SectorProgress({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final small = Theme.of(context).textTheme.bodySmall;
    final Widget child;
    if (s.bossBlocked && s.bossReady) {
      child = Row(
        children: [
          Expanded(
            child: Text(
              'Boss too strong: farming this sector. Upgrade, then try again.',
              style: small?.copyWith(color: SpaceColors.boss),
            ),
          ),
          FilledButton.tonal(
            onPressed: GameScope.of(context).challengeBoss,
            child: const Text('Challenge boss'),
          ),
        ],
      );
    } else if (s.enemy?.isBoss ?? false) {
      child = Text(
        'BOSS: ${s.enemy!.name.toUpperCase()}',
        style: small?.copyWith(
          color: SpaceColors.boss,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      );
    } else {
      child = Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: s.kills / killsPerSector,
                minHeight: 8,
                backgroundColor: SpaceColors.panelHigh,
                color: SpaceColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${s.kills} / $killsPerSector to boss', style: small),
        ],
      );
    }
    return SizedBox(
      height: 40,
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final double value;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        SizedBox(width: 52, child: Text(label, style: small)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: max <= 0 ? 0 : (value / max).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: SpaceColors.panelHigh,
              color: color,
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: Text(
            '${formatNumber(value)} / ${formatNumber(max)}',
            textAlign: TextAlign.right,
            style: small,
          ),
        ),
      ],
    );
  }
}

class _UpgradeList extends StatelessWidget {
  const _UpgradeList();

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: SpaceColors.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'UPGRADES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: SpaceColors.muted,
                letterSpacing: 2,
              ),
            ),
          ),
          for (final u in Upgrade.values)
            _UpgradeTile(upgrade: u, controller: c),
        ],
      ),
    );
  }
}

class _UpgradeTile extends StatelessWidget {
  const _UpgradeTile({required this.upgrade, required this.controller});

  final Upgrade upgrade;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final level = s.levels[upgrade]!;
    final maxed = s.isMaxed(upgrade);
    final text = Theme.of(context).textTheme;
    return ListTile(
      title: Text('${upgrade.label}  ·  Lv $level'),
      subtitle: Text(
        '${upgrade.description}: ${statText(upgrade, s.stats)}',
        style: text.bodySmall?.copyWith(color: SpaceColors.muted),
      ),
      trailing: maxed
          ? const Text('MAX')
          : FilledButton(
              onPressed: s.canBuy(upgrade)
                  ? () => controller.buy(upgrade)
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(88, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.toll, size: 16),
                  const SizedBox(width: 4),
                  Text(formatNumber(s.costOf(upgrade))),
                ],
              ),
            ),
    );
  }
}

/// The current value an upgrade improves, for its tile.
String statText(Upgrade u, ShipStats st) => switch (u) {
  Upgrade.cannons => formatNumber(st.damage),
  Upgrade.targeting => '${st.fireRate.toStringAsFixed(1)}/s',
  Upgrade.hull => formatNumber(st.maxHull),
  Upgrade.shields => st.maxShield == 0 ? 'none' : formatNumber(st.maxShield),
  Upgrade.engines => '${st.warpDelay.toStringAsFixed(2)}s',
  Upgrade.salvage => '×${st.creditMultiplier.toStringAsFixed(2)}',
};

class _OfflineDialog extends StatelessWidget {
  const _OfflineDialog({required this.report});

  final OfflineReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    return AlertDialog(
      title: const Text('While you were away'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your ship kept fighting for ${formatDuration(r.simulated)}.'),
          if (r.capped)
            Text(
              '(Away ${formatDuration(r.away)}; offline progress is capped at '
              '${formatDuration(offlineCap)}.)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
          Text('Contacts destroyed: ${r.kills}'),
          Text('New sectors reached: ${r.sectorsCleared}'),
          Text(
            'Credits earned: ${formatNumber(r.credits)}',
            style: const TextStyle(color: SpaceColors.credits),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Collect'),
        ),
      ],
    );
  }
}
