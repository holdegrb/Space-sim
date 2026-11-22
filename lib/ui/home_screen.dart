import 'package:flutter/material.dart';

import '../game/format.dart';
import '../game/game_state.dart';
import '../game/offline.dart';
import '../game/prestige.dart';
import '../game/sectors.dart';
import '../game/ships.dart';
import '../game/upgrades.dart';
import '../game_controller.dart';
import '../services/breakdown_alerts.dart';
import 'battle_view.dart';
import 'ship_art_types.dart';
import 'ships.dart';
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
  void initState() {
    super.initState();
    // The breakdown alert is the whole point of coming back; ask once the UI is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alerts = _controller?.alerts;
      if (alerts is LocalBreakdownAlerts) alerts.requestPermission();
    });
  }

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
            // Wide screens (the Fold's inner display) have room for both side by
            // side. Phones give the battle the whole screen, with the upgrades in a
            // sheet that slides up from the button at the bottom.
            if (box.maxWidth >= 600) {
              return const Row(
                children: [
                  Expanded(flex: 3, child: _BattlePanel()),
                  Expanded(flex: 2, child: _UpgradeList()),
                ],
              );
            }
            return const Column(
              children: [
                Expanded(child: _BattlePanel()),
                _UpgradesButton(),
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
                      'Sector ${s.sector}  ·  furthest ${s.bestSector}'
                      '${s.darkMatter > 0 ? '  ·  ${s.darkMatter} DM' : ''}',
                      style: text.bodySmall?.copyWith(color: SpaceColors.muted),
                    ),
                  ],
                ),
              ),
              _Credits(credits: s.credits),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  switch (v) {
                    case 'alerts':
                      c.alertsEnabled = !c.alertsEnabled;
                    case 'quiet':
                      c.quietHours = !c.quietHours;
                    case 'reset':
                      _confirmReset(context, c);
                  }
                },
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                    value: 'alerts',
                    checked: c.alertsEnabled,
                    child: const Text('Maintenance alerts'),
                  ),
                  CheckedPopupMenuItem(
                    value: 'quiet',
                    checked: c.quietHours,
                    enabled: c.alertsEnabled,
                    child: const Text('Quiet hours (11pm–8am)'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Reset progress'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SectorProgress(state: s),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                BattleView(state: s),
                if (s.tunedUp)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _TuneUpChip(seconds: s.tuneUpSeconds),
                  ),
                if (s.disabled)
                  _MaintenanceDue(
                    tuneUp: s.tuneUpAvailable,
                    onService: () => service(context, c),
                  ),
              ],
            ),
          ),
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
          const SizedBox(height: 4),
          _IntegrityBar(state: s, onService: () => service(context, c)),
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

/// The phone layout's way into the upgrades: a full-width button at the bottom
/// (thumb reach) that slides the upgrade sheet up. The badge counts upgrades
/// affordable right now.
class _UpgradesButton extends StatelessWidget {
  const _UpgradesButton();

  @override
  Widget build(BuildContext context) {
    final s = GameScope.of(context).state;
    final affordable = Upgrade.values.where(s.canBuy).length;
    final jump = s.prestigeReward > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton(
          onPressed: () => showUpgradeSheet(context),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.keyboard_arrow_up),
              const SizedBox(width: 8),
              const Text('Upgrades', style: TextStyle(fontSize: 16)),
              if (affordable > 0) ...[
                const SizedBox(width: 10),
                Badge(
                  label: Text('$affordable'),
                  backgroundColor: SpaceColors.credits,
                  textColor: Colors.black,
                ),
              ],
              if (jump) ...[
                const SizedBox(width: 8),
                const Icon(Icons.auto_awesome, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Slides the upgrade list up over the battle. It rebuilds live (credits keep
/// coming in while it's open) because [GameScope] sits above the navigator.
Future<void> showUpgradeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: SpaceColors.panel,
    // Light scrim: the battle stays visible behind the sheet.
    barrierColor: Colors.black26,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (_, scroll) => _UpgradeList(scrollController: scroll),
    ),
  );
}

class _UpgradeList extends StatelessWidget {
  const _UpgradeList({this.scrollController});

  /// Set inside the bottom sheet, which draws its own background.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final c = GameScope.of(context);
    final inSheet = scrollController != null;
    return Container(
      margin: inSheet ? null : const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: inSheet
          ? null
          : BoxDecoration(
              color: SpaceColors.panel,
              borderRadius: BorderRadius.circular(16),
            ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(0, inSheet ? 0 : 8, 0, 8),
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
          _PrestigeTile(controller: c),
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
  Upgrade.drones => formatDuration(st.endurance),
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
          if (r.brokeDownAfter == Duration.zero)
            const Text(
              'Your ship held position the whole time, waiting for service.',
            )
          else if (r.brokeDownAfter != null)
            Text(
              'Your ship fought for ${formatDuration(r.brokeDownAfter!)}, then '
              'maintenance came due and it held position for '
              '${formatDuration(r.idle)}.',
            )
          else
            Text('Your ship kept fighting for ${formatDuration(r.simulated)}.'),
          if (r.capped && r.brokeDownAfter == null)
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
          if (r.brokeDownAfter != null) ...[
            const SizedBox(height: 12),
            Text(
              'Service it to start exploring again and get a tune-up. Repair drones '
              'keep it going longer.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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

/// Services the ship and, if that earned a tune-up, says so.
void service(BuildContext context, GameController c) {
  if (!c.repair()) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Tune-up! +${((tuneUpBonus - 1) * 100).round()}% damage and credits '
          'for ${formatDuration(tuneUpDuration)}.',
        ),
      ),
    );
}

/// Over the battle view while maintenance is due: nothing happens until the ship is
/// serviced.
class _MaintenanceDue extends StatelessWidget {
  const _MaintenanceDue({required this.tuneUp, required this.onService});

  final bool tuneUp;
  final VoidCallback onService;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.build_circle, size: 40, color: SpaceColors.boss),
              const SizedBox(height: 8),
              Text(
                'Maintenance due',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Your ship is holding position until it\'s serviced.',
                textAlign: TextAlign.center,
                style: TextStyle(color: SpaceColors.muted),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onService,
                icon: const Icon(Icons.build),
                label: Text(
                  tuneUp
                      ? 'Service ship (+${((tuneUpBonus - 1) * 100).round()}% tune-up)'
                      : 'Service ship',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown on the battle view while a tune-up is running.
class _TuneUpChip extends StatelessWidget {
  const _TuneUpChip({required this.seconds});

  final double seconds;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SpaceColors.credits.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceColors.credits.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, size: 14, color: SpaceColors.credits),
            const SizedBox(width: 2),
            Text(
              'Tune-up +${((tuneUpBonus - 1) * 100).round()}% · '
              '${formatDuration(Duration(seconds: seconds.ceil()))}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: SpaceColors.credits),
            ),
          ],
        ),
      ),
    );
  }
}

