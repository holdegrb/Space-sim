import 'dart:math';

import 'dark_matter_shop.dart';
import 'prestige.dart';

/// Everything the player can buy with credits. Levels start at 0; [cost] grows
/// geometrically. Effects live in [ShipStats.fromLevels] so balance is in one place.
enum Upgrade {
  cannons('Cannons', 'Damage per shot', 10, 1.2),
  targeting('Targeting', 'Shots per second', 25, 1.28),
  hull('Hull plating', 'Maximum hull', 10, 1.2),
  shields('Shield generator', 'Shield capacity (regenerates)', 30, 1.24),
  engines('Warp engines', 'Faster warp to the next contact', 40, 1.45),
  salvage('Salvage bay', 'Credits from every kill', 60, 1.35),
  drones('Repair drones', 'Time out before maintenance is due', 100, 1.6);

  const Upgrade(this.label, this.description, this.baseCost, this.costGrowth);

  final String label;
  final String description;
  final double baseCost;
  final double costGrowth;

  /// Engines stop helping once the warp delay hits its floor; drones once endurance
  /// reaches the offline cap.
  int? get maxLevel => switch (this) {
    Upgrade.engines => 20,
    Upgrade.drones => 12,
    _ => null,
  };

  double cost(int level) => baseCost * pow(costGrowth, level);
}

/// The ship's combat numbers, derived purely from upgrade levels.
class ShipStats {
  const ShipStats({
    required this.damage,
    required this.fireRate,
    required this.maxHull,
    required this.maxShield,
    required this.shieldRegen,
    required this.warpDelay,
    required this.creditMultiplier,
    required this.endurance,
    this.bossDamageMultiplier = 1,
  });

  /// [darkMatter] is the permanent prestige bonus (see `prestige.dart`); [perks]
  /// are Dark Matter shop levels (see `dark_matter_shop.dart`).
  factory ShipStats.fromLevels(
    Map<Upgrade, int> levels, {
    double darkMatter = 0,
    Map<Perk, int> perks = const {},
  }) {
    int l(Upgrade u) => levels[u] ?? 0;
    int p(Perk k) => perks[k] ?? 0;
    final dm = darkMatterBonus(darkMatter);
    final frame = pow(1.2, p(Perk.frame));
    final shield = l(Upgrade.shields) == 0
        ? 0.0
        : 12.0 * l(Upgrade.shields) * pow(1.1, l(Upgrade.shields)) * dm * frame;
    return ShipStats(
      damage:
          5.0 * pow(1.13, l(Upgrade.cannons)) * dm * pow(1.2, p(Perk.cannons)),
      fireRate: 1.0 + 0.1 * l(Upgrade.targeting),
      maxHull: 50.0 * pow(1.13, l(Upgrade.hull)) * dm * frame,
      maxShield: shield,
      // A fifth of capacity per second.
      shieldRegen: shield * 0.2,
      warpDelay: max(0.3, 2.0 - 0.085 * l(Upgrade.engines)),
      creditMultiplier:
          (1.0 + 0.15 * l(Upgrade.salvage)) * dm * pow(1.2, p(Perk.contracts)),
      // 4h covers an evening; max level (12h) covers a night's sleep.
      endurance: Duration(minutes: 240 + 40 * l(Upgrade.drones)),
      bossDamageMultiplier: 1 + 0.5 * p(Perk.bossBreaker),
    );
  }

  final double damage;
  final double fireRate;
  final double maxHull;
  final double maxShield;
  final double shieldRegen;

  /// Seconds between one contact dying and the next one appearing.
  final double warpDelay;
  final double creditMultiplier;

  /// Extra damage against bosses (Boss breaker perk); 1 without it.
  final double bossDamageMultiplier;

  /// How long the ship can operate from full integrity before maintenance is due
  /// and it holds position until the player comes back to service it.
  final Duration endurance;

  double get dps => damage * fireRate;
}
