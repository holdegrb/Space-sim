import 'dart:math';

/// Prestige: "jump to a new galaxy". Wipes the run (sector, credits, upgrades) for
/// Dark Matter, which permanently multiplies damage, hull, shields and credits.

/// Furthest sector a run must reach before a jump pays anything.
const prestigeMinSector = 25;

/// Each Dark Matter adds this much to the multiplier (10 DM = ×2).
const darkMatterPerUnit = 0.1;

/// Dark Matter a jump would pay for a run that reached [bestSector].
/// 25 → 1, 30 → 4, 40 → 16, 50 → 36, 70 → 100, 100 → 256: deeper runs pay more.
///
/// Quadratic, not exponential: an exponential payout on top of a bonus that
/// compounds damage, hull and credits ran away (sector 270 and 700M DM by day 5 in
/// `tool/balance_sim.dart`).
int darkMatterFor(int bestSector) =>
    bestSector < prestigeMinSector ? 0 : pow((bestSector - 20) / 5, 2).floor();

double darkMatterBonus(double darkMatter) => 1 + darkMatterPerUnit * darkMatter;
