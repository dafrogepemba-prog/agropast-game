# Design Document — Parcours Quotidien

## Vue d'ensemble

Le **Parcours Quotidien** est un mini-jeu de type clicker disponible une fois par jour dans AgroPast-Game.
Le joueur arrose séquentiellement quatre cultures (Tomate → Maïs → Carotte → Piment) en tapant sur un
arrosoir animé. Chaque tap apporte +5 % de progression. À 100 %, la culture est récoltée, son score est
crédité via `Player.ajouterScore()`, et la culture suivante se débloque. La session se réinitialise
automatiquement à minuit via comparaison de dates dans `SharedPreferences`.

L'implémentation est **100 % Flutter** (Android + Web), s'appuie sur le `provider` existant et
n'introduit qu'une seule dépendance tierce nouvelle : `audioplayers ^6.x`.

---

## Architecture globale

```
main.dart
  └─ MultiProvider
       ├─ GameProvider (existant)
       └─ ParcoursQuotidienProvider (nouveau) ← dépend de GameProvider
            │
            ├─ lib/models/culture.dart          (CultureType enum + Culture data class)
            ├─ lib/services/parcours_provider.dart  (ChangeNotifier — logique métier)
            ├─ lib/services/audio_service.dart      (AudioService — BGM + SFX)
            ├─ lib/screens/parcours_screen.dart     (grille 2×2 + arrosoir)
            └─ lib/widgets/particules_painter.dart  (CustomPainter eau)
```


### Flux de données

```
[HomeScreen] ──tap bouton──► [ParcoursQuotidienScreen]
                                     │
                    ┌────────────────┼────────────────────┐
                    ▼                ▼                     ▼
         ParcoursQuotidienProvider  ParticulesPainter   AudioService
                    │
          ┌─────────┼─────────┐
          ▼         ▼         ▼
    SharedPrefs  GameProvider  Player.ajouterScore()
```

---

## Composants — High-Level Design

| Couche | Fichier | Rôle |
|--------|---------|------|
| Modèle | `lib/models/culture.dart` | Enum `CultureType` + classe `Culture` (données immuables) |
| State | `lib/services/parcours_provider.dart` | `ParcoursQuotidienProvider` — logique métier, persistence, audio |
| Audio | `lib/services/audio_service.dart` | Wrappeur `audioplayers` — BGM boucle + SFX one-shot |
| Écran | `lib/screens/parcours_screen.dart` | UI principale : grille 2×2 + arrosoir + résultats |
| Widget | `lib/widgets/particules_painter.dart` | `CustomPainter` particules eau |
| Modif | `lib/screens/home_screen.dart` | Ajout bouton "Parcours Quotidien" + badge session |
| Config | `agropast_game/pubspec.yaml` | Ajout `audioplayers: ^6.1.0` |

---

## Low-Level Design

### 1. `lib/models/culture.dart`

#### Enum `CultureType`

```dart
enum CultureType { tomate, mais, carotte, piment }
```

#### Classe `Culture` (immuable)

```dart
@immutable
class Culture {
  final CultureType type;
  final String label;   // 'Tomate', 'Maïs', etc.
  final String emoji;   // '🍅', '🌽', '🥕', '🌶️'
  final int scoreRecolte; // 200, 350, 550, 800

  const Culture({
    required this.type,
    required this.label,
    required this.emoji,
    required this.scoreRecolte,
  });
}
```

#### Constante `kCultures`

```dart
const List<Culture> kCultures = [
  Culture(type: CultureType.tomate,   label: 'Tomate',  emoji: '🍅', scoreRecolte: 200),
  Culture(type: CultureType.mais,     label: 'Maïs',    emoji: '🌽', scoreRecolte: 350),
  Culture(type: CultureType.carotte,  label: 'Carotte', emoji: '🥕', scoreRecolte: 550),
  Culture(type: CultureType.piment,   label: 'Piment',  emoji: '🌶️', scoreRecolte: 800),
];
```

---


### 2. `lib/services/audio_service.dart`

```dart
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  bool _bgmStarted = false;

  /// Démarre la BGM en boucle (volume ≤ 0.5).
  /// Sur web, [requireUserGesture] doit être true : appeler après le premier tap.
  Future<void> startBgm({bool requireUserGesture = false}) async { ... }

  /// Joue un SFX one-shot (arrosage) sans interrompre la BGM.
  Future<void> playSfx() async { ... }

  /// Arrête la BGM et libère les deux players.
  Future<void> dispose() async { ... }

  bool get bgmStarted => _bgmStarted;
}
```

