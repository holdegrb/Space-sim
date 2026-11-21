# CLAUDE.md

Idle (AFK) space-exploration game for Android, in Flutter. Working title **Space Sim**.

| | Value |
|---|---|
| Dart package | `space_sim` |
| Android app ID | `st.octowow.space_sim` (changing it breaks updates over existing installs) |
| Flutter | 3.41.6 (CI pins it) |

```
flutter analyze                  # must stay clean
flutter test
dart run tool/balance_sim.dart   # simulated players over 5 days; rerun after any balance change
```
Code is `dart format` clean. CI and signing: see README.md (same scheme as the Booty Bay app).

## Workflow

- **Always track changes with a pull request.** Every change goes on a branch and gets a PR
  against the default branch (`master`), even small ones. Never push straight to `master`. Push
  follow-ups to the same branch while its PR is open; after it merges, start a new branch and PR.

## Layout

| File | Role |
|---|---|
| `lib/game/game_state.dart` | The whole simulation: combat tick, kills, bosses, defeat, buying, save JSON |
| `lib/game/upgrades.dart` | `Upgrade` (costs) and `ShipStats.fromLevels` (effects) |
| `lib/game/sectors.dart` | Enemy scaling per sector, sector/region names, discoveries |
| `lib/game/prestige.dart` | Galaxy jump: Dark Matter payout and bonus |
| `lib/services/breakdown_alerts.dart` | "Maintenance due" notification (interface + plugin impl) and quiet hours |
| `lib/game/offline.dart` | Offline progress = the real simulation, capped at 12h |
| `lib/game/format.dart` | 1.23K / 4.5M number and duration formatting |
| `lib/game_controller.dart` | Real-time loop (33ms), lifecycle, save/load (`shared_preferences`) |
| `lib/ui/` | `home_screen.dart` (panels, dialogs), `battle_view.dart` (CustomPainter), `theme.dart` |

**Layout:** on phones (< 600 dp wide) the battle fills the screen and the upgrades live in a
bottom sheet (`showUpgradeSheet`, opens at half height) behind a full-width **Upgrades** button
whose badge counts affordable upgrades. The fight is drawn in the upper part of the battle view
so it stays visible above the open sheet. Wide screens (Fold inner) keep battle | upgrades side
by side.

## Rules

- **`lib/game/` is pure Dart and deterministic**: no `Random` without a fixed seed, no
  `DateTime.now()`, no Flutter imports. Offline progress and the balance tests depend on this.
  Time comes in only as `tick(dt)`.
- Offline progress runs the same `tick` with `maxStep: 0.25` (coarser, same rules). Don't add a
  separate "estimated income" formula; it drifts from the real game.
- Balance numbers live only in `upgrades.dart` (player) and `sectors.dart` (enemies). The
  `balance (greedy player)` tests pin wide bands (10 min → sector 5–20, 1h → 20–60); if a change
  moves them, rerun `tool/balance_sim.dart` and update the bands deliberately.
- Boss block: losing to a boss sets `bossBlocked` (farm instead of dying in a loop while idle).
  Buying anything or "Challenge boss" clears it. Losing to regulars retreats a sector.
- **Integrity / maintenance (the "come back" mechanic):** `integrity` drains linearly from 1 to 0
  over `ShipStats.endurance` (4h, +40 min per Repair drones level, max 12h = the offline cap) while
  the ship operates, in every phase except `disabled`. At 0 the ship is `Phase.disabled`: no
  fighting, no credits, no progress, online or offline, until `repair()` (free; the cost is coming
  back). The owner asked for a full stop; research suggested a soft slowdown instead (not adopted;
  ask the owner before changing it). Keep the drain purely time-based: that makes the breakdown
  instant exactly `now + timeToBreakdown`, which the controller schedules as a notification when
  the app is backgrounded and cancels on return. Defeats don't cost integrity for the same reason.
  - Player-facing wording is **"Maintenance due" / "Service"**, never "broken down" / "repair":
    research found punishment framing reads worse than "come collect" framing. Code names
    (`repair`, `disabled`, `integrity`) are unchanged.
  - **Tune-up:** servicing at integrity ≤ `tuneUpThreshold` (0.5) grants `tuneUpBonus` (×1.25
    damage and credits) for `tuneUpDuration` (15 min) of operation; it doesn't tick while
    disabled and is saved (`tuneUp`). The threshold stops tap-spamming Service for a permanent
    boost; keep the bonus small so it stays a bonus, not the baseline.
  - The 4h base covers an evening and max drones cover a night's sleep. Started at 2h, which the
    research put at the very bottom of comparable games' windows (AFK Arena 12h).
  - Alert: one per absence, at `alertTimeFor` (breakdowns 23:00–08:00 local wait until 08:00).
    Players can turn alerts and quiet hours off from the ⋮ menu (`alerts_enabled`,
    `alerts_quiet_hours` in prefs, both default on).
- **Prestige (galaxy jump):** from sector 25, `prestige()` pays `darkMatterFor(bestSector)`
  (quadratic) and resets sector, credits, all upgrade levels (drones too) and integrity. Each Dark
  Matter adds +10% (additive) to damage, hull, shields and credits via `ShipStats.fromLevels`.
  The payout was exponential once and ran away (sector 270, 700M DM by day 5); keep it
  polynomial and check `tool/balance_sim.dart` (it simulates players checking in every 2/4/8h
  and at 8am/1pm/9pm, who service, buy and jump) after touching it. `bestSector` is per run, `bestEver` all-time.
- Saves are versioned (now `'v': 2`; v1 loads as no Dark Matter, full integrity) and `fromJson` tolerates missing/garbage fields. Only progress
  is saved; the fight in progress restarts with a warp. Bump `v` and migrate if the meaning of a
  field changes.
- Lifecycle: `paused`/`hidden`/`detached` stop the loop, save and schedule the breakdown alert;
  `resumed` applies offline time since the last save and cancels the alert. `inactive` keeps
  playing.
- Notifications: `AndroidScheduleMode.inexactAllowWhileIdle` on purpose (exact alarms need
  `SCHEDULE_EXACT_ALARM`, without which scheduling throws on Android 12+); may arrive late under
  Doze. Small icon `drawable/ic_stat_ship` is looked up by name, kept by `res/raw/keep.xml`.
  Boot receivers in the manifest restore it after a reboot. Permission is requested from
  `HomeScreen` (needs an Activity).

## Ideas not built yet

A Dark Matter shop (spend DM on permanent perks, e.g. drones that survive a jump), bulk buy (×10 / max), ship classes,
crew, a star map of cleared sectors, sound, a launcher icon.
