import 'dart:math';

import 'package:flutter/material.dart';

import '../game/game_state.dart';
import 'ships.dart';
import 'theme.dart';

/// The fight, drawn from [GameState] each frame: parallax stars (streaking while
/// warping), the player's ship, the contact, laser fire and the shield bubble.
class BattleView extends StatelessWidget {
  const BattleView({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        painter: _BattlePainter(state),
        child: const SizedBox.expand(),
      ),
    );
  }
}

final _stars = () {
  final r = Random(7);
  return List.generate(
    90,
    (_) => (r.nextDouble(), r.nextDouble(), 0.2 + r.nextDouble() * 0.8),
  );
}();

class _BattlePainter extends CustomPainter {
  _BattlePainter(this.s);

  final GameState s;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF03060E),
    );
    final warping = s.phase == Phase.warping;
    _drawStars(canvas, size, warping);

    // Sized mostly by width: the phone layout gives the battle a tall view.
    final scale = min(size.width / 280, size.height / 220).clamp(0.6, 2.2);
    // Upper half, so the fight stays visible above the half-height upgrade sheet.
    final player = Offset(size.width * 0.22, size.height * 0.36);
    final foe = Offset(size.width * 0.74, size.height * 0.33);
    final e = s.enemy;
    final art = playerArt(s.shipClass);
    final playerW = 104 * scale;
    final foeArt = e == null ? null : enemyArt[e.name];
    final foeW = (e?.isBoss ?? false) ? 128 * scale : 84 * scale;

    // Lasers fade over 150ms after each shot.
    if (e != null) {
      final pAge = s.clock - s.lastPlayerShot;
      if (pAge < 0.15) {
        _laser(
          canvas,
          player + Offset(playerW * 0.4, 0),
          foe,
          SpaceColors.accent,
          1 - pAge / 0.15,
          scale,
        );
      }
      final eAge = s.clock - s.lastEnemyShot;
      if (eAge < 0.15) {
        _laser(
          canvas,
          foe - Offset(foeW * 0.38, 0),
          player,
          e.isBoss ? SpaceColors.boss : SpaceColors.enemy,
          1 - eAge / 0.15,
          scale,
        );
      }
    }

    final down = s.phase == Phase.repairing || s.phase == Phase.disabled;
    art.paint(canvas, player, playerW, dim: down ? 0.55 : 0);
    if (s.stats.maxShield > 0 && s.shield > 0 && !down) {
      final a = (s.shield / s.stats.maxShield).clamp(0.0, 1.0);
      canvas.drawCircle(
        player,
        playerW * 0.52,
        Paint()
          ..color = SpaceColors.shield.withValues(alpha: 0.12 + 0.35 * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * scale,
      );
    }

    if (e != null) {
      final hit = s.clock - s.lastPlayerShot < 0.08;
      foeArt?.paint(canvas, foe, foeW, flash: hit ? 0.6 : 0);
      _bar(
        canvas,
        Rect.fromCenter(
          center: foe - Offset(0, foeW * 0.32 + 10 * scale),
          width: foeW * 0.85,
          height: 6 * scale,
        ),
        e.hp / e.maxHp,
        e.isBoss ? SpaceColors.boss : SpaceColors.enemy,
      );
    }

    final label = switch (s.phase) {
      Phase.warping => 'WARPING',
      Phase.repairing => 'REPAIRING',
      Phase.disabled => 'MAINTENANCE DUE',
      Phase.fighting => e!.name.toUpperCase(),
    };
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: down ? SpaceColors.enemy : SpaceColors.muted,
          fontSize: 12 * scale.clamp(1.0, 1.5),
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, size.height - tp.height - 10),
    );
  }

  void _drawStars(Canvas canvas, Size size, bool warping) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    final speed = warping ? 0.9 : 0.04;
    for (final (x0, y, depth) in _stars) {
      final x = (x0 - s.clock * speed * depth * 0.25) % 1.0;
      final p = Offset(x * size.width, y * size.height);
      paint
        ..color = Colors.white.withValues(alpha: 0.25 + 0.6 * depth)
        ..strokeWidth = 1 + depth;
      if (warping) {
        canvas.drawLine(p, p + Offset(30 * depth, 0), paint);
      } else {
        canvas.drawCircle(p, 0.6 + depth, paint);
      }
    }
  }

  void _laser(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color,
    double alpha,
    double k,
  ) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = 2.5 * k
        ..strokeCap = StrokeCap.round,
    );
  }

  void _bar(Canvas canvas, Rect r, double frac, Color color) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(3));
    canvas.drawRRect(rr, Paint()..color = Colors.white12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left, r.top, r.width * frac.clamp(0.0, 1.0), r.height),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BattlePainter old) => true;
}
