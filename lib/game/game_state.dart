import 'dart:math';

import 'sectors.dart';
import 'upgrades.dart';

enum Phase {
  /// Travelling to the next contact.
  warping,
  fighting,

  /// Hull was destroyed; limping home and patching up.
  repairing,
}

/// Seconds the ship spends repairing after its hull hits zero.
const repairSeconds = 6.0;

/// The whole game: progress, wallet, upgrades and the fight in progress.
///
/// Pure Dart and deterministic (no RNG, no wall clock): the same [tick]s from the
/// same state always give the same result. That is what lets offline progress just
/// run the real simulation, and lets tests check balance.
class GameState {
  GameState({
    this.credits = 0,
    Map<Upgrade, int>? levels,
    this.sector = 1,
    this.kills = 0,
    this.bossBlocked = false,
    int? bestSector,
    this.totalKills = 0,
  }) : levels = {for (final u in Upgrade.values) u: levels?[u] ?? 0},
       bestSector = bestSector ?? sector {
    _stats = ShipStats.fromLevels(this.levels);
    hull = _stats.maxHull;
    shield = _stats.maxShield;
    phaseTimer = _stats.warpDelay;
  }

  double credits;
  final Map<Upgrade, int> levels;

  /// Current sector, from 1.
  int sector;

  /// Regular kills in this sector, up to [killsPerSector].
  int kills;

  /// After losing to a boss (or retreating), the ship farms regular contacts instead of
  /// challenging the boss, so it doesn't die over and over while idle. Cleared by
  /// [challengeBoss] or by buying any upgrade.
  bool bossBlocked;
  int bestSector;
  int totalKills;

  late ShipStats _stats;
  ShipStats get stats => _stats;

  late double hull;
  late double shield;
  Enemy? enemy;
  Phase phase = Phase.warping;
  late double phaseTimer;
  double playerCooldown = 0;
  double enemyCooldown = 0;

  /// Game time in seconds; drives animation. Not persisted.
  double clock = 0;
  double lastPlayerShot = -100;
  double lastEnemyShot = -100;

  /// Set when a sector is cleared; the UI shows it and clears it.
  Discovery? lastDiscovery;

  bool get bossReady => kills >= killsPerSector;

  /// Advances the simulation by [dt] seconds in steps of at most [maxStep].
  void tick(double dt, {double maxStep = 0.1}) {
    while (dt > 0) {
      final step = min(dt, maxStep);
      _step(step);
      dt -= step;
    }
  }

  void _step(double dt) {
    clock += dt;
    if (phase != Phase.repairing) {
      shield = min(_stats.maxShield, shield + _stats.shieldRegen * dt);
    }
    switch (phase) {
      case Phase.warping:
        phaseTimer -= dt;
        if (phaseTimer <= 0) _spawn();
      case Phase.fighting:
        _fight(dt);
      case Phase.repairing:
        phaseTimer -= dt;
        hull = _stats.maxHull * (1 - max(0, phaseTimer) / repairSeconds);
        if (phaseTimer <= 0) {
          hull = _stats.maxHull;
          shield = _stats.maxShield;
          phase = Phase.warping;
          phaseTimer = _stats.warpDelay;
        }
    }
  }

  void _spawn() {
    final boss = bossReady && !bossBlocked;
    enemy = Enemy.forSector(sector, index: kills, boss: boss);
    phase = Phase.fighting;
    playerCooldown = 0.25;
    enemyCooldown = 1 / enemy!.fireRate;
  }

  void _fight(double dt) {
    final e = enemy!;
    playerCooldown -= dt;
    while (playerCooldown <= 0) {
      e.hp -= _stats.damage;
      lastPlayerShot = clock;
      playerCooldown += 1 / _stats.fireRate;
      if (e.destroyed) {
        _onKill(e);
        return;
      }
    }
    enemyCooldown -= dt;
    while (enemyCooldown <= 0) {
      _takeHit(e.damage);
      lastEnemyShot = clock;
      enemyCooldown += 1 / e.fireRate;
      if (hull <= 0) {
        _onDefeat(e);
        return;
      }
    }
  }

  void _takeHit(double damage) {
    final absorbed = min(shield, damage);
    shield -= absorbed;
    hull -= damage - absorbed;
  }

  void _onKill(Enemy e) {
    credits += e.reward * _stats.creditMultiplier;
    totalKills++;
    if (e.isBoss) {
      final found = Discovery.forSector(sector);
      credits += found.credits * _stats.creditMultiplier;
      lastDiscovery = found;
      sector++;
      bestSector = max(bestSector, sector);
      kills = 0;
      // Patched up at the sector's waypoint.
      hull = _stats.maxHull;
    } else {
      kills = min(kills + 1, killsPerSector);
    }
    enemy = null;
    phase = Phase.warping;
    phaseTimer = _stats.warpDelay;
  }

  void _onDefeat(Enemy e) {
    hull = 0;
    shield = 0;
    enemy = null;
    phase = Phase.repairing;
    phaseTimer = repairSeconds;
    if (e.isBoss) {
      bossBlocked = true;
    } else {
      // Even the regulars are too strong: fall back a sector and farm there.
      kills = 0;
      if (sector > 1) {
        sector--;
        kills = killsPerSector;
      }
      bossBlocked = true;
    }
  }

  void challengeBoss() => bossBlocked = false;

  bool canBuy(Upgrade u) => !isMaxed(u) && credits >= u.cost(levels[u]!);

  bool isMaxed(Upgrade u) => u.maxLevel != null && levels[u]! >= u.maxLevel!;

  double costOf(Upgrade u) => u.cost(levels[u]!);

  bool buy(Upgrade u) {
    if (!canBuy(u)) return false;
    credits -= costOf(u);
    levels[u] = levels[u]! + 1;
    final old = _stats;
    _stats = ShipStats.fromLevels(levels);
    // New plating and shield capacity arrive intact.
    if (phase != Phase.repairing) {
      hull += _stats.maxHull - old.maxHull;
      shield += _stats.maxShield - old.maxShield;
    }
    bossBlocked = false;
    return true;
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'credits': credits,
    'levels': {for (final e in levels.entries) e.key.name: e.value},
    'sector': sector,
    'kills': kills,
    'bossBlocked': bossBlocked,
    'bestSector': bestSector,
    'totalKills': totalKills,
  };

  /// Restores progress; the fight in progress restarts with a fresh warp.
  factory GameState.fromJson(Map<String, Object?> json) {
    final raw = json['levels'];
    final levels = <Upgrade, int>{};
    if (raw is Map) {
      for (final u in Upgrade.values) {
        final v = raw[u.name];
        if (v is int && v >= 0) levels[u] = v;
      }
    }
    final sector = max(1, (json['sector'] as num?)?.toInt() ?? 1);
    return GameState(
      credits: max(0, (json['credits'] as num?)?.toDouble() ?? 0),
      levels: levels,
      sector: sector,
      kills: ((json['kills'] as num?)?.toInt() ?? 0).clamp(0, killsPerSector),
      bossBlocked: json['bossBlocked'] == true,
      bestSector: max(sector, (json['bestSector'] as num?)?.toInt() ?? sector),
      totalKills: (json['totalKills'] as num?)?.toInt() ?? 0,
    );
  }
}
