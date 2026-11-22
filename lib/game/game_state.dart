import 'dart:math';

import 'prestige.dart';
import 'sectors.dart';
import 'ships.dart';
import 'upgrades.dart';

enum Phase {
  /// Travelling to the next contact.
  warping,
  fighting,

  /// Hull was destroyed; limping home and patching up.
  repairing,

  /// Integrity ran out. Nothing happens until the player comes back and [GameState.repair]s.
  disabled,
}

/// Seconds the ship spends repairing after its hull hits zero.
const repairSeconds = 6.0;

/// Servicing a ship at or below this integrity earns a tune-up: the reward for
/// coming back. Above it (a top-up a few minutes after the last one) there's none, so
/// tapping Service repeatedly can't keep the boost running.
const tuneUpThreshold = 0.5;

/// A tune-up multiplies damage and credits by this for [tuneUpDuration] of operation.
/// Kept small so it stays a bonus rather than the expected baseline.
const tuneUpBonus = 1.25;
const tuneUpDuration = Duration(minutes: 15);

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
    int? bestEver,
    this.totalKills = 0,
    this.darkMatter = 0,
    this.prestiges = 0,
    double integrity = 1,
    this.tuneUpSeconds = 0,
  }) : levels = {for (final u in Upgrade.values) u: levels?[u] ?? 0},
       bestSector = bestSector ?? sector,
       bestEver = max(bestEver ?? 1, bestSector ?? sector),
       integrity = integrity.clamp(0.0, 1.0) {
    _restartShip();
    if (this.integrity <= 0) phase = Phase.disabled;
  }

  /// Fresh stats, full hull and shields, warping to the next contact.
  void _restartShip() {
    _stats = ShipStats.fromLevels(levels, darkMatter: darkMatter.toDouble());
    hull = _stats.maxHull;
    shield = _stats.maxShield;
    enemy = null;
    phase = Phase.warping;
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

  /// Furthest sector this run (prestige resets it); [bestEver] across all runs.
  int bestSector;
  int bestEver;
  int totalKills;

  /// Permanent prestige currency; see `prestige.dart`.
  int darkMatter;
  int prestiges;

  /// Wear, 1 (fresh) to 0 (broken down). Drains linearly over
  /// [ShipStats.endurance] while the ship is operating, so the breakdown time is
  /// exactly predictable (the controller schedules a notification for it).
  double integrity;

  /// Operating seconds left on the current tune-up (see [tuneUpBonus]).
  double tuneUpSeconds;

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

  bool get disabled => phase == Phase.disabled;

  /// The hull the player flies, from the number of galaxy jumps (cosmetic).
  ShipClass get shipClass => ShipClass.forJumps(prestiges);

  bool get tunedUp => tuneUpSeconds > 0;

  /// Applies to damage and credits; 1 outside a tune-up.
  double get _boost => tunedUp ? tuneUpBonus : 1;

  /// Whether servicing now would earn a tune-up.
  bool get tuneUpAvailable => integrity <= tuneUpThreshold;

  /// Operating time left before a breakdown.
  Duration get timeToBreakdown =>
      disabled ? Duration.zero : _stats.endurance * integrity;

  /// Dark Matter a jump would pay right now.
  int get prestigeReward => darkMatterFor(bestSector);

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
    if (phase == Phase.disabled) return;
    tuneUpSeconds = max(0, tuneUpSeconds - dt);
    integrity -= dt / (_stats.endurance.inMicroseconds / 1e6);
    if (integrity <= 0) {
      _breakDown();
      return;
    }
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
      case Phase.disabled:
        break;
    }
  }

  void _breakDown() {
    integrity = 0;
    enemy = null;
    phase = Phase.disabled;
  }

  /// The player is back: full integrity, and a ship holding position gets going
  /// again. Returns whether it earned a tune-up (integrity was at or below
  /// [tuneUpThreshold]).
  bool repair() {
    final earned = tuneUpAvailable;
    if (earned) tuneUpSeconds = tuneUpDuration.inSeconds.toDouble();
    integrity = 1;
    if (phase == Phase.disabled) _restartShip();
    return earned;
  }

  /// Jumps to a new galaxy: pays [prestigeReward] Dark Matter and starts a new run
  /// (sector 1, no credits, no upgrades). Returns the Dark Matter gained, 0 if the
  /// run isn't deep enough (nothing changes then).
  int prestige() {
    final gain = prestigeReward;
    if (gain <= 0) return 0;
    darkMatter += gain;
    prestiges++;
    credits = 0;
    for (final u in Upgrade.values) {
      levels[u] = 0;
    }
    sector = 1;
    kills = 0;
    bossBlocked = false;
    bestSector = 1;
    integrity = 1;
    lastDiscovery = null;
    _restartShip();
    return gain;
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
      e.hp -= _stats.damage * _boost;
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
    credits += e.reward * _stats.creditMultiplier * _boost;
    totalKills++;
    if (e.isBoss) {
      final found = Discovery.forSector(sector);
      credits += found.credits * _stats.creditMultiplier;
      lastDiscovery = found;
      sector++;
      bestSector = max(bestSector, sector);
      bestEver = max(bestEver, sector);
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
    _stats = ShipStats.fromLevels(levels, darkMatter: darkMatter.toDouble());
    // New plating and shield capacity arrive intact.
    if (phase != Phase.repairing && phase != Phase.disabled) {
      hull += _stats.maxHull - old.maxHull;
      shield += _stats.maxShield - old.maxShield;
    }
    bossBlocked = false;
    return true;
  }

  Map<String, Object?> toJson() => {
    'v': 2,
    'credits': credits,
    'levels': {for (final e in levels.entries) e.key.name: e.value},
    'sector': sector,
    'kills': kills,
    'bossBlocked': bossBlocked,
    'bestSector': bestSector,
    'totalKills': totalKills,
    'bestEver': bestEver,
    'darkMatter': darkMatter,
    'prestiges': prestiges,
    'integrity': integrity,
    'tuneUp': tuneUpSeconds,
  };

  /// Restores progress; the fight in progress restarts with a fresh warp (or stays
  /// broken down). v1 saves (no prestige, no integrity) load as a fresh ship.
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
      bestEver: (json['bestEver'] as num?)?.toInt(),
      darkMatter: max(0, (json['darkMatter'] as num?)?.toInt() ?? 0),
      prestiges: max(0, (json['prestiges'] as num?)?.toInt() ?? 0),
      integrity: (json['integrity'] as num?)?.toDouble() ?? 1,
      tuneUpSeconds: max(
        0,
        min(
          tuneUpDuration.inSeconds.toDouble(),
          (json['tuneUp'] as num?)?.toDouble() ?? 0,
        ),
      ),
    );
  }
}
