// Modèle d'une parcelle de la ferme

enum ParcelleEtat { vide, semee, arrosee1, arrosee2, arrosee3, mure, recoltee }

class Parcelle {
  final int id;
  ParcelleEtat etat;
  int score; // score obtenu à la récolte

  Parcelle({required this.id, this.etat = ParcelleEtat.vide, this.score = 0});

  // Emoji affiché selon l'état
  String get emoji {
    switch (etat) {
      case ParcelleEtat.vide:     return '🟫';
      case ParcelleEtat.semee:    return '🌱';
      case ParcelleEtat.arrosee1: return '🌿';
      case ParcelleEtat.arrosee2: return '🌾';
      case ParcelleEtat.arrosee3: return '🌾';
      case ParcelleEtat.mure:     return '🍉';
      case ParcelleEtat.recoltee: return '✅';
    }
  }

  // Progression arrosage (0.0 → 1.0)
  double get waterProgress {
    switch (etat) {
      case ParcelleEtat.semee:    return 0.0;
      case ParcelleEtat.arrosee1: return 0.33;
      case ParcelleEtat.arrosee2: return 0.66;
      case ParcelleEtat.arrosee3: return 1.0;
      default:                    return 0.0;
    }
  }

  bool get estInteractable =>
      etat != ParcelleEtat.recoltee && etat != ParcelleEtat.mure;

  bool get estMure => etat == ParcelleEtat.mure;
  bool get estVide => etat == ParcelleEtat.vide;

  // Action sur clic
  void interagir() {
    switch (etat) {
      case ParcelleEtat.vide:
        etat = ParcelleEtat.semee;
        break;
      case ParcelleEtat.semee:
        etat = ParcelleEtat.arrosee1;
        break;
      case ParcelleEtat.arrosee1:
        etat = ParcelleEtat.arrosee2;
        break;
      case ParcelleEtat.arrosee2:
        etat = ParcelleEtat.arrosee3;
        break;
      case ParcelleEtat.arrosee3:
        etat = ParcelleEtat.mure;
        break;
      case ParcelleEtat.mure:
        score = _calculerScore();
        etat  = ParcelleEtat.recoltee;
        break;
      default:
        break;
    }
  }

  int _calculerScore() {
    // Score aléatoire pondéré entre 500 et 3000
    final base = 500 + (DateTime.now().millisecondsSinceEpoch % 2500);
    return base.toInt();
  }

  void reset() {
    etat  = ParcelleEtat.vide;
    score = 0;
  }

  // ── Sérialisation pour persistance ───────────────────────
  Map<String, dynamic> toMap() => {
    'id':    id,
    'etat':  etat.index,
    'score': score,
  };

  factory Parcelle.fromMap(Map<String, dynamic> map) {
    final p = Parcelle(id: map['id'] as int? ?? 0);
    final etatIndex = map['etat'] as int? ?? 0;
    p.etat  = ParcelleEtat.values[etatIndex.clamp(0, ParcelleEtat.values.length - 1)];
    p.score = map['score'] as int? ?? 0;
    return p;
  }
}
