# Requirements Document — Parcours Quotidien

## Introduction

Le **Parcours Quotidien** est une session de mini-jeu disponible une fois par jour dans AgroPast-Game. Le joueur arrose successivement quatre cultures débloquées séquentiellement (Tomate 🍅, Maïs 🌽, Carotte 🥕, Piment 🌶️) en tapant un arrosoir animé. Chaque tap ajoute +5 % de progression à la culture active. Lorsque la progression d'une culture atteint 100 %, elle est récoltée, et la culture suivante se débloque. Le score obtenu est crédité via `Player.ajouterScore()`. La session se réinitialise automatiquement à minuit. L'interface respecte la charte graphique du jeu (fond `#0d1b0f`, cartes `#1c3320`, accent `#4caf50`) et fonctionne de manière identique sur Android et Web.

---

## Glossaire

- **ParcoursQuotidienProvider** : `ChangeNotifier` Flutter dédié à la gestion d'état du Parcours Quotidien, indépendant de `GameProvider`.
- **Session Quotidienne** : Période d'une journée civile durant laquelle le joueur peut effectuer une partie du Parcours Quotidien. Elle expire et se réinitialise à minuit (00:00:00 heure locale).
- **Culture Active** : La culture en cours d'arrosage lors de la session (parmi Tomate, Maïs, Carotte, Piment).
- **Arrosoir** : Widget interactif (bouton/zone tappable) affichant un arrosoir animé que le joueur tape pour progresser.
- **Tap Arrosoir** : Événement produit lorsque le joueur appuie sur l'Arrosoir.
- **Progression** : Indicateur numérique exprimé en pourcentage (0 % à 100 %) représentant l'avancement de l'arrosage de la Culture Active.
- **Grille de Cultures** : Composant visuel affichant les quatre cultures sous forme de cartes avec leur état (verrouillé, en cours, récoltée).
- **Particules** : Effet visuel d'éclaboussures d'eau rendu via `CustomPainter`, déclenché à chaque Tap Arrosoir.
- **BGM** : Musique de fond (background music) jouée pendant la session, gérée par une instance `audioplayers`.
- **SFX** : Son d'effet (sound effect) joué à chaque Tap Arrosoir, géré par une instance `audioplayers` séparée.
- **SharedPreferences** : Mécanisme de persistance locale utilisé pour sauvegarder l'état de la session entre les lancements de l'application. Sur web, les données sont stockées dans le cache du navigateur et peuvent être effacées.
- **Player.ajouterScore()** : Méthode existante du modèle `Player` qui ajoute des points au score total et détecte les montées de niveau.
- **Reset Minuit** : Réinitialisation automatique de la session quotidienne lorsque la date courante dépasse la date de la dernière session enregistrée.

---

## Requirements

### Requirement 1 — Navigation vers le Parcours Quotidien

**User Story :** En tant que joueur, je veux accéder au Parcours Quotidien depuis l'écran d'accueil, afin de lancer ma session du jour en un seul geste.

#### Acceptance Criteria

1. THE `HomeScreen` SHALL afficher un bouton « Parcours Quotidien » dans le menu principal, avec une icône représentant un arrosoir.
2. WHEN le joueur appuie sur le bouton « Parcours Quotidien », THE `HomeScreen` SHALL naviguer vers le `ParcoursQuotidienScreen` via une transition de route simple (`MaterialPageRoute`), sans animation Hero.
3. WHILE la Session Quotidienne du jour est déjà terminée, THE `HomeScreen` SHALL afficher un indicateur visuel sur le bouton signalant que la session a été effectuée.

---

### Requirement 2 — Initialisation et état de la session

**User Story :** En tant que joueur, je veux que mon avancement quotidien soit sauvegardé et réinitialisé chaque jour, afin de retrouver mon état exact à la réouverture de l'application.

#### Acceptance Criteria

1. WHEN le `ParcoursQuotidienProvider` est initialisé, THE `ParcoursQuotidienProvider` SHALL charger depuis `SharedPreferences` la date de la dernière session, l'index de la Culture Active, et la Progression courante.
2. WHEN la date locale courante est strictement supérieure à la date de la dernière session enregistrée, THE `ParcoursQuotidienProvider` SHALL réinitialiser la Progression à 0 %, la Culture Active à Tomate (index 0), et enregistrer la nouvelle date de session dans `SharedPreferences`.
3. THE `ParcoursQuotidienProvider` SHALL persister dans `SharedPreferences` tout changement d'état (Progression, Culture Active, date de session) immédiatement après chaque Tap Arrosoir.
4. IF une erreur de lecture ou d'écriture `SharedPreferences` survient, THEN THE `ParcoursQuotidienProvider` SHALL continuer la session en mémoire sans interrompre le joueur.
5. WHERE la session est exécutée sur navigateur web, THE `ParcoursQuotidienProvider` SHALL afficher un avertissement non bloquant indiquant que les données de progression sont stockées dans le cache du navigateur et peuvent être perdues si celui-ci est effacé.

---

### Requirement 3 — Grille des quatre cultures (P0)

