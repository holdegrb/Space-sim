// ignore_for_file: avoid_print
// Not a test: `dart run tool/balance_sim.dart` prints how a player progresses.
//
// The player checks in every 5 minutes for the first hour, then on a schedule.
// Each check-in services the ship (earning a tune-up when due), buys the cheapest upgrades it can afford, and jumps
// galaxies once a jump would at least double their Dark Matter (and pays >= 1).
import 'package:space_sim/game/dark_matter_shop.dart';
import 'package:space_sim/game/format.dart';
import 'package:space_sim/game/game_state.dart';
import 'package:space_sim/game/upgrades.dart';

void main() {
  for (final gap in [2, 4, 8]) {
    print('--- checks in every ${gap}h after the first hour ---');
    run((t) => gap * 3600);
  }
  // A casual day: 8am, 1pm and 9pm (starting at 8am), so overnight is an 11h gap.
  print('--- checks in at 8am, 1pm and 9pm ---');
  const day = [5, 8, 11]; // hours to the next check-in from 8am / 1pm / 9pm
  var i = 0;
  run((t) => day[i++ % 3] * 3600);
}

void run(int Function(int t) nextGap) {
  final s = GameState();
  var t = 0;
  var nextReport = 3600;
  var tuneUps = 0;
  while (t < 5 * 24 * 3600) {
    final step = t < 3600 ? 300 : nextGap(t);
    // Tick in 5s chunks so an early-game player also buys during play.
    for (var i = 0; i < step; i += 5) {
      s.tick(5, maxStep: 0.25);
      if (t < 3600) buyAll(s);
    }
    t += step;
    final brokeDown = s.disabled;
    if (s.repair()) tuneUps++;
    final reward = s.prestigeReward;
    if (reward > 0 && reward >= s.darkMatter) {
      print(
        '  ${formatDuration(Duration(seconds: t)).padRight(8)} '
        'JUMP at sector ${s.bestSector}: +$reward DM',
      );
      s.prestige();
    }
    // Spend Dark Matter on the cheapest perk, repeatedly.
    while (true) {
      final perks = Perk.values.where((p) => !s.isPerkMaxed(p)).toList()
        ..sort((a, b) => s.perkCost(a).compareTo(s.perkCost(b)));
      if (perks.isEmpty || !s.buyPerk(perks.first)) break;
    }
    buyAll(s);
    if (t >= nextReport) {
      print(
        '  ${formatDuration(Duration(seconds: t)).padRight(8)} '
        'sector ${s.sector.toString().padLeft(3)} best ${s.bestSector.toString().padLeft(3)} '
        'DM ${s.darkMatter.toString().padLeft(4)} jumps ${s.prestiges} perks ${s.perks.values.fold(0, (a, b) => a + b)} '
        'endurance ${formatDuration(s.stats.endurance)} tune-ups $tuneUps'
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
