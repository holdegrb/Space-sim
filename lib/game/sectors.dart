import 'dart:math';

/// Regular kills needed in a sector before its boss appears.
const killsPerSector = 10;

const _regions = [
  'Sol Fringe',
  'Kepler Drift',
  'Vega Expanse',
  'Orion Shoals',
  'Cygnus Rift',
  'Draco Reach',
  'Lyra Deep',
  'Perseus Void',
  'Andromeda Gate',
];

const _numerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];

const _enemyNames = [
  'Pirate Scout',
  'Scrap Drone',
  'Raider',
  'Void Wasp',
  'Corsair',
  'Sentinel',
  'Hive Drone',
  'Marauder',
];

const _bossNames = [
  'Pirate Warlord',
  'Dreadnought',
  'Hive Queen',
  'Rogue AI Core',
  'Void Leviathan',
  'Star Eater',
];

/// Sectors come in regions of ten: "Kepler Drift IV" is sector 14.
String regionName(int sector) {
  final r = (sector - 1) ~/ 10;
  return r < _regions.length
      ? _regions[r]
      : 'Uncharted Space ${r - _regions.length + 1}';
}

String sectorName(int sector) =>
    '${regionName(sector)} ${_numerals[(sector - 1) % 10]}';

/// One hostile contact. Only [hp] changes during a fight.
class Enemy {
  Enemy({
    required this.name,
    required this.isBoss,
    required this.maxHp,
    required this.damage,
    required this.fireRate,
    required this.reward,
  }) : hp = maxHp;

  /// The [index]th regular contact (0-based) of [sector], or its boss.
  factory Enemy.forSector(int sector, {int index = 0, bool boss = false}) {
    final g = sector - 1;
    final hp = 15.0 * pow(1.22, g);
    final damage = 3.0 * pow(1.19, g);
    final reward = 4.0 * pow(1.15, g);
    if (boss) {
      return Enemy(
        name: _bossNames[g % _bossNames.length],
        isBoss: true,
        maxHp: hp * 8,
        damage: damage * 2,
        fireRate: 0.8,
        reward: reward * 10,
      );
    }
    return Enemy(
      name: _enemyNames[(g + index) % _enemyNames.length],
      isBoss: false,
      maxHp: hp,
      damage: damage,
      fireRate: 0.8,
      reward: reward,
    );
  }

  final String name;
  final bool isBoss;
  final double maxHp;
  double hp;
  final double damage;
  final double fireRate;
  final double reward;

  bool get destroyed => hp <= 0;
}

/// What the ship finds when it clears a sector: flavour plus a one-off credit haul.
class Discovery {
  const Discovery(this.sector, this.title, this.text, this.credits);

  factory Discovery.forSector(int sector) {
    final t = _discoveries[(sector * 7 + 3) % _discoveries.length];
    return Discovery(sector, t.$1, t.$2, Enemy.forSector(sector).reward * 15);
  }

  final int sector;
  final String title;
  final String text;

  /// Before the salvage multiplier.
  final double credits;
}

const _discoveries = [
  ('Derelict freighter', 'Its hold was still sealed. Cargo salvaged.'),
  ('Abandoned mining outpost', 'The ore silos were half full.'),
  ('Ancient beacon', 'It was still transmitting coordinates. Data sold.'),
  ('Smuggler\'s stash', 'Hidden in an asteroid hollow.'),
  ('Frozen comet', 'Rich in rare ices.'),
  ('Ion storm', 'Your crew harvested charged particles from the edge.'),
  ('Ghost station', 'Empty, but the vault opened.'),
  ('Wrecked battlecruiser', 'Its reactor core still had fuel.'),
  ('Alien monolith', 'Scholars will pay well for these scans.'),
  ('Lost probe', 'Returned to its owners for a reward.'),
];
