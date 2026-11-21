import 'package:flutter_test/flutter_test.dart';
import 'package:space_sim/game/format.dart';
import 'package:space_sim/game/game_state.dart';
import 'package:space_sim/game/offline.dart';
import 'package:space_sim/game/prestige.dart';
import 'package:space_sim/game/sectors.dart';
import 'package:space_sim/game/upgrades.dart';

/// Plays like an attentive player: ticks in 5s chunks, buying the cheapest
/// upgrade whenever it can.
GameState greedyPlay(Duration d, {int darkMatter = 0}) {
  final s = GameState(darkMatter: darkMatter);
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

  group('integrity (must come back to repair)', () {
    test('drains over the endurance, then the ship breaks down and stops', () {
      final s = GameState();
      expect(s.stats.endurance, const Duration(hours: 4));
      s.tick(2 * 3600, maxStep: 0.25);
      expect(s.integrity, closeTo(0.5, 0.001));
      expect(s.timeToBreakdown.inMinutes, closeTo(120, 1));
      s.tick(2 * 3600 + 1, maxStep: 0.25);
      expect(s.disabled, isTrue);
      expect(s.timeToBreakdown, Duration.zero);
      final kills = s.totalKills;
      final credits = s.credits;
      s.tick(3600, maxStep: 0.25);
      expect(s.totalKills, kills);
      expect(s.credits, credits);
    });

    test('repair restores integrity and restarts a broken-down ship', () {
      final s = GameState(integrity: 0);
      expect(s.disabled, isTrue);
      s.repair();
      expect(s.disabled, isFalse);
      expect(s.integrity, 1);
      s.tick(30);
      expect(s.totalKills, greaterThan(0));
    });

    test('repair drones extend endurance', () {
      final s = GameState(credits: 1e9);
      s.buy(Upgrade.drones);
      s.buy(Upgrade.drones);
      expect(s.stats.endurance, const Duration(hours: 5, minutes: 20));
      final maxed = GameState(
        levels: {Upgrade.drones: Upgrade.drones.maxLevel!},
      );
      expect(maxed.stats.endurance, offlineCap);
    });

    test('servicing at half or below earns a tune-up; topping up does not', () {
      final s = GameState(integrity: 0.9);
      expect(s.repair(), isFalse);
      expect(s.tunedUp, isFalse);
      final low = GameState(integrity: 0.5);
      expect(low.repair(), isTrue);
      expect(low.tuneUpSeconds, tuneUpDuration.inSeconds);
      // A second tap straight after earns nothing more.
      expect(low.repair(), isFalse);
      final down = GameState(integrity: 0);
      expect(down.repair(), isTrue);
      expect(down.disabled, isFalse);
    });

    test('a tune-up boosts damage and credits, then wears off', () {
      final plain = GameState()..tick(120);
      final boosted = GameState(tuneUpSeconds: 900)..tick(120);
      expect(boosted.credits, greaterThan(plain.credits * 1.2));
      expect(boosted.tuneUpSeconds, closeTo(780, 0.01));
      boosted.tick(800);
      expect(boosted.tunedUp, isFalse);
    });

    test('a tune-up does not tick down while maintenance is due', () {
      final s = GameState(integrity: 0, tuneUpSeconds: 100)..tick(60);
      expect(s.tuneUpSeconds, 100);
    });

    test('offline report says when the ship broke down', () {
      final s = GameState();
      final r = simulateOffline(s, const Duration(hours: 7));
      expect(r.brokeDownAfter, const Duration(hours: 4));
      expect(r.idle, const Duration(hours: 3));
      expect(s.disabled, isTrue);

      final again = simulateOffline(s, const Duration(hours: 1));
      expect(again.brokeDownAfter, Duration.zero);
      expect(again.kills, 0);
    });

    test('no breakdown within endurance', () {
      final r = simulateOffline(GameState(), const Duration(hours: 3));
      expect(r.brokeDownAfter, isNull);
    });
  });

  group('prestige', () {
    test('pays nothing before the minimum sector', () {
      final s = GameState(sector: 24, credits: 50);
      expect(s.prestigeReward, 0);
      expect(s.prestige(), 0);
      expect(s.sector, 24);
      expect(s.credits, 50);
    });

    test('payout grows with depth', () {
      expect(darkMatterFor(prestigeMinSector), 1);
      expect(darkMatterFor(40), 16);
      expect(darkMatterFor(70), 100);
    });

    test('resets the run, keeps Dark Matter, and boosts stats', () {
      final s = GameState(
        sector: 40,
        credits: 1e6,
        levels: {Upgrade.cannons: 30, Upgrade.drones: 4},
        integrity: 0.3,
        totalKills: 500,
      );
      final base = GameState().stats;
      expect(s.prestige(), 16);
      expect(s.darkMatter, 16);
      expect(s.prestiges, 1);
      expect(s.sector, 1);
      expect(s.bestSector, 1);
      expect(s.bestEver, 40);
      expect(s.credits, 0);
      expect(s.levels.values.every((l) => l == 0), isTrue);
      expect(s.integrity, 1);
      expect(s.totalKills, 500);
      expect(s.stats.damage, closeTo(base.damage * 2.6, 1e-9));
      expect(s.stats.maxHull, closeTo(base.maxHull * 2.6, 1e-9));
      expect(s.stats.creditMultiplier, closeTo(2.6, 1e-9));
      expect(s.hull, s.stats.maxHull);
    });

    test('a boosted second run outpaces the first', () {
      final first = greedyPlay(const Duration(minutes: 30));
      final boosted = greedyPlay(const Duration(minutes: 30), darkMatter: 20);
      expect(boosted.bestSector, greaterThan(first.bestSector + 5));
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
        bestEver: 30,
        darkMatter: 12,
        prestiges: 2,
        integrity: 0.25,
        tuneUpSeconds: 42,
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
      expect(r.bestEver, 30);
      expect(r.darkMatter, 12);
      expect(r.prestiges, 2);
      expect(r.integrity, 0.25);
      expect(r.tuneUpSeconds, 42);
      expect(r.stats.damage, s.stats.damage);
    });

    test('a broken-down ship stays broken down after a reload', () {
      final r = GameState.fromJson(GameState(integrity: 0).toJson());
      expect(r.disabled, isTrue);
    });

    test('v1 saves load with a fresh ship and no Dark Matter', () {
      final r = GameState.fromJson({'v': 1, 'credits': 10, 'sector': 5});
      expect(r.integrity, 1);
      expect(r.darkMatter, 0);
      expect(r.bestEver, 5);
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
