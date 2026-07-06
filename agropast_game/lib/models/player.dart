// Modèle joueur — persisté avec shared_preferences

class Player {
  String pseudo;
  String email;
  int scoreTotal;
  int nombreRecoltes;
  int niveau;
  int piecesOr;

  Player({
    this.pseudo         = 'Fermier',
    this.email          = '',
    this.scoreTotal     = 0,
    this.nombreRecoltes = 0,
    this.niveau         = 1,
    this.piecesOr       = 100,
  });

  // Calcul du niveau selon score
  static int calculerNiveau(int score) {
    if (score < 5000)  return 1;
    if (score < 15000) return 2;
    if (score < 30000) return 3;
    if (score < 50000) return 4;
    return 5;
  }

  void ajouterScore(int points) {
    scoreTotal    += points;
    nombreRecoltes++;
    niveau = calculerNiveau(scoreTotal);
  }

  Map<String, dynamic> toMap() => {
    'pseudo':         pseudo,
    'scoreTotal':     scoreTotal,
    'nombreRecoltes': nombreRecoltes,
    'niveau':         niveau,
    'piecesOr':       piecesOr,
  };

  factory Player.fromMap(Map<String, dynamic> map) => Player(
    pseudo:         map['pseudo']         ?? 'Fermier',
    scoreTotal:     map['scoreTotal']     ?? 0,
    nombreRecoltes: map['nombreRecoltes'] ?? 0,
    niveau:         map['niveau']         ?? 1,
    piecesOr:       map['piecesOr']       ?? 100,
  );
}