**User Story :** En tant que joueur, je veux voir les quatre cultures de ma session quotidienne affichées sous forme de grille, afin de visualiser d'un coup d'œil ma progression globale.

#### Acceptance Criteria

1. THE `ParcoursQuotidienScreen` SHALL afficher une grille contenant exactement quatre cartes de cultures dans l'ordre : Tomate 🍅, Maïs 🌽, Carotte 🥕, Piment 🌶️.
2. THE `ParcoursQuotidienScreen` SHALL rendre chaque carte avec un fond de couleur `#1c3320` et une bordure d'accent `#4caf50` sur fond général `#0d1b0f`.
3. WHILE une culture est verrouillée (index supérieur à l'index de la Culture Active), THE `ParcoursQuotidienScreen` SHALL afficher la carte de cette culture grisée et non interactive.
4. WHILE une culture est la Culture Active, THE `ParcoursQuotidienScreen` SHALL afficher la carte avec une barre de progression horizontale indiquant la Progression en pourcentage (0 % à 100 %).
5. WHEN la Progression d'une culture atteint 100 %, THE `ParcoursQuotidienScreen` SHALL afficher la carte de cette culture avec un badge « ✅ Récoltée » et une animation de transition vers la culture suivante.
6. WHILE toutes les quatre cultures ont été récoltées, THE `ParcoursQuotidienScreen` SHALL afficher un écran de résultats récapitulant le score total de la session et un message de félicitations.

---

### Requirement 4 — Mécanique de tap arrosoir (P0)

**User Story :** En tant que joueur, je veux taper sur l'arrosoir pour arroser ma culture active et progresser dans ma session, afin de ressentir une boucle de jeu satisfaisante.

#### Acceptance Criteria

1. THE `ParcoursQuotidienScreen` SHALL afficher un widget Arrosoir interactif centré dans la partie inférieure de l'écran.
2. WHEN le joueur effectue un Tap Arrosoir, THE `ParcoursQuotidienProvider` SHALL incrémenter la Progression de la Culture Active de 5 points de pourcentage.
3. WHEN le joueur effectue un Tap Arrosoir, THE `ParcoursQuotidienScreen` SHALL déclencher l'effet de Particules d'eau via `CustomPainter` à la position du tap.
4. WHEN la Progression de la Culture Active atteint exactement 100 %, THE `ParcoursQuotidienProvider` SHALL calculer le score de récolte de la culture et appeler `Player.ajouterScore()` avec ce score.
5. WHEN `Player.ajouterScore()` retourne un `NiveauInfo` non nul (montée de niveau), THE `ParcoursQuotidienScreen` SHALL afficher la dialog de montée de niveau existante de l'application.
6. WHEN la Progression dépasse 100 % suite à un Tap Arrosoir, THE `ParcoursQuotidienProvider` SHALL plafonner la Progression à 100 % avant de déclencher la récolte.
7. WHILE la Session Quotidienne est terminée (quatre cultures récoltées), THE `ParcoursQuotidienProvider` SHALL ignorer tout Tap Arrosoir supplémentaire sans modifier l'état.

---

### Requirement 5 — Déblocage séquentiel des cultures

**User Story :** En tant que joueur, je veux débloquer les cultures une par une dans l'ordre défini, afin de ressentir une progression et une montée en difficulté tout au long de ma session.

#### Acceptance Criteria

1. THE `ParcoursQuotidienProvider` SHALL initialiser chaque nouvelle session avec uniquement la Tomate (index 0) comme Culture Active, les cultures Maïs, Carotte et Piment étant verrouillées.
2. WHEN la Culture Active à l'index N atteint 100 % de Progression, THE `ParcoursQuotidienProvider` SHALL définir la culture à l'index N+1 comme nouvelle Culture Active, si N+1 < 4.
3. WHEN la Culture Active est Tomate et que sa Progression atteint 100 %, THE `ParcoursQuotidienProvider` SHALL débloquer Maïs comme nouvelle Culture Active.
4. WHEN la Culture Active est Maïs et que sa Progression atteint 100 %, THE `ParcoursQuotidienProvider` SHALL débloquer Carotte comme nouvelle Culture Active.
5. WHEN la Culture Active est Carotte et que sa Progression atteint 100 %, THE `ParcoursQuotidienProvider` SHALL débloquer Piment comme nouvelle Culture Active.
6. WHEN la Culture Active est Piment et que sa Progression atteint 100 %, THE `ParcoursQuotidienProvider` SHALL marquer la Session Quotidienne comme terminée.

---

### Requirement 6 — Effets visuels de particules (P0)

**User Story :** En tant que joueur, je veux voir des éclaboussures d'eau animées à chaque tap, afin d'obtenir un retour visuel immédiat et engageant.

#### Acceptance Criteria

1. THE `ParcoursQuotidienScreen` SHALL implémenter l'effet de Particules via un `CustomPainter` dédié, sans dépendance à une bibliothèque d'animation tierce.
2. WHEN un Tap Arrosoir est détecté, THE `ParcoursQuotidienScreen` SHALL créer entre 8 et 15 particules d'eau dont la position initiale correspond à la position du tap sur l'écran.
3. WHILE les particules sont actives, THE `ParcoursQuotidienScreen` SHALL animer chaque particule avec une trajectoire divergente, une décélération progressive, et une réduction d'opacité jusqu'à 0 en 400 millisecondes maximum.
4. WHILE les particules sont actives, THE `ParcoursQuotidienScreen` SHALL rendre chaque particule avec une couleur dans la gamme bleu clair à cyan (`#29b6f6` à `#80deea`).
5. IF la fréquence de tap dépasse 10 taps par seconde, THEN THE `ParcoursQuotidienScreen` SHALL limiter le nombre de groupes de particules simultanés à 5 afin de préserver les performances.

---

### Requirement 7 — Audio (P1)

**User Story :** En tant que joueur, je veux entendre une musique de fond et des sons d'arrosage, afin d'être davantage immergé dans la session quotidienne.

#### Acceptance Criteria

1. THE `ParcoursQuotidienProvider` SHALL gérer deux instances `audioplayers` distinctes : une dédiée à la BGM et une dédiée aux SFX.
2. WHEN le `ParcoursQuotidienScreen` est affiché pour la première fois lors d'une session, THE `ParcoursQuotidienProvider` SHALL démarrer la BGM en lecture en boucle à volume réduit (volume ≤ 0,5).
3. WHEN le joueur quitte le `ParcoursQuotidienScreen`, THE `ParcoursQuotidienProvider` SHALL arrêter la BGM et libérer les ressources `audioplayers`.
4. WHEN un Tap Arrosoir est détecté, THE `ParcoursQuotidienProvider` SHALL jouer un SFX d'arrosage via l'instance SFX sans interrompre la BGM.
5. WHERE l'application s'exécute sur navigateur web, THE `ParcoursQuotidienProvider` SHALL ne démarrer la BGM qu'après le premier Tap Arrosoir du joueur afin de respecter la politique d'autoplay des navigateurs.
6. IF une erreur de chargement de fichier audio survient, THEN THE `ParcoursQuotidienProvider` SHALL continuer la session sans audio sans afficher de message d'erreur visible au joueur.

---

### Requirement 8 — Retour haptique (P2)

**User Story :** En tant que joueur sur Android, je veux ressentir une vibration légère à chaque tap d'arrosoir, afin d'obtenir un retour physique renforçant le ressenti de jeu.

#### Acceptance Criteria

1. WHERE la plateforme est Android, WHEN un Tap Arrosoir est détecté, THE `ParcoursQuotidienScreen` SHALL déclencher une vibration haptique légère via `HapticFeedback.lightImpact()`.
2. WHERE la plateforme est Web ou iOS, THE `ParcoursQuotidienScreen` SHALL ignorer silencieusement l'appel haptique sans lever d'exception.

---

### Requirement 9 — Score et intégration Player

**User Story :** En tant que joueur, je veux que les points gagnés pendant le Parcours Quotidien soient ajoutés à mon score global, afin de progresser dans le jeu principal.

#### Acceptance Criteria

1. WHEN une culture est récoltée (Progression atteint 100 %), THE `ParcoursQuotidienProvider` SHALL calculer un score de récolte compris entre 200 et 800 points selon la position de la culture dans la séquence (Tomate : 200, Maïs : 350, Carotte : 550, Piment : 800).
2. WHEN le score de récolte est calculé, THE `ParcoursQuotidienProvider` SHALL appeler `Player.ajouterScore(score)` sur l'instance `Player` du `GameProvider` existant.
3. WHEN la Session Quotidienne est terminée, THE `ParcoursQuotidienProvider` SHALL appeler `GameProvider._save()` ou son équivalent public pour persister le score global mis à jour dans `SharedPreferences`.
4. THE `ParcoursQuotidienProvider` SHALL exposer le score cumulé de la session en cours via une propriété publique `sessionScore` de type `int`.

---

### Requirement 10 — Compatibilité Android et Web

**User Story :** En tant que joueur, je veux que le Parcours Quotidien se comporte de manière identique sur Android et sur Web, afin d'avoir une expérience cohérente quel que soit mon appareil.

#### Acceptance Criteria

1. THE `ParcoursQuotidienScreen` SHALL rendre un layout identique sur Android et sur Web avec les mêmes couleurs (`#0d1b0f`, `#1c3320`, `#4caf50`), tailles de composants et interactions.
2. THE `ParcoursQuotidienProvider` SHALL utiliser `SharedPreferences` comme unique mécanisme de persistance sur Android et sur Web sans distinction de code selon la plateforme, à l'exception des règles audio (Requirement 7.5) et haptique (Requirement 8.1).
3. WHILE l'application s'exécute en mode Web, THE `ParcoursQuotidienScreen` SHALL afficher une bannière d'information non bloquante rappelant que les données de session sont liées au cache du navigateur.
4. IF la résolution d'affichage est inférieure à 360 dp de largeur, THEN THE `ParcoursQuotidienScreen` SHALL adapter la taille des cartes de la Grille de Cultures pour rester entièrement visibles sans défilement horizontal.
