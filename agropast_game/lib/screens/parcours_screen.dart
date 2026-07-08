// ============================================================
// parcours_screen.dart — Parcours Quotidien
// Design fidèle au mockup : grille 2×2 + clicker arrosoir
// ============================================================
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/culture.dart';
import '../models/player.dart';
import '../services/parcours_provider.dart';
import '../widgets/particules_painter.dart';

enum EtatCulture { locked, available, inProgress, done }

class ParcoursQuotidienScreen extends StatefulWidget {
  const ParcoursQuotidienScreen({super.key});
  @override
  State<ParcoursQuotidienScreen> createState() => _ParcoursState();
}

class _ParcoursState extends State<ParcoursQuotidienScreen>
    with TickerProviderStateMixin {
  // Compte à rebours minuit
  late Timer _countdownTimer;
  String _countdown = '--:--:--';

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        context.read<ParcoursQuotidienProvider>().init());
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now     = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day + 1);
      final diff    = midnight.difference(now);
      final h = diff.inHours.toString().padLeft(2, '0');
      final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
      if (mounted) setState(() => _countdown = '$h:$m:$s');
    });
  }

  void _ouvrirCulture(BuildContext context, int index,
      ParcoursQuotidienProvider pq) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: pq,
          child: _CultureScreen(cultureIndex: index),
        ),
      ),
    ).then((_) {
      // Vérifier montée de niveau au retour
      final ev = pq.levelUpEvent;
      if (ev != null && mounted) {
        _showLevelUpDialog(ev);
        pq.clearLevelUpEvent();
      }
    });
  }

  void _showLevelUpDialog(NiveauInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1b2a1b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(info.emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 10),
          const Text('Niveau supérieur !',
              style: TextStyle(color: Color(0xFFf9a825),
                  fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(info.nom,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          if (info.bonusPiecesOr > 0) ...[
            const SizedBox(height: 10),
            Text('+${info.bonusPiecesOr} 💰',
                style: const TextStyle(
                    color: Color(0xFFf9a825), fontWeight: FontWeight.bold)),
          ],
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2e7d32),
                minimumSize: const Size.fromHeight(42)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Super !'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParcoursQuotidienProvider>(
      builder: (ctx, pq, _) {
        if (!pq.initialized) {
          return const Scaffold(
            backgroundColor: Color(0xFF0d1b0f),
            body: Center(child: CircularProgressIndicator(
                color: Color(0xFF4caf50))),
          );
        }

        final done    = pq.culturesDoneCount;
        final total   = 4;
        final restant = total - done;

        return Scaffold(
          backgroundColor: const Color(0xFF0d1b0f),
          body: SafeArea(
            child: Column(
              children: [
                // ── AppBar custom ──────────────────────────
                _AppBarParcours(
                  score:    pq.totalScore,
                  niveau:   pq.niveau,
                  recoltes: pq.recoltes,
                  done:     done,
                  pieces:   pq.pieces,
                ),

                // ── Bannière restant / web ─────────────────
                if (kIsWeb)
                  _banner('💡 Progression liée au cache navigateur.',
                      const Color(0xFF1c3320)),
                if (!pq.sessionDone)
                  _banner(
                    restant > 0
                        ? '🌾 $restant culture${restant > 1 ? 's' : ''} restante${restant > 1 ? 's' : ''} aujourd\'hui'
                        : '🎉 Toutes les cultures du jour terminées !',
                    const Color(0xFF1c3320),
                  ),

                // ── Grille 2×2 ─────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.0,
                      children: List.generate(4, (i) {
                        final etat = _etatCulture(i, pq);
                        return _CultureCard(
                          culture:     kCultures[i],
                          etat:        etat,
                          progression: i == pq.cultureIndex
                              ? pq.progression : 0.0,
                          onTap: (etat == EtatCulture.available ||
                                  etat == EtatCulture.inProgress)
                              ? () => _ouvrirCulture(ctx, i, pq)
                              : null,
                        );
                      }),
                    ),
                  ),
                ),

                // ── Compte à rebours (quand 4 done) ────────
                if (pq.sessionDone)
                  _CountdownBanner(countdown: _countdown)
                else
                  const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  EtatCulture _etatCulture(int i, ParcoursQuotidienProvider pq) {
    if (pq.sessionDone || i < pq.cultureIndex) return EtatCulture.done;
    if (i == pq.cultureIndex) {
      return pq.progression > 0
          ? EtatCulture.inProgress
          : EtatCulture.available;
    }
    return EtatCulture.locked;
  }

  Widget _banner(String msg, Color bg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    color: bg,
    child: Text(msg,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
        textAlign: TextAlign.center),
  );
}

// ── AppBar Parcours ────────────────────────────────────────
class _AppBarParcours extends StatelessWidget {
  final int score, niveau, recoltes, done, pieces;
  const _AppBarParcours({
    required this.score, required this.niveau,
    required this.recoltes, required this.done, required this.pieces,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0a150a),
        border: Border(bottom: BorderSide(color: Color(0xFF1c3320), width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios,
                    color: Colors.white70, size: 18),
              ),
              const SizedBox(width: 8),
              const Text('🌿 Ma Ferme',
                  style: TextStyle(
                      color: Color(0xFF4caf50),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2e7d32),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_fmt(score)} pts',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip('Niv. $niveau', 'Niveau'),
              _StatChip('$recoltes', 'Récoltes'),
              _StatChip('$done/4', "Aujourd'hui"),
              _StatChip('$pieces 💰', ''),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

class _StatChip extends StatelessWidget {
  final String value, label;
  const _StatChip(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold,
              fontSize: 14)),
      if (label.isNotEmpty)
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
    ],
  );
}

// ── Carte culture ──────────────────────────────────────────
class _CultureCard extends StatelessWidget {
  final Culture culture;
  final EtatCulture etat;
  final double progression;
  final VoidCallback? onTap;

  const _CultureCard({
    required this.culture, required this.etat,
    required this.progression, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = etat == EtatCulture.locked;
    final isDone   = etat == EtatCulture.done;
    final isActive = etat == EtatCulture.inProgress ||
                     etat == EtatCulture.available;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isLocked ? 0.4 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1c3320),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDone
                  ? const Color(0xFF2e7d32)
                  : isActive
                      ? const Color(0xFF4caf50)
                      : Colors.white12,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // Contenu
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icône
                    isLocked
                        ? const Text('🔒',
                            style: TextStyle(fontSize: 28))
                        : Text(culture.emoji,
                            style: const TextStyle(fontSize: 36)),
                    const SizedBox(height: 6),
                    Text(culture.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      isDone
                          ? 'Terminée'
                          : isLocked
                              ? 'Verrouillée'
                              : etat == EtatCulture.available
                                  ? 'Disponible'
                                  : '${progression.toInt()}%',
                      style: TextStyle(
                          color: isDone
                              ? const Color(0xFF4caf50)
                              : isLocked
                                  ? Colors.white24
                                  : Colors.white60,
                          fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    // Barre de progression
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: isDone
                            ? 1.0
                            : (progression / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.white12,
                        color: isDone
                            ? const Color(0xFF2e7d32)
                            : const Color(0xFF4caf50),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge ✓
              if (isDone)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2e7d32),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('✓',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compte à rebours ───────────────────────────────────────
class _CountdownBanner extends StatelessWidget {
  final String countdown;
  const _CountdownBanner({required this.countdown});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 14),
    color: const Color(0xFF1c3320),
    child: Column(
      children: [
        const Text('Prochaines cultures dans',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(countdown,
            style: const TextStyle(
                color: Color(0xFF4caf50),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace')),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════
// ÉCRAN 2 — Simulation clicker arrosoir
// ══════════════════════════════════════════════════════════
class _CultureScreen extends StatefulWidget {
  final int cultureIndex;
  const _CultureScreen({required this.cultureIndex});
  @override
  State<_CultureScreen> createState() => _CultureScreenState();
}

class _CultureScreenState extends State<_CultureScreen>
    with TickerProviderStateMixin {

  // Timer écoulé
  late Timer _timer;
  int _secondes = 0;

  // Particules
  final ParticulesController _particules = ParticulesController();
  late AnimationController   _partCtrl;

  // Rotation arrosoir
  late AnimationController _rotCtrl;
  late Animation<double>    _rotAnim;

  // +5% flottant
  late AnimationController _plusCtrl;
  late Animation<double>    _plusFade;
  late Animation<Offset>    _plusSlide;
  Offset _tapLocalPos = Offset.zero;

  // Étoiles décoratives
  late AnimationController _starsCtrl;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondes++);
    });

    _partCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..addListener(() {
        if (!_particules.tick()) _partCtrl.stop();
        setState(() {});
      });

    _rotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _rotAnim = Tween<double>(begin: 0, end: 0.15)
        .animate(CurvedAnimation(parent: _rotCtrl, curve: Curves.easeInOut));

    _plusCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _plusFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _plusCtrl, curve: Curves.easeOut));
    _plusSlide = Tween<Offset>(
            begin: Offset.zero, end: const Offset(0, -1.5))
        .animate(CurvedAnimation(parent: _plusCtrl, curve: Curves.easeOut));

    _starsCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _timer.cancel();
    _partCtrl.dispose();
    _rotCtrl.dispose();
    _plusCtrl.dispose();
    _starsCtrl.dispose();
    super.dispose();
  }

  String get _timerStr {
    final m = (_secondes ~/ 60).toString().padLeft(2, '0');
    final s = (_secondes % 60).toString().padLeft(2, '0');
    return '⏱ 00:$m:$s';
  }

  void _onTap(Offset globalPos) {
    final pq = context.read<ParcoursQuotidienProvider>();
    if (pq.sessionDone) return;

    if (!kIsWeb) HapticFeedback.lightImpact();

    // Position locale pour particules et +5%
    final box  = context.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(globalPos) ?? globalPos;
    setState(() => _tapLocalPos = local);

    // Particules
    _particules.spawn(local);
    if (!_partCtrl.isAnimating) _partCtrl.repeat();

    // Rotation
    _rotCtrl.forward(from: 0);

    // +5% slide
    _plusCtrl.forward(from: 0);

    // Logique
    pq.onTapArrosoir();

    // Si 100% → retour auto après animation
    if (pq.progression >= 100) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParcoursQuotidienProvider>(
      builder: (ctx, pq, _) {
        final culture = kCultures[widget.cultureIndex];
        final prog    = widget.cultureIndex == pq.cultureIndex
            ? pq.progression : 100.0;

        // Couleur fond selon maturité
        final bgColor = Color.lerp(
          const Color(0xFF0d1b0f),
          const Color(0xFF0d2a10),
          prog / 100,
        )!;

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Stack(
              children: [
                // Particules
                Positioned.fill(
                  child: CustomPaint(
                    painter: ParticulesPainter(
                      groups: _particules.groups,
                      repaint: _partCtrl,
                    ),
                  ),
                ),

                Column(
                  children: [
                    // ── Header ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.arrow_back_ios,
                                color: Colors.white70, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text('${culture.emoji} ${culture.label}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const Spacer(),
                          Text(_timerStr,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ── Zone centrale étoiles + emoji ────────
                    _PlantZone(
                        emoji: culture.emoji,
                        progression: prog,
                        starsAnim: _starsCtrl),

                    const SizedBox(height: 24),

                    // ── Barre de maturité ────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Maturité',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                              Text('${prog.toInt()}%',
                                  style: const TextStyle(
                                      color: Color(0xFF4caf50),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (prog / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.white12,
                              color: Color.lerp(
                                const Color(0xFF4caf50),
                                const Color(0xFFb9f6ca),
                                prog / 100,
                              ),
                              minHeight: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ── Bouton arrosoir 🚿 ───────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTapDown: (d) => _onTap(d.globalPosition),
                            child: RotationTransition(
                              turns: _rotAnim,
                              child: Container(
                                width: 88, height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF1c3320),
                                  border: Border.all(
                                      color: const Color(0xFF4caf50),
                                      width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4caf50)
                                          .withOpacity(.35),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text('🚿',
                                      style: TextStyle(fontSize: 38)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Appuie pour arroser',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── +5% flottant ─────────────────────────────
                if (_plusCtrl.isAnimating)
                  Positioned(
                    left: _tapLocalPos.dx - 18,
                    top:  _tapLocalPos.dy - 50,
                    child: SlideTransition(
                      position: _plusSlide,
                      child: FadeTransition(
                        opacity: _plusFade,
                        child: const Text('+5%',
                            style: TextStyle(
                                color: Color(0xFF4caf50),
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Zone plante avec étoiles ───────────────────────────────
class _PlantZone extends StatelessWidget {
  final String emoji;
  final double progression;
  final AnimationController starsAnim;

  const _PlantZone({
    required this.emoji,
    required this.progression,
    required this.starsAnim,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180, height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dégradé radial de fond
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.lerp(const Color(0xFF1c3320),
                      const Color(0xFF2e7d32), progression / 100)!,
                  const Color(0xFF0d1b0f),
                ],
                radius: 0.8,
              ),
            ),
          ),
          // Étoiles animées
          AnimatedBuilder(
            animation: starsAnim,
            builder: (_, __) {
              return CustomPaint(
                size: const Size(180, 180),
                painter: _StarsPainter(starsAnim.value),
              );
            },
          ),
          // Emoji plante
          Text(emoji, style: const TextStyle(fontSize: 72)),
        ],
      ),
    );
  }
}

// ── Étoiles CustomPainter ──────────────────────────────────
class _StarsPainter extends CustomPainter {
  final double t;
  _StarsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = const Color(0xFF4caf50).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // 4 étoiles qui orbitent
    for (int i = 0; i < 4; i++) {
      final angle = (t * 2 * 3.14159) + (i * 3.14159 / 2);
      final r     = 72.0;
      final x     = cx + r * _cos(angle);
      final y     = cy + r * _sin(angle);
      final size2 = 4.0 + 2.0 * _sin(t * 3.14159 * 2 + i);
      canvas.drawCircle(Offset(x, y), size2, paint);
    }
  }

  double _cos(double a) {
    // approximation simple cos
    return _sin(a + 3.14159 / 2);
  }

  double _sin(double a) {
    a = a % (2 * 3.14159);
    if (a < 0) a += 2 * 3.14159;
    // Taylor approximation
    final x = a - 3.14159;
    return -x * (1 - x * x / 6) * (1 - x * x / 20);
  }

  @override
  bool shouldRepaint(_StarsPainter old) => true;
}
