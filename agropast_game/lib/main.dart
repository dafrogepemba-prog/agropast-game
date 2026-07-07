import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/admob_service.dart';
import 'services/game_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Init AdMob SDK de production
  await AdMobService.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => GameProvider(),
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
