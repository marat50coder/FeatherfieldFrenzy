import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/storage.dart';
import 'services/audio.dart';
import 'services/image_assets.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow both orientations at launch so the loading screen can be shown
  // vertically or horizontally. The game itself is locked to portrait later.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  await GameStorage.instance.init();
  await Audio.instance.init();
  Audio.instance.startMusic();

  runApp(const FietherfieldFrenzyApp());
}

class FietherfieldFrenzyApp extends StatelessWidget {
  const FietherfieldFrenzyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fietherfield Frenzy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const SplashScreen(),
    );
  }
}

/// Locks the app to portrait. Called once the loading screen finishes.
Future<void> lockPortrait() async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}

/// Preloads every image the game needs. Reused by the splash screen.
Future<void> preloadEverything(BuildContext context) async {
  await ImageAssets.instance.preloadAll(context);
}
