// ignore_for_file: avoid_print
// Not a test: `dart run tool/balance_sim.dart` prints how a player progresses.
//
// The player checks in every 5 minutes for the first hour, then every [gap] hours.
// Each check-in repairs the ship, buys the cheapest upgrades it can afford, and jumps
// galaxies once a jump would at least double their Dark Matter (and pays >= 1).
import 'package:space_sim/game/format.dart';
import 'package:space_sim/game/game_state.dart';
import 'package:space_sim/game/upgrades.dart';

void main() {
  for (final gap in [2, 4, 8]) {
    print('--- checks in every ${gap}h after the first hour ---');
    run(gap);
  }
}

void run(int gapHours) {
  final s = GameState();
  var t = 0;
  var nextReport = 3600;
  while (t < 5 * 24 * 3600) {
    final step = t < 3600 ? 300 : gapHours * 3600;
    // Tick in 5s chunks so an early-game player also buys during play.
    for (var i = 0; i < step; i += 5) {
      s.tick(5, maxStep: 0.25);
      if (t < 3600) buyAll(s);
    }
    t += step;
    final brokeDown = s.disabled;
    s.repair();
    final reward = s.prestigeReward;
    if (reward > 0 && reward >= s.darkMatter) {
      print(
        '  ${formatDuration(Duration(seconds: t)).padRight(8)} '
        'JUMP at sector ${s.bestSector}: +$reward DM',
      );
      s.prestige();
    }
    buyAll(s);
    if (t >= nextReport) {
      print(
        '  ${formatDuration(Duration(seconds: t)).padRight(8)} '
        'sector ${s.sector.toString().padLeft(3)} best ${s.bestSector.toString().padLeft(3)} '
        'DM ${s.darkMatter.toString().padLeft(4)} jumps ${s.prestiges} '
        'endurance ${formatDuration(s.stats.endurance)}'
        '${brokeDown ? '  (was broken down)' : ''}',
      );
      nextReport = t + 12 * 3600;
    }
  }
}

void buyAll(GameState s) {
  while (true) {
    final options = Upgrade.values.where((u) => !s.isMaxed(u)).toList()
      ..sort((a, b) => s.costOf(a).compareTo(s.costOf(b)));
    if (!s.buy(options.first)) return;
  }
}
