import 'dart:math';

import 'game_state.dart';

/// Offline progress stops accruing after this long away.
const offlineCap = Duration(hours: 8);

/// Shorter absences aren't worth a "while you were away" report.
const offlineReportThreshold = Duration(minutes: 1);

class OfflineReport {
  const OfflineReport({
    required this.away,
    required this.simulated,
    required this.credits,
    required this.kills,
    required this.sectorsCleared,
  });

  final Duration away;

  /// [away] clamped to [offlineCap].
  final Duration simulated;
  final double credits;
  final int kills;
  final int sectorsCleared;

  bool get capped => simulated < away;
}

/// Runs the real battle simulation for the time the player was away (up to
/// [offlineCap]), with coarser steps since nobody is watching.
OfflineReport simulateOffline(GameState state, Duration away) {
  if (away.isNegative) away = Duration.zero;
  final simulated = away > offlineCap ? offlineCap : away;
  final credits0 = state.credits;
  final kills0 = state.totalKills;
  final best0 = state.bestSector;
  state.tick(simulated.inMilliseconds / 1000, maxStep: 0.25);
  // Discoveries found offline are summed into the report, not shown one by one.
  state.lastDiscovery = null;
  return OfflineReport(
    away: away,
    simulated: simulated,
    credits: max(0, state.credits - credits0),
    kills: state.totalKills - kills0,
    sectorsCleared: state.bestSector - best0,
  );
}