/// Time until maintenance is due, with a free Service button (the cost is coming
/// back). Servicing at half or below also earns a tune-up.
class _IntegrityBar extends StatelessWidget {
  const _IntegrityBar({required this.state, required this.onService});

  final GameState state;
  final VoidCallback onService;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final small = Theme.of(context).textTheme.bodySmall;
    final color = s.integrity > 0.5
        ? SpaceColors.accent
        : (s.integrity > 0.2 ? SpaceColors.boss : SpaceColors.enemy);
    return Row(
      children: [
        SizedBox(width: 52, child: Text('Service', style: small)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.integrity,
              minHeight: 8,
              backgroundColor: SpaceColors.panelHigh,
              color: color,
            ),
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            s.disabled ? 'due' : formatDuration(s.timeToBreakdown),
            textAlign: TextAlign.right,
            style: small,
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: s.integrity < 0.995 ? onService : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(s.tuneUpAvailable ? 'Service ⚡' : 'Service'),
        ),
      ],
    );
  }
}

/// "Jump to a new galaxy": shows the Dark Matter bonus and what a jump pays.
class _PrestigeTile extends StatelessWidget {
  const _PrestigeTile({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final reward = s.prestigeReward;
    final bonus = darkMatterBonus(s.darkMatter.toDouble());
    final small = Theme.of(context).textTheme.bodySmall;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceColors.panelHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceColors.prestige.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: SpaceColors.prestige,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Galaxy jump',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${s.darkMatter} Dark Matter',
                style: small?.copyWith(color: SpaceColors.prestige),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Start over in a new galaxy (sector 1, no credits or upgrades) for Dark '
            'Matter. Each one adds ${(darkMatterPerUnit * 100).round()}% damage, hull, '
            'shields and credits, forever. Now: ×${bonus.toStringAsFixed(1)}.',
            style: small?.copyWith(color: SpaceColors.muted),
          ),
          const SizedBox(height: 10),
          _ShipUpgradePreview(current: s.shipClass),
          const SizedBox(height: 10),
          if (reward > 0) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: SpaceColors.prestige,
              ),
              onPressed: () => _confirm(context, reward),
              icon: const Icon(Icons.rocket_launch, size: 18),
              label: Text('Jump for +$reward Dark Matter'),
            ),
            const SizedBox(height: 4),
            Text(
              'Deeper runs pay much more: sector ${s.bestSector + 5} would pay '
              '${darkMatterFor(s.bestSector + 5)}.',
              style: small?.copyWith(color: SpaceColors.muted),
            ),
          ] else
            Text(
              'Reach sector $prestigeMinSector to jump (furthest this run: '
              '${s.bestSector}).',
              style: small,
            ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, int reward) async {
    final next = controller.state.shipClass.next;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to a new galaxy?'),
        content: Text(
          'You gain $reward Dark Matter and lose this run\'s sectors, credits and '
          'upgrades.'
          '${next == null ? '' : ' Your ship becomes the ${next.fullName}.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Jump'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final before = controller.state.shipClass;
    if (controller.prestige() > 0 && controller.state.shipClass != before) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'New ship: the ${controller.state.shipClass.fullName}!',
            ),
          ),
        );
    }
  }
}

/// In the galaxy-jump card: the ship you fly now and the one the next jump brings.
class _ShipUpgradePreview extends StatelessWidget {
  const _ShipUpgradePreview({required this.current});

  final ShipClass current;

  @override
  Widget build(BuildContext context) {
    final next = current.next;
    final small = Theme.of(context).textTheme.bodySmall;
    Widget ship(ShipClass c, String caption) => Expanded(
      child: Column(
        children: [
          ShipArtView(art: playerArt(c), height: 52),
          const SizedBox(height: 2),
          Text(
            c.label,
            style: Theme.of(context).textTheme.labelLarge,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            caption,
            style: small?.copyWith(color: SpaceColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return Row(
      children: [
        ship(current, 'Your ship'),
        if (next != null) ...[
          const Icon(Icons.arrow_forward, color: SpaceColors.prestige),
          ship(next, 'Next jump'),
        ],
      ],
    );
  }
}

/// A [ShipArt] as a widget, scaled to [height].
class ShipArtView extends StatelessWidget {
  const ShipArtView({super.key, required this.art, required this.height});

  final ShipArt art;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height * art.width / art.height;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _ArtPainter(art)),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art);

  final ShipArt art;

  @override
  void paint(Canvas canvas, Size size) =>
      art.paint(canvas, size.center(Offset.zero), size.width);

  @override
  bool shouldRepaint(_ArtPainter old) => old.art != art;
}