**Règle BGM web** : `startBgm(requireUserGesture: true)` est appelé lors du premier
`onTap` arrosoir sur web (détection via `kIsWeb`). Sur Android, il est appelé lors du
`initState` du screen.

**Gestion erreur** : tous les appels `audioplayers` sont enveloppés dans `try/catch`
silencieux — aucune exception ne remonte à l'UI (Req. 7.6).

---


### 3. `lib/services/parcours_provider.dart`

#### Structure de données `SharedPreferences`

| Clé | Type | Description |
|-----|------|-------------|
| `pq_last_date` | `String` | Date ISO `yyyy-MM-dd` de la dernière session |
| `pq_culture_index` | `int` | Index de la culture active (0–3) |
| `pq_progression` | `double` | Progression courante (0.0–100.0) |
| `pq_session_done` | `bool` | `true` si les 4 cultures ont été récoltées |
| `pq_session_score` | `int` | Score cumulé de la session en cours |

#### Classe `ParcoursQuotidienProvider`

```dart
class ParcoursQuotidienProvider extends ChangeNotifier {
  // ── Dépendances ───────────────────────────────────────────
  final GameProvider _gameProvider;
  final AudioService _audio = AudioService();

  // ── État en mémoire ───────────────────────────────────────
  int     _cultureIndex = 0;       // 0 = Tomate ... 3 = Piment
  double  _progression  = 0.0;     // 0.0 à 100.0
  bool    _sessionDone  = false;
  int     _sessionScore = 0;
  String  _lastDate     = '';      // 'yyyy-MM-dd'

  // ── Getters publics ───────────────────────────────────────
  int    get cultureIndex => _cultureIndex;
  double get progression  => _progression;
  bool   get sessionDone  => _sessionDone;
  int    get sessionScore => _sessionScore;
  Culture get cultureCourante => kCultures[_cultureIndex];
  NiveauInfo? levelUpEvent;  // non-null = montée à afficher

  // ── Init ──────────────────────────────────────────────────
  ParcoursQuotidienProvider(this._gameProvider);

  /// Charge l'état depuis SharedPreferences.
  /// Appeler dans initState via Future.microtask.
  Future<void> init() async { ... }

  // ── Action principale ─────────────────────────────────────
  /// Appelé à chaque tap arrosoir.
  /// [isWeb] : true si kIsWeb (pour démarrer BGM au premier tap).
  void onTapArrosoir({bool isWeb = false}) { ... }

  // ── Interne ───────────────────────────────────────────────
  void   _incrementProgression() { ... }   // +5 pts, plafond à 100
  void   _recolterCulture() { ... }        // score + ajouterScore + déblocage
  void   _avancerCulture() { ... }         // index++ ou sessionDone = true
  Future<void> _save() async { ... }       // persist SharedPreferences
  void   _checkReset(String today) { ... } // comparaison dates + reset si besoin
  String _todayStr() { ... }               // 'yyyy-MM-dd' heure locale

  // ── Nettoyage ─────────────────────────────────────────────
  @override
  void dispose() { _audio.dispose(); super.dispose(); }
}
```


#### Algorithme `onTapArrosoir`

```
onTapArrosoir(isWeb):
  1. if sessionDone → return (Req. 4.7)
  2. if isWeb && !audio.bgmStarted → audio.startBgm(requireUserGesture: true) (Req. 7.5)
  3. audio.playSfx() (Req. 7.4)
  4. _incrementProgression()             → progression = min(progression + 5, 100) (Req. 4.6)
  5. if progression == 100:
       _recolterCulture()                (Req. 4.4, 9.1)
       _avancerCulture()                 (Req. 5.2)
  6. _save()                             (Req. 2.3)
  7. notifyListeners()
```

#### Algorithme `_recolterCulture`

```
_recolterCulture():
  score = kCultures[_cultureIndex].scoreRecolte   (Req. 9.1)
  _sessionScore += score                           (Req. 9.4)
  NiveauInfo? montee = _gameProvider.player.ajouterScore(score)  (Req. 4.4, 9.2)
  if montee != null → levelUpEvent = montee         (Req. 4.5)
  if cultureIndex == 3 (Piment):
    _sessionDone = true                             (Req. 5.6)
    _gameProvider.savePublic()                      (Req. 9.3)
```

