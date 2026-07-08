// ============================================================
// culture.dart — Modèle des 4 cultures du Parcours Quotidien
// ============================================================

import 'package:flutter/foundation.dart';

enum CultureType { tomate, mais, carotte, piment }

@immutable
class Culture {
  final CultureType type;
  final String label;
  final String emoji;
  final int scoreRecolte; // points crédités à 100 % de maturité

  const Culture({
    required this.type,
    required this.label,
    required this.emoji,
    required this.scoreRecolte,
  });
}

const List<Culture> kCultures = [
  Culture(type: CultureType.tomate,  label: 'Tomate',  emoji: '🍅', scoreRecolte: 200),
  Culture(type: CultureType.mais,    label: 'Maïs',    emoji: '🌽', scoreRecolte: 350),
  Culture(type: CultureType.carotte, label: 'Carotte', emoji: '🥕', scoreRecolte: 550),
  Culture(type: CultureType.piment,  label: 'Piment',  emoji: '🌶️', scoreRecolte: 800),
];
