// ============================================================
// culture.dart — Modèle des 4 cultures du Parcours Quotidien
// ============================================================

import 'package:flutter/foundation.dart';

enum CultureType { tomate, mais, carotte, piment }

@immutable
class Culture {
  final CultureType type;
  final String label;
  final String emoji;       // fallback si SVG indisponible
  final String svgAsset;    // chemin asset SVG
  final int scoreRecolte;

  const Culture({
    required this.type,
    required this.label,
    required this.emoji,
    required this.svgAsset,
    required this.scoreRecolte,
  });
}

const List<Culture> kCultures = [
  Culture(
    type: CultureType.tomate,
    label: 'Tomate',
    emoji: '🍅',
    svgAsset: 'assets/images/tomato.svg',
    scoreRecolte: 200,
  ),
  Culture(
    type: CultureType.mais,
    label: 'Maïs',
    emoji: '🌽',
    svgAsset: 'assets/images/mais.svg',
    scoreRecolte: 350,
  ),
  Culture(
    type: CultureType.carotte,
    label: 'Carotte',
    emoji: '🥕',
    svgAsset: 'assets/images/carotte.svg',
    scoreRecolte: 550,
  ),
  Culture(
    type: CultureType.piment,
    label: 'Piment',
    emoji: '🌶️',
    svgAsset: 'assets/images/piment.svg',
    scoreRecolte: 800,
  ),
];
