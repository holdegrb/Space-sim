import 'dart:math';

/// The player's hull. Purely cosmetic for now: each galaxy jump moves the ship up
/// one class, and from the fifth jump on it flies the Aegis.
enum ShipClass {
  wayfarer('Wayfarer', 'Scout'),
  meridian('Meridian', 'Explorer'),
  kestrel('Kestrel', 'Frigate'),
  halcyon('Halcyon', 'Science vessel'),
  bastion('Bastion', 'Heavy cruiser'),
  aegis('Aegis', 'Dreadnought');

  const ShipClass(this.label, this.role);

  final String label;
  final String role;

  static ShipClass forJumps(int prestiges) =>
      values[min(max(0, prestiges), values.length - 1)];

  /// The class the next jump brings, or null at the top.
  ShipClass? get next => index + 1 < values.length ? values[index + 1] : null;

  String get fullName => '$label-class ${role.toLowerCase()}';
}