#### Algorithme `init`

```
init():
  prefs = await SharedPreferences.getInstance()
  try:
    _lastDate     = prefs.getString('pq_last_date') ?? ''
    _cultureIndex = prefs.getInt('pq_culture_index') ?? 0
    _progression  = prefs.getDouble('pq_progression') ?? 0.0
    _sessionDone  = prefs.getBool('pq_session_done') ?? false
    _sessionScore = prefs.getInt('pq_session_score') ?? 0
  catch:
    // continuer en mémoire (Req. 2.4) — état déjà initialisé aux valeurs par défaut
  _checkReset(_todayStr())                          (Req. 2.2)
  notifyListeners()
```

#### Algorithme `_checkReset`

```
_checkReset(today):
  if _lastDate.isEmpty || _lastDate < today:        (Req. 2.2)
    _cultureIndex = 0
    _progression  = 0.0
    _sessionDone  = false
    _sessionScore = 0
    _lastDate     = today
    _save()
```

---


#### Méthode `savePublic` sur `GameProvider`

`GameProvider._save()` est actuellement privée. Pour l'appel depuis `ParcoursQuotidienProvider`
(Req. 9.3), on expose une méthode publique :

```dart
// Dans GameProvider
Future<void> savePublic() => _save();
```

---

### 4. `lib/widgets/particules_painter.dart`

#### Modèle de données `Particule`

```dart
class Particule {
  Offset position;      // position courante
  Offset velocity;      // vitesse initiale (px/frame)
  double opacity;       // 1.0 → 0.0
  double radius;        // 3.0 à 6.0 px
  Color  color;         // gamme #29b6f6 – #80deea
}
```

#### Classe `ParticulesPainter`

```dart
class ParticulesPainter extends CustomPainter {
  final List<Particule> particules;

  const ParticulesPainter({required this.particules, required Listenable repaint})
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) { ... }  // dessine chaque particule

  @override
  bool shouldRepaint(ParticulesPainter old) => true;
}
```

#### Mixin `ParticulesController` (dans `_ParcoursScreenState`)

```dart
// Intégré dans _ParcoursScreenState
AnimationController _partAnim;         // durée 400 ms
final List<List<Particule>> _groups = []; // max 5 groupes actifs (Req. 6.5)

void _spawnParticules(Offset tapPos) {
  // 1. count = Random().nextInt(8) + 8  → [8, 15] (Req. 6.2)
  // 2. générer count Particule avec position=tapPos, velocity aléatoire divergente
  // 3. couleur : lerp(Color(0xFF29b6f6), Color(0xFF80deea), t) (Req. 6.4)
  // 4. if _groups.length >= 5 → retirer le plus ancien (Req. 6.5)
  // 5. démarrer _partAnim (Req. 6.3)
}
```

Les particules sont animées via un `Ticker` qui met à jour position et opacité à chaque frame.
La décélération est simulée par un facteur de friction `velocity *= 0.85` par frame.
L'animation se termine quand opacité ≤ 0 (≤ 400 ms pour velocity standard).

---


### 5. `lib/screens/parcours_screen.dart`

#### Structure du widget

```dart
class ParcoursQuotidienScreen extends StatefulWidget { ... }

class _ParcoursScreenState extends State<ParcoursQuotidienScreen>
    with TickerProviderStateMixin {

  // ── Controllers ───────────────────────────────────────────
  late AnimationController _partAnim;   // particules
  late AnimationController _recolteAnim; // badge récolte (scale)
  final List<List<Particule>> _groups = [];

  @override void initState() { ... }    // init provider + BGM Android
  @override void dispose()   { ... }    // dispose animations + BGM

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1b0f),
      appBar: ...,
      body: Consumer<ParcoursQuotidienProvider>(
        builder: (ctx, pq, _) {
          if (pq.sessionDone) return _buildResultats(pq);
          return Column(children: [
            if (kIsWeb) _WebBanner(),       // Req. 10.3
            _GrilleCultures(pq),            // Req. 3.1–3.5
            const Spacer(),
            _ArrosoirWidget(onTap: _onTap), // Req. 4.1
          ]);
        },
      ),
    );
  }

  void _onTap(Offset pos) {
    // 1. Haptique Android (Req. 8.1)
    // 2. Spawn particules (Req. 4.3)
    // 3. pq.onTapArrosoir(isWeb: kIsWeb)
    // 4. Vérifier levelUpEvent → dialog (Req. 4.5)
  }
}
```

