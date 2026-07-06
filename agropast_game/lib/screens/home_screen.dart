import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_provider.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<GameProvider>().player;

    return Scaffold(
      backgroundColor: const Color(0xFF1b2a1b),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour, ${player.pseudo} 👋',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Niveau ${player.niveau} • ${player.scoreTotal} pts',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFf9a825).withOpacity(.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFf9a825).withOpacity(.4)),
                    ),
                    child: Row(
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text('${player.piecesOr}',
                            style: const TextStyle(
                                color: Color(0xFFf9a825),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Logo central
              const Text('🍉', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 12),
              const Text(
                'AgroPast-Game',
                style: TextStyle(
                  color: Color(0xFFf9a825),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Gère ta ferme. Vendange ta vigne.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),

              const SizedBox(height: 50),

              // Bouton Jouer
              _MenuButton(
                emoji: '🎮',
                label: 'Jouer',
                subtitle: '${player.nombreRecoltes} récoltes effectuées',
                color: const Color(0xFF2e7d32),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const GameScreen())),
              ),
              const SizedBox(height: 16),

              // Bouton Classement
              _MenuButton(
                emoji: '🏆',
                label: 'Classement',
                subtitle: 'Voir les meilleurs fermiers',
                color: const Color(0xFF1565c0),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen())),
              ),
              const SizedBox(height: 16),

              // Bouton Paramètres pseudo
              _MenuButton(
                emoji: '⚙️',
                label: 'Mon profil',
                subtitle: 'Modifier ton pseudo',
                color: const Color(0xFF4a148c),
                onTap: () => _showPseudoDialog(context),
              ),

              const SizedBox(height: 24),

              const Text(
                'v1.0.0 • Gratuit • Financé par la pub 🎯',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  void _showPseudoDialog(BuildContext context) {
    final ctrl = TextEditingController(
        text: context.read<GameProvider>().player.pseudo);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2d4a1e),
        title: const Text('Mon pseudo',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ex: AgriKing_Brazza',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF4caf50))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2e7d32)),
            onPressed: () {
              if (ctrl.text.trim().length >= 2) {
                context.read<GameProvider>().setPseudo(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String emoji, label, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
