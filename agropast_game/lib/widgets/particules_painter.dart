// ============================================================
// particules_painter.dart — Effet eau CustomPainter
// Déclenché à chaque tap arrosoir
// ============================================================

import 'dart:math';
import 'package:flutter/material.dart';

class Particule {
  Offset position;
  Offset velocity;
  double opacity;
  double radius;
  Color color;

  Particule({
    required this.position,
    required this.velocity,
    required this.opacity,
    required this.radius,
    required this.color,
  });
}

class ParticulesPainter extends CustomPainter {
  final List<List<Particule>> groups;

  const ParticulesPainter({required this.groups, required Listenable repaint})
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final group in groups) {
      for (final p in group) {
        if (p.opacity <= 0) continue;
        final paint = Paint()
          ..color = p.color.withOpacity(p.opacity.clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p.position, p.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(ParticulesPainter old) => true;
}

/// Controller de particules — à mixin dans un State avec TickerProvider
class ParticulesController {
  static const int _maxGroups = 5;
  static const _friction      = 0.85;
  static const _fadeFactor    = 0.07;
  static final _rng           = Random();

  final List<List<Particule>> groups = [];

  void spawn(Offset tapPos) {
    if (groups.length >= _maxGroups) groups.removeAt(0);

    final count = 8 + _rng.nextInt(8); // [8, 15]
    final group = <Particule>[];
    for (int i = 0; i < count; i++) {
      final angle  = _rng.nextDouble() * 2 * pi;
      final speed  = 2.0 + _rng.nextDouble() * 4.0;
      final t      = _rng.nextDouble();
      final color  = Color.lerp(
        const Color(0xFF29b6f6),
        const Color(0xFF80deea),
        t,
      )!;
      group.add(Particule(
        position: tapPos,
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        opacity:  1.0,
        radius:   3.0 + _rng.nextDouble() * 3.0,
        color:    color,
      ));
    }
    groups.add(group);
  }

  /// Appelé à chaque frame du ticker — retourne true si encore actif
  bool tick() {
    bool anyActive = false;
    for (final group in groups) {
      for (final p in group) {
        if (p.opacity <= 0) continue;
        p.position = p.position + p.velocity;
        p.velocity = p.velocity * _friction;
        p.opacity  = (p.opacity - _fadeFactor).clamp(0.0, 1.0);
        if (p.opacity > 0) anyActive = true;
      }
    }
    if (!anyActive) groups.clear();
    return anyActive;
  }
}
