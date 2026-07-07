// ============================================================
// Modèle joueur — persisté avec shared_preferences
// ============================================================

class NiveauInfo {
  final int    niveau;
  final String nom;
  final String emoji;
  final int    scoreMin;
  final int    scoreMax;
  final int    bonusPiecesOr; // bonus accordé à la montée de niveau
  final String culture;       // culture débloquée à ce niveau

  const NiveauInfo({
    required this.niveau,
    required this.nom,
    required this.emoji,
    required this.scoreMin,
    required this.scoreMax,
    required this.bonusPiecesOr,
    required this.culture,
  });

  double get progressionRatio => scoreMax > scoreMin ? 1.0 : 0.0;
}

// Table des niveaux
const List<NiveauInfo> kNiveaux = [
  NiveauInfo(niveau:1, nom:'Apprenti Fermier', emoji:'🌱', scoreMin:0,     scoreMax:5000,  bonusPiecesOr:0,   culture:'Pastèque'),
  NiveauInfo(niveau:2, nom:'Fermier Actif',    emoji:'🌿', scoreMin:5000,  scoreMax:15000, bonusPiecesOr:50,  culture:'Vigne'),
  NiveauInfo(niveau:3, nom:'Agriculteur',      emoji:'🌾', scoreMin:15000, scoreMax:30000, bonusPiecesOr:100, culture:'Maïs'),
  NiveauInfo(niveau:4, nom:'Expert Récolte',   emoji:'🍉', scoreMin:30000, scoreMax:50000, bonusPiecesOr:200, culture:'Cacao'),
  NiveauInfo(niveau:5, nom:'Maître Fermier',   emoji:'🏆', scoreMin:50000, scoreMax:99999, bonusPiecesOr:500, culture:'Café'),
];

// Taux de conversion FCFA
const double kFcfaParMille = 60.0; // 60 FCFA par 1 000 pts

class Player {
  String pseudo;
  String email;
  int scoreTotal;
  int nombreRecoltes;
  int niveau;
  int piecesOr;
  List<int> niveauxAtteints; // historique des niveaux déjà récompensés

  Player({
    this.pseudo           = 'Fermier',
    this.email            = '',
    this.scoreTotal       = 0,
    this.nombreRecoltes   = 0,
    this.niveau           = 1,
    this.piecesOr         = 100,
    List<int>? niveauxAtteints,
  }) : niveauxAtteints = niveauxAtteints ?? [1];

  // ── Infos niveau actuel ──────────────────────────────────
  NiveauInfo get niveauInfo =>
      kNiveaux.firstWhere((n) => n.niveau == niveau,
          orElse: () => kNiveaux.last);

  // ── Progression vers le niveau suivant ──────────────────
  double get progressionNiveau {
    final info = niveauInfo;
    if (niveau >= kNiveaux.length) return 1.0;
    final range = info.scoreMax - info.scoreMin;
    if (range <= 0) return 1.0;
    return ((scoreTotal - info.scoreMin) / range).clamp(0.0, 1.0);
  }

  int get ptsVersProchainNiveau {
    if (niveau >= kNiveaux.length) return 0;
    return (niveauInfo.scoreMax - scoreTotal).clamp(0, 999999);
  }

  // ── Revenus FCFA estimés ─────────────────────────────────
  double get revenusFcfa => (scoreTotal / 1000) * kFcfaParMille;
  String get revenusFcfaStr {
    final r = revenusFcfa;
    if (r < 1) return '${(r * 100).toStringAsFixed(0)} F';
    if (r < 1000) return '${r.toStringAsFixed(0)} F';
    return '${(r / 1000).toStringAsFixed(1)} kF';
  }

  // ── Calcul niveau depuis score ───────────────────────────
  static int calculerNiveau(int score) {
    for (final n in kNiveaux.reversed) {
      if (score >= n.scoreMin) return n.niveau;
    }
    return 1;
  }

  // ── Ajouter score + vérifier montée de niveau ────────────
  // Retourne le NiveauInfo si montée de niveau, null sinon
  NiveauInfo? ajouterScore(int points) {
    scoreTotal    += points;
    nombreRecoltes++;
    final nouveauNiveau = calculerNiveau(scoreTotal);
    NiveauInfo? montee;
    if (nouveauNiveau > niveau && !niveauxAtteints.contains(nouveauNiveau)) {
      niveau = nouveauNiveau;
      niveauxAtteints.add(nouveauNiveau);
      final info = niveauInfo;
      piecesOr += info.bonusPiecesOr; // bonus pièces d'or à la montée
      montee = info;
    } else {
      niveau = nouveauNiveau;
    }
    return montee;
  }

  Map<String, dynamic> toMap() => {
    'pseudo':          pseudo,
    'scoreTotal':      scoreTotal,
    'nombreRecoltes':  nombreRecoltes,
    'niveau':          niveau,
    'piecesOr':        piecesOr,
    'niveauxAtteints': niveauxAtteints,
  };

  factory Player.fromMap(Map<String, dynamic> map) => Player(
    pseudo:          map['pseudo']         ?? 'Fermier',
    scoreTotal:      map['scoreTotal']     ?? 0,
    nombreRecoltes:  map['nombreRecoltes'] ?? 0,
    niveau:          map['niveau']         ?? 1,
    piecesOr:        map['piecesOr']       ?? 100,
    niveauxAtteints: (map['niveauxAtteints'] as List<dynamic>?)
                         ?.map((e) => e as int).toList() ?? [1],
  );
}
