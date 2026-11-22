import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:space_sim/game/game_state.dart';
import 'package:space_sim/game/sectors.dart';
import 'package:space_sim/game/ships.dart';
import 'package:space_sim/ui/ships.dart';

void main() {
  test(
    'each galaxy jump moves up one ship class, topping out at the Aegis',
    () {
      expect(ShipClass.forJumps(0), ShipClass.wayfarer);
      expect(ShipClass.forJumps(1), ShipClass.meridian);
      expect(ShipClass.forJumps(4), ShipClass.bastion);
      expect(ShipClass.forJumps(5), ShipClass.aegis);
      expect(ShipClass.forJumps(50), ShipClass.aegis);
      expect(ShipClass.aegis.next, isNull);
      expect(ShipClass.wayfarer.next, ShipClass.meridian);
      expect(ShipClass.kestrel.fullName, 'Kestrel-class frigate');
    },
  );

  test('the game state flies the class for its jumps', () {
    expect(GameState().shipClass, ShipClass.wayfarer);
    final s = GameState(sector: 30)..prestige();
    expect(s.shipClass, ShipClass.meridian);
  });

  test('every enemy the game can spawn has a drawing', () {
    final names = <String>{};
    for (var sector = 1; sector <= 30; sector++) {
      for (var i = 0; i < killsPerSector; i++) {
        names.add(Enemy.forSector(sector, index: i).name);
      }
      names.add(Enemy.forSector(sector, boss: true).name);
    }
    expect(names, hasLength(14));
    for (final n in names) {
      expect(enemyArt[n], isNotNull, reason: n);
    }
  });

  test('every drawing paints', () {
    final arts = [...ShipClass.values.map(playerArt), ...enemyArt.values];
    for (final art in arts) {
      expect(art.shapes, isNotEmpty);
      final canvas = Canvas(PictureRecorder());
      art.paint(canvas, const Offset(100, 50), 120, flash: 0.5, dim: 0.2);
    }
  });
}
