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
| `lib/services/breakdown_alerts.dart` | Local notification when the ship breaks down (interface + plugin impl) |
| `lib/game/offline.dart` | Offline progress = the real simulation, capped at 8h |
| `lib/game/format.dart` | 1.23K / 4.5M number and duration formatting |
| `lib/game_controller.dart` | Real-time loop (33ms), lifecycle, save/load (`shared_preferences`) |
| `lib/ui/` | `home_screen.dart` (panels, dialogs), `battle_view.dart` (CustomPainter), `theme.dart` |

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
- **Integrity / breakdown (the "come back" mechanic):** `integrity` drains linearly from 1 to 0
  over `ShipStats.endurance` (2h, +30 min per Repair drones level, max 8h = the offline cap) while
  the ship operates, in every phase except `disabled`. At 0 the ship is `Phase.disabled`: no
  fighting, no credits, no progress, online or offline, until `repair()` (free; the cost is coming
  back). Keep the drain purely time-based: that makes the breakdown instant exactly
  `now + timeToBreakdown`, which the controller schedules as a notification when the app is
  backgrounded and cancels on return. Defeats don't cost integrity for the same reason.
- **Prestige (galaxy jump):** from sector 25, `prestige()` pays `darkMatterFor(bestSector)`
  (quadratic) and resets sector, credits, all upgrade levels (drones too) and integrity. Each Dark
  Matter adds +10% (additive) to damage, hull, shields and credits via `ShipStats.fromLevels`.
  The payout was exponential once and ran away (sector 270, 700M DM by day 5); keep it
  polynomial and check `tool/balance_sim.dart` (it simulates players checking in every 2/4/8h
  who repair, buy and jump) after touching it. `bestSector` is per run, `bestEver` all-time.
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
