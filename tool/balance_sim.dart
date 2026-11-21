// ignore_for_file: avoid_print
// Not a test: `dart run tool/balance_sim.dart` prints a greedy player's progress.
import 'package:space_sim/game/format.dart';
import 'package:space_sim/game/game_state.dart';
import 'package:space_sim/game/upgrades.dart';

void main() {
  final s = GameState();
  var t = 0;
  const checkpoints = [60, 300, 600, 1800, 3600, 3 * 3600, 8 * 3600, 24 * 3600];
  for (final cp in checkpoints) {
    while (t < cp) {
      s.tick(5, maxStep: 0.25);
      t += 5;
      while (true) {
        final options = Upgrade.values.where((u) => !s.isMaxed(u)).toList()
          ..sort((a, b) => s.costOf(a).compareTo(s.costOf(b)));
        if (!s.buy(options.first)) break;
      }
    }
    print(
      '${formatDuration(Duration(seconds: cp)).padRight(7)} sector ${s.sector} best ${s.bestSector} '
      'credits ${formatNumber(s.credits)} levels ${s.levels.values.toList()} '
      'dps ${formatNumber(s.stats.dps)} blocked ${s.bossBlocked}',
    );
  }
}
