import 'dart:ui';

/// One filled shape of a ship drawing, in its [ShipArt]'s design coordinates.
class ArtShape {
  ArtShape(this.color, this.opacity, this.path);

  final Color color;
  final double opacity;
  final Path path;
}

/// A ship drawing from the design canvas (see `design/` and
/// `tool/gen_ship_art.py`): flat filled shapes in a [width] x [height] box.
/// Player ships face right, enemies face left.
class ShipArt {
  ShipArt(this.width, this.height, this.shapes);

  final double width;
  final double height;
  final List<ArtShape> shapes;

  static final _paint = Paint()..isAntiAlias = true;

  /// Draws the ship centred on [center], [drawWidth] wide. [flash] (0–1) washes it
  /// white (a hit); [dim] (0–1) darkens it (repairing, maintenance due).
  void paint(
    Canvas canvas,
    Offset center,
    double drawWidth, {
    double flash = 0,
    double dim = 0,
  }) {
    final k = drawWidth / width;
    canvas.save();
    canvas.translate(center.dx - drawWidth / 2, center.dy - height * k / 2);
    canvas.scale(k);
    for (final s in shapes) {
      var c = s.color;
      if (flash > 0) c = Color.lerp(c, const Color(0xFFFFFFFF), flash)!;
      if (dim > 0) c = Color.lerp(c, const Color(0xFF03060E), dim)!;
      _paint.color = c.withValues(alpha: c.a * s.opacity);
      canvas.drawPath(s.path, _paint);
    }
    canvas.restore();
  }
}
