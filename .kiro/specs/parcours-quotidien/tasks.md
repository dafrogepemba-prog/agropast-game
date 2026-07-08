# Tasks — Parcours Quotidien

## Build 1 — P0 : Boucle quotidienne + Grille + Clicker

- [ ] 1. Créer `lib/models/culture.dart` — enum CultureType, classe Culture, constante kCultures
- [ ] 2. Exposer `GameProvider.savePublic()` dans `lib/services/game_provider.dart`
- [ ] 3. Créer `lib/services/parcours_provider.dart` — ParcoursQuotidienProvider (logique + SharedPreferences)
- [ ] 4. Créer `lib/widgets/particules_painter.dart` — CustomPainter particules eau
- [ ] 5. Créer `lib/screens/parcours_screen.dart` — grille 2×2 + arrosoir + résultats
- [ ] 6. Modifier `lib/screens/home_screen.dart` — ajouter bouton Parcours Quotidien
- [ ] 7. Modifier `lib/main.dart` — MultiProvider avec ChangeNotifierProxyProvider
- [ ] 8. Build web + build APK CI + push

## Build 2 — P1 : Audio

- [ ] 9. Ajouter `audioplayers: ^6.1.0` dans pubspec.yaml
- [ ] 10. Créer `lib/services/audio_service.dart` — AudioService BGM + SFX
- [ ] 11. Intégrer AudioService dans ParcoursQuotidienProvider
- [ ] 12. Ajouter assets/sounds/bgm_parcours.mp3 + sfx_arrosage.mp3 (fournis par l'utilisateur)
- [ ] 13. Build + push

## Build 3 — P2 : Polish

- [ ] 14. Ajouter HapticFeedback.lightImpact() sur Android dans parcours_screen.dart
- [ ] 15. Transition couleur fond selon progression (AnimatedContainer background)
- [ ] 16. Build + push
