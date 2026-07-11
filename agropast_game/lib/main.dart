import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/ad_mediation_service.dart';
import 'services/game_provider.dart';
import 'services/parcours_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Init Ad Mediation SDK (AdMob + Unity Ads)
  await AdMediationServiceBase.init();

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
}

class AgroPastApp extends StatelessWidget {
  const AgroPastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroPast-Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2e7d32),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1b2a1b),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
