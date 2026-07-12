// ============================================================
// parcours_sync_test.dart
// Vérifie que ParcoursQuotidienProvider appelle bien syncScorePublic
// à la fin d'une session complète, sans écraser le score existant.
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agropast_game/models/player.dart';
import 'package:agropast_game/services/game_provider.dart';
import 'package:agropast_game/services/parcours_provider.dart';
import 'package:agropast_game/services/audio_service.dart';

// ── Fake AudioService — no-op total, pas de platform channels ──
class FakeAudioService implements AudioServiceBase {
  @override bool get bgmStarted => false;
  @override Future<void> preload()          async {}
  @override Future<void> startBgm()         async {}
  @override Future<void> playSfxArrosage()  async {}
  @override Future<void> playJingleRecolte()async {}
  @override Future<void> pauseBgm()         async {}
  @override Future<void> resumeBgm()        async {}
  @override Future<void> dispose()          async {}
}

// ── Fake GameProvider — capture les appels réseau ────────────
class FakeGameProvider extends GameProvider {
  int syncCallCount = 0;
  String? lastSyncEventType;

  FakeGameProvider({int initialScore = 0}) {
    player = Player(scoreTotal: initialScore, nombreRecoltes: 0);
  }

  @override
  Future<void> savePublic() async {}

  @override
  Future<void> syncScorePublic({required String eventType}) async {
    syncCallCount++;
    lastSyncEventType = eventType;
  }
}

void main() {
  // Score des 4 cultures : Tomate 200 + Maïs 350 + Carotte 550 + Piment 800
  const int kSessionScore = 200 + 350 + 550 + 800; // 1 900

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'pq_last_date': '', // force reset au init
    });
  });

  // Helper : crée un provider injecté avec le fake audio
  ParcoursQuotidienProvider makeProvider(FakeGameProvider gp) =>
      ParcoursQuotidienProvider(gp, audioService: FakeAudioService());

  // Helper : simule une session complète (4 cultures × 20 taps)
  void completeSession(ParcoursQuotidienProvider pq) {
    for (int c = 0; c < 4; c++) {
      for (int t = 0; t < 20; t++) {
        pq.onTapArrosoir();
      }
    }
  }

  // ── Test 1 : syncScorePublic appelé exactement une fois ──
  test('syncScorePublic appelé une fois à la fin de la session', () async {
    final gp = FakeGameProvider(initialScore: 0);
    final pq = makeProvider(gp);
    await pq.init();

    completeSession(pq);

    expect(pq.sessionDone, isTrue,
        reason: 'Session doit être terminée après 4 cultures');
    expect(gp.syncCallCount, equals(1),
        reason: 'syncScorePublic doit être appelé exactement une fois');
    expect(gp.lastSyncEventType, equals('parcours_quotidien'),
        reason: 'event_type doit valoir "parcours_quotidien"');
  });

  // ── Test 2 : score existant reporté, pas remis à zéro ────
  test('score existant reporté — joueur à 30 000 pts garde son total', () async {
    const int initialScore = 30000;
    final gp = FakeGameProvider(initialScore: initialScore);
    final pq = makeProvider(gp);
    await pq.init();

    completeSession(pq);

    expect(
      gp.player.scoreTotal,
      equals(initialScore + kSessionScore),
      reason: 'Score final = $initialScore + $kSessionScore '
              '= ${initialScore + kSessionScore}',
    );
  });

  // ── Test 3 : joueur proche du seuil de retrait ───────────
  test('joueur à 32 000 pts dépasse le seuil de retrait après la session', () async {
    const int initialScore = 32000; // 32 000 + 1 900 = 33 900 > seuil 33 334
    final gp = FakeGameProvider(initialScore: initialScore);
    final pq = makeProvider(gp);
    await pq.init();

    completeSession(pq);

    expect(gp.player.scoreTotal, equals(initialScore + kSessionScore));
    expect(
      gp.player.scoreTotal,
      greaterThanOrEqualTo(33334),
      reason: 'Joueur doit être éligible au retrait après cette session',
    );
  });

  // ── Test 4 : pas de sync si session incomplète ───────────
  test('syncScorePublic non appelé si session non terminée', () async {
    final gp = FakeGameProvider(initialScore: 0);
    final pq = makeProvider(gp);
    await pq.init();

    // Seulement 2 cultures sur 4
    for (int c = 0; c < 2; c++) {
      for (int t = 0; t < 20; t++) {
        pq.onTapArrosoir();
      }
    }

    expect(pq.sessionDone, isFalse);
    expect(gp.syncCallCount, equals(0),
        reason: 'Pas de sync avant fin de session');
  });

  // ── Test 5 : reset quotidien remet la session à zéro ─────
  test('reset quotidien — date passée remet sessionDone à false', () async {
    SharedPreferences.setMockInitialValues({
      'pq_last_date': '2000-01-01', // date passée → force reset
      'pq_session_done': true,
      'pq_culture_index': 3,
    });

    final gp = FakeGameProvider(initialScore: 5000);
    final pq = makeProvider(gp);
    await pq.init();

    expect(pq.sessionDone, isFalse,
        reason: 'Reset quotidien doit annuler la session du jour précédent');
    expect(pq.cultureIndex, equals(0),
        reason: 'Index culture doit être remis à 0 après reset');
  });
}
