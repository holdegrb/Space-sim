# Space Sim (working title)

An idle space-exploration game for Android, built with Flutter.

Your ship pushes deeper into space on its own, fighting whatever it meets. Destroy 10 contacts
in a sector and its boss appears. Beat the boss to chart the next sector and uncover a discovery
(derelicts, stashes, anomalies) with a credit haul. Spend credits on upgrades. The ship keeps
fighting while you're away, but not forever: see wear below.

- **Upgrades:** cannons (damage), targeting (fire rate), hull plating, shield generator
  (regenerating), warp engines (less downtime between fights), salvage bay (more credits).
- **Wear:** the ship wears down while it's out (2 hours from a fresh repair, up to 8 with
  Repair drones). When it's worn out the ship breaks down and stops completely, so nothing more
  is earned until you come back and tap **Repair**. Repairs are free, and you get a
  notification when it breaks down.
- **Galaxy jump (prestige):** from sector 25 you can start over in a new galaxy for Dark Matter.
  Each point is a permanent +10% to damage, hull, shields and credits. Deeper runs pay more.
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
