import '../game/ships.dart';
import 'ship_art.dart';
import 'ship_art_types.dart';

ShipArt playerArt(ShipClass c) => switch (c) {
  ShipClass.wayfarer => wayfarerArt,
  ShipClass.meridian => meridianArt,
  ShipClass.kestrel => kestrelArt,
  ShipClass.halcyon => halcyonArt,
  ShipClass.bastion => bastionArt,
  ShipClass.aegis => aegisArt,
};

/// Keyed by the enemy names in `sectors.dart`; a name without art draws nothing
/// (a test checks every name has one).
final enemyArt = <String, ShipArt>{
  'Pirate Scout': pirateScoutArt,
  'Scrap Drone': scrapDroneArt,
  'Raider': raiderArt,
  'Void Wasp': voidWaspArt,
  'Corsair': corsairArt,
  'Sentinel': sentinelArt,
  'Hive Drone': hiveDroneArt,
  'Marauder': marauderArt,
  'Pirate Warlord': pirateWarlordArt,
  'Dreadnought': dreadnoughtArt,
  'Hive Queen': hiveQueenArt,
  'Rogue AI Core': rogueAiCoreArt,
  'Void Leviathan': voidLeviathanArt,
  'Star Eater': starEaterArt,
};