#### Grille 2×2 `_GrilleCultures`

```dart
Widget _GrilleCultures(ParcoursQuotidienProvider pq) =>
  GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    padding: const EdgeInsets.all(12),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    children: List.generate(4, (i) => _CultureCard(
      culture: kCultures[i],
      etat: _etatCulture(i, pq),
      progression: i == pq.cultureIndex ? pq.progression : 0,
    )),
  );
```

#### Widget `_CultureCard`

```dart
enum EtatCulture { locked, active, done }

class _CultureCard extends StatelessWidget {
  // fond #1c3320, bordure #4caf50 (Req. 3.2)
  // locked : ColorFilter gris + IgnorePointer (Req. 3.3)
  // active : LinearProgressIndicator vert (Req. 3.4)
  // done   : badge "✅ Récoltée" (Req. 3.5)
  // Responsive : LayoutBuilder → contrainte minWidth 150 dp (Req. 10.4)
}
```

#### Widget `_ArrosoirWidget`

```dart
class _ArrosoirWidget extends StatefulWidget {
  final void Function(Offset tapPosition) onTap;
  // Animation oscillation (scale) en boucle pour indiquer l'interactivité
  // GestureDetector.onTapDown fournit TapDownDetails.globalPosition
}
```

---


#### Écran de résultats `_buildResultats`

```dart
Widget _buildResultats(ParcoursQuotidienProvider pq) => Center(
  child: Column(children: [
    const Text('🎉 Parcours terminé !', style: ...),
    Text('Score session : ${pq.sessionScore} pts', style: ...),
    // Récapitulatif des 4 cultures avec leurs scores
    ElevatedButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Retour à l\'accueil'),
    ),
  ]),
);
```

---

### 6. Modifications — `lib/screens/home_screen.dart`

Ajout d'un bouton `_MenuButton` dans la section "Menu principal" :

```dart
_MenuButton(
  icon: Icons.water_drop,            // icône arrosoir
  label: 'Parcours Quotidien',
  subtitle: sessionDone
    ? '✅ Session du jour effectuée'
    : '🌱 Session disponible',
  color: const Color(0xFF1b5e20),
  badge: sessionDone ? '✅ Fait' : null,  // Req. 1.3
  onTap: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const ParcoursQuotidienScreen())),
),
```

`sessionDone` est lu depuis `context.watch<ParcoursQuotidienProvider>().sessionDone`.

---

### 7. Modifications — `agropast_game/pubspec.yaml`

```yaml
dependencies:
  # ... dépendances existantes ...
  audioplayers: ^6.1.0    # BGM + SFX Parcours Quotidien (P1)
```

Fichiers audio à ajouter dans `assets/sounds/` :
- `bgm_parcours.mp3` — musique de fond (loop, ≤ 500 ko)
- `sfx_arrosage.mp3` — son arrosoir (one-shot, ≤ 50 ko)

```yaml
flutter:
  assets:
    - assets/images/
    - assets/sounds/      # déjà déclaré dans pubspec existant
```

---

### 8. Intégration `MultiProvider` dans `main.dart`

```dart
runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => GameProvider()),
      ChangeNotifierProxyProvider<GameProvider, ParcoursQuotidienProvider>(
        create: (ctx) => ParcoursQuotidienProvider(
            Provider.of<GameProvider>(ctx, listen: false)),
        update: (ctx, gp, prev) => prev ?? ParcoursQuotidienProvider(gp),
      ),
    ],
    child: const AgroPastApp(),
  ),
);
```

`ChangeNotifierProxyProvider` garantit que `ParcoursQuotidienProvider` reçoit la
référence à `GameProvider` sans créer de dépendance circulaire.

---


## Gestion des erreurs

