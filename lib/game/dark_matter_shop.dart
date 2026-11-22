import 'dart:math';

/// Permanent perks bought with Dark Matter. They survive every galaxy jump.
///
/// Spending Dark Matter never weakens its passive bonus: the bonus counts every
/// point ever earned (`GameState.darkMatter`), and the shop spends from what's left
/// after earlier purchases (`GameState.darkMatterAvailable`).
enum Perk {
  cannons(
    'Overcharged cannons',
    '+20% damage per level',
    baseCost: 3,
    costGrowth: 1.6,
  ),
  frame(
    'Reinforced frame',
    '+20% hull and shields per level',
    baseCost: 3,
    costGrowth: 1.6,
  ),
  contracts(
    'Salvage contracts',
    '+20% credits per level',
    baseCost: 3,
    costGrowth: 1.6,
  ),
  bossBreaker(
    'Boss breaker',
    '+50% damage against bosses per level',
    baseCost: 8,
    costGrowth: 2,
  ),
  warpStart(
    'Warp start',
    'Each run starts 10% of the way to your furthest sector per level',
    baseCost: 5,
    costGrowth: 2,
    maxLevel: 5,
  ),
  droneMemory(
    'Drone memory',
    'Repair drones keep their levels through a galaxy jump',
    baseCost: 25,
    costGrowth: 1,
    maxLevel: 1,
  );

  const Perk(
    this.label,
    this.description, {
    required this.baseCost,
    required this.costGrowth,
    this.maxLevel,
  });

  final String label;
  final String description;
  final int baseCost;
  final double costGrowth;
  final int? maxLevel;

  /// Whole Dark Matter, rounded up so a price never looks cheaper than it is.
  int cost(int level) => (baseCost * pow(costGrowth, level)).ceil();
}

/// The sector a new run starts in after a jump, from the furthest sector ever
/// reached and the Warp start level.
int warpStartSector(int bestEver, int warpStartLevel) =>
    max(1, (bestEver * 0.1 * warpStartLevel).floor());
