import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_provider.dart';

// Données factices — à remplacer par l'API réelle
final _mockLeaders = [
  {'rank': 1, 'pseudo': 'AgriKing_Brazza',  'pays': '🇨🇬', 'score': 148250},
  {'rank': 2, 'pseudo': 'PasteQueen_CI',    'pays': '🇨🇮', 'score': 137800},
  {'rank': 3, 'pseudo': 'VinoMaster_BJ',    'pays': '🇧🇯', 'score': 129450},
  {'rank': 4, 'pseudo': 'FermierFou237',    'pays': '🇨🇲', 'score': 118900},
  {'rank': 5, 'pseudo': 'SowGrow_CI',       'pays': '🇨🇮', 'score': 110300},
  {'rank': 6, 'pseudo': 'RedSeedBF',        'pays': '🇧🇫', 'score': 104750},
  {'rank': 7, 'pseudo': 'JardinierSahel',   'pays': '🇲🇱', 'score':  97200},
  {'rank': 8, 'pseudo': 'TerroirGN',        'pays': '🇬🇳', 'score':  89650},
  {'rank': 9, 'pseudo': 'HarvestKing_TG',   'pays': '🇹🇬', 'score':  82100},
  {'rank':10, 'pseudo': 'WineWizard_NG',    'pays': '🇳🇬', 'score':  76500},
];

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myScore = context.watch<GameProvider>().player.scoreTotal;
    final myPseudo = context.watch<GameProvider>().player.pseudo;

    return Scaffold(
      backgroundColor: const Color(0xFF1b2a1b),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d1f0d),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Text('🏆 ', style: TextStyle(fontSize: 20)),
            Text('Classement', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mon score
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2e7d32), Color(0xFF1b5e20)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('👤', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(myPseudo,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const Text('Mon score',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text('$myScore pts',
                      style: const TextStyle(
                          color: Color(0xFFf9a825),
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),

            // Liste classement
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _mockLeaders.length,
                itemBuilder: (ctx, i) {
                  final l = _mockLeaders[i];
                  return _LeaderRow(
                    rank:   l['rank'] as int,
                    pseudo: l['pseudo'] as String,
                    pays:   l['pays']   as String,
                    score:  l['score']  as int,
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '* Classement illustratif — les vrais scores arrivent au lancement',
                style: TextStyle(
                    color: Colors.white.withOpacity(.3), fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final int rank, score;
  final String pseudo, pays;
  const _LeaderRow(
      {required this.rank,
      required this.pseudo,
      required this.pays,
      required this.score});

  String get _medal {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: rank <= 3
            ? const Color(0xFF2d4a1e)
            : const Color(0xFF1e3a1e),
        borderRadius: BorderRadius.circular(10),
        border: rank <= 3
            ? Border.all(
                color: const Color(0xFFf9a825).withOpacity(.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(_medal,
                style: TextStyle(
                    fontSize: rank <= 3 ? 22 : 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          Text(pays, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(pseudo,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          Text('${score.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} pts',
              style: const TextStyle(
                  color: Color(0xFF4caf50),
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
