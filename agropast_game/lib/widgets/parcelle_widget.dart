import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/parcelle.dart';

class ParcelleWidget extends StatefulWidget {
  final Parcelle parcelle;
  final VoidCallback onTap;

  const ParcelleWidget(
      {super.key, required this.parcelle, required this.onTap});

  @override
  State<ParcelleWidget> createState() => _ParcelleWidgetState();
}

class _ParcelleWidgetState extends State<ParcelleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>    _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 150),
        lowerBound: 0.85,
        upperBound: 1.0)
      ..value = 1.0;
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    _ctrl.reverse().then((_) => _ctrl.forward());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parcelle;
    final isMure = p.etat == ParcelleEtat.mure;
    final isVide = p.etat == ParcelleEtat.vide;
    final isRecoltee = p.etat == ParcelleEtat.recoltee;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: isRecoltee ? null : _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: isVide || isRecoltee
                ? null
                : LinearGradient(
                    colors: [
                      const Color(0xFF1b5e20),
                      const Color(0xFF2e7d32),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: isVide
                ? const Color(0xFF1a2f1a)
                : (isRecoltee
                    ? const Color(0xFF0d1f0d).withOpacity(0.7)
                    : null),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMure
                  ? const Color(0xFFf9a825)
                  : (isVide
                      ? Colors.white24
                      : const Color(0xFF66bb6a)),
              width: isMure ? 3 : 2,
            ),
            boxShadow: isMure
                ? [
                    BoxShadow(
                      color: const Color(0xFFf9a825).withOpacity(.5),
                      blurRadius: 16,
                      spreadRadius: 3,
                    )
                  ]
                : (isVide
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF4caf50).withOpacity(.25),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isVide)
                Center(
                  child: CustomPaint(
                    size: const Size(double.infinity, double.infinity),
                    painter: _HatchPainter(),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ParcelleIcon(etat: p.etat),
                  if (p.waterProgress > 0 && !isMure && !isRecoltee) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: p.waterProgress,
                          backgroundColor: Colors.white12,
                          color: const Color(0xFF64b5f6),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                  if (isRecoltee && p.score > 0) ...[
                    const SizedBox(height: 6),
                    Text('+${p.score}',
                        style: const TextStyle(
                            color: Color(0xFF4caf50),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Icône de parcelle avec SVG (compatible Flutter Web CanvasKit) ──
class _ParcelleIcon extends StatelessWidget {
  final ParcelleEtat etat;
  const _ParcelleIcon({required this.etat});

  @override
  Widget build(BuildContext context) {
    switch (etat) {
      case ParcelleEtat.vide:
        return const Icon(
          Icons.add_circle_outline,
          color: Colors.white54,
          size: 48,
        );
      case ParcelleEtat.semee:
        return SvgPicture.asset(
          'assets/images/seedling.svg',
          height: 40,
          width: 40,
          colorFilter: const ColorFilter.mode(
            Color(0xFF81c784),
            BlendMode.srcIn,
          ),
        );
      case ParcelleEtat.arrosee1:
        return SvgPicture.asset(
          'assets/images/seedling.svg',
          height: 42,
          width: 42,
          colorFilter: const ColorFilter.mode(
            Color(0xFF66bb6a),
            BlendMode.srcIn,
          ),
        );
      case ParcelleEtat.arrosee2:
        return SvgPicture.asset(
          'assets/images/carotte.svg',
          height: 44,
          width: 44,
        );
      case ParcelleEtat.arrosee3:
        return SvgPicture.asset(
          'assets/images/tomato.svg',
          height: 46,
          width: 46,
        );
      case ParcelleEtat.mure:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFf9a825).withOpacity(0.2),
          ),
          child: SvgPicture.asset(
            'assets/images/tomato.svg',
            height: 40,
            width: 40,
          ),
        );
      case ParcelleEtat.recoltee:
        return SvgPicture.asset(
          'assets/images/check_badge.svg',
          height: 44,
          width: 44,
        );
    }
  }
}

// ── Hatch pattern painter for empty parcelle ──
class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1.5;

    const spacing = 12.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
