import 'package:flutter/material.dart';
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

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: p.etat == ParcelleEtat.recoltee ? null : _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: _bgColor(p.etat),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMure
                  ? const Color(0xFFf9a825)
                  : const Color(0xFF3a5c24),
              width: isMure ? 2.5 : 1.5,
            ),
            boxShadow: isMure
                ? [
                    BoxShadow(
                      color: const Color(0xFFf9a825).withOpacity(.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(p.emoji,
                  style: const TextStyle(fontSize: 36)),
              if (p.waterProgress > 0 &&
                  p.etat != ParcelleEtat.mure &&
                  p.etat != ParcelleEtat.recoltee) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: p.waterProgress,
                      backgroundColor: Colors.white12,
                      color: const Color(0xFF64b5f6),
                      minHeight: 5,
                    ),
                  ),
                ),
              ],
              if (p.etat == ParcelleEtat.recoltee &&
                  p.score > 0) ...[
                const SizedBox(height: 4),
                Text('+${p.score}',
                    style: const TextStyle(
                        color: Color(0xFF4caf50),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _bgColor(ParcelleEtat e) {
    switch (e) {
      case ParcelleEtat.vide:
        return const Color(0xFF2d4a1e);
      case ParcelleEtat.recoltee:
        return const Color(0xFF1b5e20).withOpacity(.5);
      default:
        return const Color(0xFF2d4a1e);
    }
  }
}
