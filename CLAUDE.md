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
dart run tool/balance_sim.dart   # greedy player over 24h; rerun after any balance change
```
Code is `dart format` clean. CI and signing: see README.md (same scheme as the Booty Bay app).

## Layout

| File | Role |
|---|---|
| `lib/game/game_state.dart` | The whole simulation: combat tick, kills, bosses, defeat, buying, save JSON |
| `lib/game/upgrades.dart` | `Upgrade` (costs) and `ShipStats.fromLevels` (effects) |
| `lib/game/sectors.dart` | Enemy scaling per sector, sector/region names, discoveries |
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
- Saves are versioned (`'v': 1`) and `fromJson` tolerates missing/garbage fields. Only progress
  is saved; the fight in progress restarts with a warp. Bump `v` and migrate if the meaning of a
  field changes.
- Lifecycle: `paused`/`hidden`/`detached` stop the loop and save; `resumed` applies offline time
  since the last save. `inactive` keeps playing.

## Ideas not built yet

Prestige/rebirth (the curve flattens around sector 50–65), bulk buy (×10 / max), ship classes,
crew, a star map of cleared sectors, sound, a launcher icon.
