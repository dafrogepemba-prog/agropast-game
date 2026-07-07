import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_provider.dart';
import '../services/api_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _leaders = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await ApiService.getLeaderboard();
      setState(() {
        _leaders = data;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error   = 'Impossible de charger le classement.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1b2a1b),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d1f0d),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Color(0xFFf9a825), size: 22),
            SizedBox(width: 8),
            Text('Classement', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _load,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Mon score ──────────────────────────────────
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
                  const Icon(Icons.person, color: Colors.white, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(gp.player.pseudo,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        Text('Niveau ${gp.player.niveau} • ${gp.player.nombreRecoltes} récoltes',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${_formatScore(gp.player.scoreTotal)} pts',
                          style: const TextStyle(
                              color: Color(0xFFf9a825),
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      Text('${gp.player.piecesOr} 🪙',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Contenu ────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF4caf50)))
                  : _error.isNotEmpty
                      ? _ErrorView(error: _error, onRetry: _load)
                      : _leaders.isEmpty
                          ? _EmptyView()
                          : RefreshIndicator(
                              color: const Color(0xFF4caf50),
                              backgroundColor: const Color(0xFF1b2a1b),
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                itemCount: _leaders.length,
                                itemBuilder: (ctx, i) {
                                  final l = _leaders[i];
                                  final isMe = l['pseudo'] == gp.player.pseudo;
                                  return _LeaderRow(
                                    rank:   l['rank']   as int,
                                    pseudo: l['pseudo'] as String,
                                    pays:   l['pays']   as String? ?? '',
                                    score:  l['score']  as int,
                                    isMe:   isMe,
                                  );
                                },
                              ),
                            ),
            ),

            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Classement mis à jour en temps réel',
                style: TextStyle(
                    color: Colors.white.withOpacity(.3), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatScore(int s) =>
      s.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ── Ligne du classement ───────────────────────────────────
class _LeaderRow extends StatelessWidget {
  final int rank, score;
  final String pseudo, pays;
  final bool isMe;

  const _LeaderRow({
    required this.rank,
    required this.pseudo,
    required this.pays,
    required this.score,
    required this.isMe,
  });

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
        color: isMe
            ? const Color(0xFF1a3a2a)
            : rank <= 3
                ? const Color(0xFF2d4a1e)
                : const Color(0xFF1e3a1e),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe
              ? const Color(0xFF4caf50)
              : rank <= 3
                  ? const Color(0xFFf9a825).withOpacity(.3)
                  : Colors.transparent,
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(_medal,
                style: TextStyle(
                    fontSize: rank <= 3 ? 22 : 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          if (pays.isNotEmpty) ...[
            Text(_flagEmoji(pays),
                style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              pseudo + (isMe ? ' (moi)' : ''),
              style: TextStyle(
                  color: isMe ? const Color(0xFF4caf50) : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${score.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} pts',
            style: const TextStyle(
                color: Color(0xFF4caf50),
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _flagEmoji(String pays) {
    const flags = {
      'Congo-Brazzaville': '🇨🇬', 'RDC': '🇨🇩',
      'Sénégal': '🇸🇳', "Côte d'Ivoire": '🇨🇮',
      'Cameroun': '🇨🇲', 'Gabon': '🇬🇦',
      'Bénin': '🇧🇯', 'Burkina Faso': '🇧🇫',
      'Mali': '🇲🇱', 'Autre': '🌍',
    };
    return flags[pays] ?? '🌍';
  }
}

// ── Widgets d'état ────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off, color: Colors.white38, size: 48),
        const SizedBox(height: 12),
        Text(error,
            style: const TextStyle(color: Colors.white54),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2e7d32)),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      ],
    ),
  );
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 64),
        SizedBox(height: 12),
        Text('Aucun score encore enregistré.',
            style: TextStyle(color: Colors.white38)),
        SizedBox(height: 6),
        Text('Joue et récolte pour apparaître ici !',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      ],
    ),
  );
}