| Scénario | Comportement |
|----------|-------------|
| `SharedPreferences` illisible | Session démarre avec état initial en mémoire (Req. 2.4) |
| `SharedPreferences` non-writable | Tap continue normalement, état perdu à la fermeture |
| Fichier audio manquant | `try/catch` silencieux, session continue sans son (Req. 7.6) |
| `Player.ajouterScore` retourne null | Aucun dialog — comportement normal |
| Tap après session terminée | `onTapArrosoir` retourne immédiatement (guard en tête) (Req. 4.7) |
| Résolution < 360 dp | `LayoutBuilder` adapte la taille des cartes (Req. 10.4) |
| Taux de tap > 10/s | `_groups.length >= 5` → suppression du groupe le plus ancien (Req. 6.5) |

---

## Charte graphique appliquée

| Élément | Couleur |
|---------|---------|
| Fond `Scaffold` | `#0d1b0f` |
| Fond cartes culture | `#1c3320` |
| Bordure / accent | `#4caf50` |
| Barre de progression | `#4caf50` |
| Particules eau | `#29b6f6` → `#80deea` (lerp aléatoire) |
| Badge récolte | Blanc sur fond `#2e7d32` |
| Texte score | `#f9a825` (cohérence avec l'app existante) |

---

## Contraintes de plateforme

| Comportement | Android | Web |
|-------------|---------|-----|
| BGM démarrage | Au `initState` | Au premier tap (autoplay policy) |
| Haptique | `HapticFeedback.lightImpact()` | Ignoré silencieusement |
| `SharedPreferences` | Fichier local | Cache navigateur + bannière info |
| Particules `CustomPainter` | ✅ identique | ✅ identique |
| Layout grille 2×2 | ✅ identique | ✅ identique |

---


## Correctness Properties

*Une propriété est une caractéristique ou un comportement qui doit être vrai pour toutes
les exécutions valides du système — c'est-à-dire une spécification formelle de ce que le
logiciel doit faire. Les propriétés servent de pont entre les spécifications lisibles par
l'humain et les garanties de correction vérifiables automatiquement.*

---

### Property 1 : Round-trip persistence de l'état de session

*Pour tout* tuple valide `(dateISO, cultureIndex ∈ [0,3], progression ∈ [0.0, 100.0], sessionScore ≥ 0)`,
sauvegarder cet état dans `SharedPreferences` via `_save()` puis recharger via `init()` doit
produire un `ParcoursQuotidienProvider` dont les champs correspondent exactement aux valeurs
sauvegardées.

**Validates: Requirements 2.1, 2.3**

---

### Property 2 : Reset automatique à minuit

*Pour toute* date `lastDate` strictement inférieure à la date courante (date dans le passé ou
veille), l'appel à `init()` doit réinitialiser `cultureIndex = 0`, `progression = 0.0`,
`sessionDone = false` et `sessionScore = 0`, quelle que soit la valeur précédemment persistée.

**Validates: Requirements 2.2**

---

### Property 3 : Invariant de progression (plafond 100 %)

*Pour toute* progression initiale `P ∈ [0.0, 100.0]`, après un appel à `onTapArrosoir()`,
la progression résultante est `min(P + 5.0, 100.0)` et ne dépasse jamais 100.0.

**Validates: Requirements 4.2, 4.6**

---

### Property 4 : Idempotence de la session terminée

*Pour tout* état de session où `sessionDone = true`, quelle que soit la séquence de N appels
supplémentaires à `onTapArrosoir()` (N ≥ 1), l'état du provider reste inchangé :
`cultureIndex`, `progression`, `sessionScore` et `sessionDone` ne sont pas modifiés.

**Validates: Requirements 4.7, 7.4** (le SFX ne doit pas non plus être joué)

---

### Property 5 : Déblocage séquentiel des cultures

*Pour tout* index de culture `N ∈ [0, 2]`, quand la `progression` atteint 100.0 avec
`cultureIndex = N`, le prochain état doit avoir `cultureIndex = N + 1` et `progression = 0.0`.

**Validates: Requirements 5.2, 5.3, 5.4, 5.5**

---

### Property 6 : Score de récolte conforme à la table

*Pour tout* index de culture `N ∈ [0, 3]`, le score calculé lors de la récolte de la culture
à l'index `N` doit être exactement `kCultures[N].scoreRecolte`, c'est-à-dire
`[200, 350, 550, 800][N]`.

**Validates: Requirements 9.1**

---

### Property 7 : Accumulation correcte du score de session

*Pour tout* sous-ensemble de cultures récoltées (combinaison valide d'index 0 à 3 en ordre
séquentiel), `sessionScore` doit être égal à la somme exacte des `scoreRecolte` des cultures
récoltées jusqu'à présent.

**Validates: Requirements 9.4**

---

### Property 8 : Ordre invariant des cultures affiché

*Pour tout* état de session valide (cultureIndex ∈ [0,3], sessionDone ∈ {true,false}),
la grille du `ParcoursQuotidienScreen` affiche toujours exactement quatre cartes dans
l'ordre fixe : Tomate (0), Maïs (1), Carotte (2), Piment (3).

**Validates: Requirements 3.1**

---

### Property 9 : Verrouillage des cultures non débloquées

*Pour tout* état de session avec `cultureIndex = N`, toute culture dont l'index `i > N`
doit être dans l'état `EtatCulture.locked` (grisée, non interactive), et toute culture
dont l'index `i < N` doit être dans l'état `EtatCulture.done`.

**Validates: Requirements 3.3**

---

### Property 10 : Nombre de particules dans l'intervalle [8, 15]

*Pour tout* tap arrosoir sur une session non terminée, le nombre de particules créées
dans le groupe correspondant est un entier dans l'intervalle fermé [8, 15].

**Validates: Requirements 6.2**

---

### Property 11 : Couleurs des particules dans la gamme eau

*Pour toute* particule générée par un tap arrosoir, sa composante `color` doit être une
interpolation entre `Color(0xFF29b6f6)` et `Color(0xFF80deea)`, c'est-à-dire que
ses composantes R, G, B doivent rester dans les bornes définies par ces deux couleurs.

**Validates: Requirements 6.4**

---


## Stratégie de test

### Tests unitaires (example-based)

| Test | Fichier cible |
|------|---------------|
| Init provider avec état vide → valeurs par défaut | `parcours_provider_test.dart` |
| Bouton Parcours Quotidien présent dans HomeScreen | `home_screen_test.dart` |
| Dialog montée de niveau affiché quand `levelUpEvent != null` | `parcours_screen_test.dart` |
| BGM web ne démarre pas avant le premier tap | `audio_service_test.dart` |
| Session complète → `GameProvider.savePublic()` appelé | `parcours_provider_test.dart` |
| Écran de résultats affiché quand `sessionDone = true` | `parcours_screen_test.dart` |

### Tests de propriétés (property-based)

Bibliothèque recommandée : [`fast_check`](https://pub.dev/packages/fast_check) (Dart, 100 itérations min).

| Tag | Propriété testée | Fichier |
|-----|-----------------|---------|
| `Feature: parcours-quotidien, Property 1: round-trip persistence` | Round-trip SharedPreferences | `parcours_pbt_test.dart` |
| `Feature: parcours-quotidien, Property 2: reset minuit` | Reset sur date passée | `parcours_pbt_test.dart` |
| `Feature: parcours-quotidien, Property 3: plafond 100%` | `min(P+5, 100)` toujours respecté | `parcours_pbt_test.dart` |
| `Feature: parcours-quotidien, Property 4: idempotence session terminée` | N taps sur session done → état inchangé | `parcours_pbt_test.dart` |
| `Feature: parcours-quotidien, Property 5: déblocage séquentiel` | index N → N+1 à 100% | `parcours_pbt_test.dart` |
| `Feature: parcours-quotidien, Property 6: score récolte` | score = table[N] | `parcours_pbt_test.dart` |
| `Feature: parcours-quotidien, Property 7: sessionScore cumulatif` | sum des scores récoltés | `parcours_pbt_test.dart` |
| `Feature: parcours-quotidien, Property 8: ordre cultures` | ordre Tomate→Maïs→Carotte→Piment | `parcours_pbt_test.dart` |
| `Feature: parcours-quotidien, Property 9: verrouillage cultures` | locked/done selon cultureIndex | `parcours_pbt_test.dart` |
| `Feature: parcours-quotidien, Property 10: count particules [8,15]` | count ∈ [8,15] pour tout tap | `particules_pbt_test.dart` |
| `Feature: parcours-quotidien, Property 11: couleurs particules` | composantes R,G,B dans bornes | `particules_pbt_test.dart` |
