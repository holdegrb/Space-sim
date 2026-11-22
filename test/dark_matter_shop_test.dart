import 'package:flutter_test/flutter_test.dart';
import 'package:space_sim/game/dark_matter_shop.dart';
import 'package:space_sim/game/game_state.dart';
import 'package:space_sim/game/upgrades.dart';

void main() {
  test(
    'buying spends from what is left; the passive bonus keeps every point',
    () {
      final s = GameState(darkMatter: 10);
      final damage0 = s.stats.damage;
      expect(s.darkMatterAvailable, 10);
      expect(s.buyPerk(Perk.cannons), isTrue); // costs 3
      expect(s.darkMatter, 10);
      expect(s.darkMatterSpent, 3);
      expect(s.darkMatterAvailable, 7);
      expect(s.stats.damage, closeTo(damage0 * 1.2, 1e-9));
    },
  );

  test('costs grow, round up, and you cannot overspend', () {
    expect(Perk.cannons.cost(0), 3);
    expect(Perk.cannons.cost(1), 5); // 4.8 rounded up
    expect(Perk.bossBreaker.cost(2), 32);
    final s = GameState(darkMatter: 2);
    expect(s.buyPerk(Perk.cannons), isFalse);
    expect(s.darkMatterSpent, 0);
  });

  test('perks with a max level stop there', () {
    final s = GameState(darkMatter: 1000);
    expect(s.buyPerk(Perk.droneMemory), isTrue);
    expect(s.isPerkMaxed(Perk.droneMemory), isTrue);
    expect(s.buyPerk(Perk.droneMemory), isFalse);
    for (var i = 0; i < 5; i++) {
      expect(s.buyPerk(Perk.warpStart), isTrue);
    }
    expect(s.buyPerk(Perk.warpStart), isFalse);
  });

  test('frame and contracts multiply hull, shields and credits', () {
    final base = GameState(levels: {Upgrade.shields: 3});
    final s = GameState(
      levels: {Upgrade.shields: 3},
      perks: {Perk.frame: 2, Perk.contracts: 1},
    );
    expect(s.stats.maxHull, closeTo(base.stats.maxHull * 1.44, 1e-9));
    expect(s.stats.maxShield, closeTo(base.stats.maxShield * 1.44, 1e-9));
    expect(
      s.stats.creditMultiplier,
      closeTo(base.stats.creditMultiplier * 1.2, 1e-9),
    );
  });

  test('boss breaker kills bosses faster but not regulars', () {
    GameState boss(int level) => GameState(
      kills: 10,
      levels: {Upgrade.cannons: 20, Upgrade.hull: 20},
      perks: {Perk.bossBreaker: level},
    );
    double timeToClear(GameState s) {
      var t = 0.0;
      while (s.sector == 1 && t < 120) {
        s.tick(0.1);
        t += 0.1;
      }
      return t;
    }

    expect(timeToClear(boss(2)), lessThan(timeToClear(boss(0)) * 0.8));
    expect(GameState(perks: {Perk.bossBreaker: 3}).stats.damage, 5);
  });

  test('warp start begins the next run part of the way to your best', () {
    expect(warpStartSector(60, 0), 1);
    expect(warpStartSector(60, 1), 6);
    expect(warpStartSector(60, 5), 30);
    expect(warpStartSector(5, 1), 1);
    final s = GameState(sector: 60, perks: {Perk.warpStart: 2});
    expect(s.jumpStartSector, 12);
    s.prestige();
    expect(s.sector, 12);
    expect(s.bestSector, 12);
    expect(s.bestEver, 60);
  });

  test(
    'drone memory keeps Repair drones through a jump; perks always stay',
    () {
      final kept = GameState(
        sector: 30,
        levels: {Upgrade.drones: 6, Upgrade.cannons: 9},
        perks: {Perk.droneMemory: 1, Perk.cannons: 2},
      )..prestige();
      expect(kept.levels[Upgrade.drones], 6);
      expect(kept.levels[Upgrade.cannons], 0);
      expect(kept.perks[Perk.cannons], 2);

      final lost = GameState(sector: 30, levels: {Upgrade.drones: 6})
        ..prestige();
      expect(lost.levels[Upgrade.drones], 0);
    },
  );

  test('perks and spending survive a save, and bad values are clamped', () {
    final s = GameState(
      darkMatter: 40,
      darkMatterSpent: 11,
      perks: {Perk.cannons: 2, Perk.warpStart: 1},
    );
    final r = GameState.fromJson(s.toJson());
    expect(r.darkMatterSpent, 11);
    expect(r.perks[Perk.cannons], 2);
    expect(r.perks[Perk.warpStart], 1);
    expect(r.perks[Perk.frame], 0);
    expect(r.stats.damage, s.stats.damage);

    final bad = GameState.fromJson({
      'darkMatter': 5,
      'darkMatterSpent': 99,
      'perks': {'droneMemory': 4, 'warpStart': 9, 'cannons': 'x'},
    });
    expect(bad.darkMatterSpent, 5);
    expect(bad.perks[Perk.droneMemory], 1);
    expect(bad.perks[Perk.warpStart], 5);
    expect(bad.perks[Perk.cannons], 0);
  });
}
