# Space Sim (working title)

An idle space-exploration game for Android, built with Flutter.

Your ship pushes deeper into space on its own, fighting whatever it meets. Destroy 10 contacts
in a sector and its boss appears. Beat the boss to chart the next sector and uncover a discovery
(derelicts, stashes, anomalies) with a credit haul. Spend credits on upgrades. The ship keeps
fighting while you're away, but not forever: see wear below.

- **Upgrades:** cannons (damage), targeting (fire rate), hull plating, shield generator
  (regenerating), warp engines (less downtime between fights), salvage bay (more credits).
- **Maintenance:** the ship runs for 4 hours after a service (up to 12 with Repair drones).
  Then maintenance is due and it holds position, earning nothing, until you come back and tap
  **Service**. Servicing is free, and if the ship was at half or below you get a 15-minute
  **tune-up** (+25% damage and credits). A notification tells you when maintenance is due; it
  waits until 8am if that falls overnight, and both can be turned off from the ⋮ menu.
- **Ships:** you start in a Wayfarer-class scout; every galaxy jump moves you up a class, up
  to the Aegis-class dreadnought. Enemies come from four factions: Redwake Corsairs, the Hive
  Swarm, the Null Choir and the Void Brood.
- **Galaxy jump (prestige):** from sector 25 you can start over in a new galaxy for Dark Matter.
  Each point is a permanent +10% to damage, hull, shields and credits. Deeper runs pay more.
- **Dark Matter shop:** spend Dark Matter on perks that last forever: stronger cannons, frame
  and salvage contracts, extra damage against bosses, starting later runs deeper (Warp start)
  and keeping Repair drones through a jump. Spending never lowers the Dark Matter bonus.
- **Losing** is never a game over. Lose to a boss and the ship repairs and farms the sector until
  you upgrade or tap **Challenge boss**. Lose to regular contacts and it falls back a sector.

## Development

```
flutter pub get
flutter analyze
flutter test
dart run tool/balance_sim.dart   # simulated players over 5 days (check-ins, jumps), for tuning
flutter build apk --release
```

Flutter 3.41.6 (pinned in CI).

## Releases

CI (`.github/workflows/build-apk.yml`) runs analyze and the tests, then builds an APK on every
push and publishes it as a GitHub Release `build-<run number>` with `SpaceSim.apk`. Builds off
`master` are pre-releases. The run number is the versionCode, so each build installs as an update.

To get updates that install over each other, add the four signing secrets to this repo (Settings →
Secrets and variables → Actions): `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Without them each build uses a throwaway debug key and
can't update the previous install. Never commit a keystore or `android/key.properties`.
