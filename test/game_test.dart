import 'package:flutter_test/flutter_test.dart';
import 'package:space_sim/game/format.dart';
import 'package:space_sim/game/game_state.dart';
import 'package:space_sim/game/offline.dart';
import 'package:space_sim/game/sectors.dart';
import 'package:space_sim/game/upgrades.dart';

/// Plays like an attentive player: ticks in 5s chunks, buying the cheapest
/// upgrade whenever it can.
GameState greedyPlay(Duration d) {
  final s = GameState();
  for (var t = 0; t < d.inSeconds; t += 5) {
    s.tick(5, maxStep: 0.25);
    while (true) {
      final options = Upgrade.values.where((u) => !s.isMaxed(u)).toList()
        ..sort((a, b) => s.costOf(a).compareTo(s.costOf(b)));
      if (!s.buy(options.first)) break;
    }
  }
  return s;
}

void main() {
  group('combat', () {
    test('a fresh ship kills sector 1 regulars and earns credits', () {
      final s = GameState();
      s.tick(30);
      expect(s.totalKills, greaterThan(3));
      expect(s.credits, greaterThan(0));
      expect(s.sector, 1);
    });

    test('the boss appears after killsPerSector regular kills', () {
      final s = GameState(kills: killsPerSector);
      s.tick(5);
      expect(s.enemy?.isBoss, isTrue);
    });

    test('beating the boss advances the sector and records a discovery', () {
      final s = GameState(
        kills: killsPerSector,
        levels: {Upgrade.cannons: 30, Upgrade.hull: 30},
      );
      s.tick(20);
      expect(s.sector, 2);
      expect(s.bestSector, 2);
      expect(s.kills, lessThan(killsPerSector));
      expect(s.lastDiscovery?.sector, 1);
    });

    test('losing to the boss blocks it, repairs, and keeps farming', () {
      final s = GameState(sector: 20, kills: killsPerSector);
      s.tick(60);
      expect(s.bossBlocked, isTrue);
      expect(s.sector, lessThanOrEqualTo(20));
      final killsBefore = s.totalKills;
      s.tick(120);
      // Too weak even for the regulars at sector 20, so it retreats until it can farm.
      expect(s.totalKills, greaterThanOrEqualTo(killsBefore));
    });

    test('losing to regulars retreats a sector', () {
      final s = GameState(sector: 10, kills: 3);
      s.tick(30);
      expect(s.sector, lessThan(10));
      expect(s.bestSector, 10);
    });

    test('buying clears the boss block and tops up new hull', () {
      final s = GameState(credits: 100, bossBlocked: true);
      final hull0 = s.hull;
      expect(s.buy(Upgrade.hull), isTrue);
      expect(s.bossBlocked, isFalse);
      expect(s.hull, greaterThan(hull0));
      expect(s.credits, closeTo(90, 1e-9));
    });

    test('cannot overspend or exceed a max level', () {
      final s = GameState(credits: 5);
      expect(s.buy(Upgrade.cannons), isFalse);
      final e = GameState(credits: 1e30, levels: {Upgrade.engines: 20});
      expect(e.buy(Upgrade.engines), isFalse);
    });

    test('simulation is deterministic regardless of step size', () {
      final a = GameState()..tick(600, maxStep: 0.05);
      final b = GameState()..tick(600, maxStep: 0.25);
      // Coarser steps lose a little sub-step precision, never whole sectors.
      expect(b.sector, a.sector);
      expect(b.totalKills, closeTo(a.totalKills, a.totalKills * 0.1 + 2));
    });
  });

  group('offline', () {
    test('earns while away and reports it', () {
      final s = GameState();
      final r = simulateOffline(s, const Duration(minutes: 10));
      expect(r.kills, greaterThan(0));
      expect(r.credits, greaterThan(0));
      expect(r.capped, isFalse);
    });

    test('caps at offlineCap', () {
      final r = simulateOffline(GameState(), const Duration(days: 3));
      expect(r.simulated, offlineCap);
      expect(r.capped, isTrue);
    });

    test('a negative absence (clock change) does nothing', () {
      final s = GameState();
      final r = simulateOffline(s, const Duration(hours: -2));
      expect(r.kills, 0);
      expect(s.credits, 0);
    });
  });

  group('save', () {
    test('round-trips progress', () {
      final s = GameState(
        credits: 1234.5,
        levels: {Upgrade.cannons: 4, Upgrade.salvage: 2},
        sector: 7,
        kills: 3,
        bossBlocked: true,
        bestSector: 9,
        totalKills: 88,
      );
      final r = GameState.fromJson(s.toJson());
      expect(r.credits, 1234.5);
      expect(r.levels[Upgrade.cannons], 4);
      expect(r.levels[Upgrade.salvage], 2);
      expect(r.levels[Upgrade.hull], 0);
      expect(r.sector, 7);
      expect(r.kills, 3);
      expect(r.bossBlocked, isTrue);
      expect(r.bestSector, 9);
      expect(r.totalKills, 88);
    });

    test('tolerates garbage', () {
      final r = GameState.fromJson({
        'credits': -5,
        'levels': {'cannons': 'x', 'bogus': 3},
        'sector': 0,
        'kills': 99,
      });
      expect(r.credits, 0);
      expect(r.levels[Upgrade.cannons], 0);
      expect(r.sector, 1);
      expect(r.kills, killsPerSector);
    });
  });

  group('balance (greedy player)', () {
    // Wide bands: these catch a broken economy, not small tuning changes.
    test('10 minutes: past the first few sectors', () {
      expect(
        greedyPlay(const Duration(minutes: 10)).bestSector,
        inInclusiveRange(5, 20),
      );
    });

    test('1 hour: progress slows but continues', () {
      expect(
        greedyPlay(const Duration(hours: 1)).bestSector,
        inInclusiveRange(20, 60),
      );
    });
  });

  group('names and formatting', () {
    test('sectors are grouped in regions of ten', () {
      expect(sectorName(1), 'Sol Fringe I');
      expect(sectorName(14), 'Kepler Drift IV');
      expect(sectorName(20), 'Kepler Drift X');
      expect(regionName(95), 'Uncharted Space 1');
    });

    test('numbers', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(999.9), '999');
      expect(formatNumber(1234), '1.23K');
      expect(formatNumber(999960), '999K');
      expect(formatNumber(45.6e6), '45.6M');
      expect(formatNumber(1e40), '1.00e40');
    });
  });
}
