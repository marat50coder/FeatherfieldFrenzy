import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hatchway/config/frenzy_gate_config.dart';
import 'hatchway/gate_coordinator.dart';
import 'hatchway/infra/flock_probe.dart';
import 'hatchway/infra/frenzy_safe.dart';
import 'hatchway/infra/gate_exchange.dart';
import 'hatchway/infra/perch_signals.dart';
import 'hatchway/infra/plume_agent.dart';
import 'hatchway/infra/wing_attribution.dart';
import 'hatchway/pages/portal_shell.dart';
import 'screens/splash_screen.dart';
import 'services/audio.dart';
import 'services/image_assets.dart';
import 'services/storage.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow both orientations at launch so the loading screen can be shown
  // vertically or horizontally. The game itself is locked to portrait
  // later; the WebView shell re-enables all orientations.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  final safe = FrenzySafe();
  final agent = PlumeAgent();
  await Future.wait<void>(<Future<void>>[
    GameStorage.instance.init(),
    Audio.instance.init(),
    safe.initialize(),
    agent.prepare(),
  ]);
  // Music does NOT auto-start here — silence during splash / gate probing /
  // gray-flow WebView. It's kicked off by MenuScreen.initState() so the
  // player only hears it once they're actually in the white game.

  assert(() {
    debugPrint(
      '[FFR.BOOT] credentialsReady=${FrenzyGateConfig.grayCredentialsReady} '
      'endpoint=${FrenzyGateConfig.endpoint} '
      'afKeyLen=${FrenzyGateConfig.appsFlyerKey.length} '
      'fbNum=${FrenzyGateConfig.firebaseProjectNumber}',
    );
    return true;
  }());

  var productionServicesReady = false;
  if (FrenzyGateConfig.grayCredentialsReady) {
    try {
      await Firebase.initializeApp();
      productionServicesReady = true;
      assert(() {
        debugPrint('[FFR.BOOT] Firebase.initializeApp OK');
        return true;
      }());
    } catch (error) {
      assert(() {
        debugPrint('[FFR.BOOT] Firebase.initializeApp failed: $error');
        return true;
      }());
    }
    if (productionServicesReady) {
      try {
        await FirebaseAppCheck.instance.activate(
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } catch (error) {
        // App Check must never block FCM / gray routing.
        assert(() {
          debugPrint('[FFR.BOOT] AppCheck skipped: $error');
          return true;
        }());
      }
    }
  } else {
    assert(() {
      debugPrint(
        '[FFR.BOOT] gate DISABLED — missing credentials '
        '(endpoint/af/firebase). White game only.',
      );
      return true;
    }());
  }

  final probe = FlockNetProbe();
  // Attribution + config POST must run even if Firebase failed to init;
  // only push/FCM needs productionServicesReady.
  final signals = PerchSignalHub(safe, enabled: productionServicesReady);
  final attribution = WingAttribution(agent);
  final coordinator = FrenzyGateCoordinator(
    safe: safe,
    probe: probe,
    attribution: attribution,
    exchange: GateExchange(agent, safe),
    signals: signals,
    agent: agent,
    runtimeEnabled: FrenzyGateConfig.grayCredentialsReady,
  );

  // Prewarm AppsFlyer while the splash is painting its first frame — every
  // second we shave off here is a second the user isn't staring at a
  // loading bar. Fire-and-forget: any error is surfaced later inside
  // WingAttribution.awaitSignals (which is what the gate actually awaits).
  if (FrenzyGateConfig.grayCredentialsReady) {
    // ignore: unawaited_futures
    attribution.start();
  }

  runApp(FietherfieldFrenzyApp(coordinator: coordinator));
}

class FietherfieldFrenzyApp extends StatelessWidget {
  const FietherfieldFrenzyApp({super.key, this.coordinator});

  final FrenzyGateCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fietherfield Frenzy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: SplashScreen(coordinator: coordinator),
    );
  }
}

/// Locks the app to portrait. Called before entering the white-game
/// menu; the WebView shell re-enables all orientations on its own.
Future<void> lockPortrait() async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}

/// Preloads every image the game needs. Reused by the splash screen.
Future<void> preloadEverything(BuildContext context) async {
  await ImageAssets.instance.preloadAll(context);
}

/// Widget builder for the portal shell — used by the invitation screen
/// as its "next" destination.
Widget portalShellBuilder({
  required FrenzyGateCoordinator coordinator,
  required String url,
  bool coldLaunch = false,
}) {
  return PortalShell(
    url: url,
    coldLaunch: coldLaunch,
    safe: coordinator.safe,
    probe: coordinator.probe,
    signals: coordinator.signals,
    agent: coordinator.agent,
  );
}
