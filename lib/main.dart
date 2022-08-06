// Uncomment the following lines when enabling Firebase Crashlytics
// import 'dart:io';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:game_template/src/audio/audio_controller.dart';
import 'package:game_template/src/in_app_purchase/ad_removal_state.gen.dart';
import 'package:game_template/src/player_progress/player_progress.dart';
import 'package:game_template/src/settings/settings.dart';
import 'package:game_template/src/settings/settings_state.gen.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logging/logging.dart';

import 'src/ads/ads_controller.dart';
import 'src/crashlytics/crashlytics.dart';
import 'src/games_services/games_services.dart';
import 'src/games_services/score.dart';
import 'src/in_app_purchase/in_app_purchase.dart';
import 'src/level_selection/level_selection_screen.dart';
import 'src/level_selection/levels.dart';
import 'src/main_menu/main_menu_screen.dart';
import 'src/play_session/play_session_screen.dart';
import 'src/player_progress/persistence/local_storage_player_progress_persistence.dart';
import 'src/settings/persistence/local_storage_settings_persistence.dart';
import 'src/settings/settings_screen.dart';
import 'src/style/my_transition.dart';
import 'src/style/palette.dart';
import 'src/style/snack_bar.dart';
import 'src/win_game/win_game_screen.dart';

Future<void> main() async {
  // To enable Firebase Crashlytics, uncomment the following lines and
  // the import statements at the top of this file.
  // See the 'Crashlytics' section of the main README.md file for details.

  FirebaseCrashlytics? crashlytics;
  // if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
  //   try {
  //     WidgetsFlutterBinding.ensureInitialized();
  //     await Firebase.initializeApp(
  //       options: DefaultFirebaseOptions.currentPlatform,
  //     );
  //     crashlytics = FirebaseCrashlytics.instance;
  //   } catch (e) {
  //     debugPrint("Firebase couldn't be initialized: $e");
  //   }
  // }

  await guardWithCrashlytics(
    guardedMain,
    crashlytics: crashlytics,
  );
}

/// Without logging and crash reporting, this would be `void main()`.
void guardedMain() {
  if (kReleaseMode) {
    // Don't log anything below warnings in production.
    Logger.root.level = Level.WARNING;
  }
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: '
        '${record.loggerName}: '
        '${record.message}');
  });

  WidgetsFlutterBinding.ensureInitialized();

  _log.info('Going full screen');
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

Logger _log = Logger('main.dart');

// Prepare the google_mobile_ads plugin so that the first ad loads faster. This can be done later or with a delay if
// startup experience suffers.
final adsControllerProvider = (!kIsWeb && (Platform.isIOS || Platform.isAndroid))
    ? Provider<AdsController>((ref) => AdsController(MobileAds.instance)..initialize())
    : null;

// Attempt to log the player in.
final gamesServicesControllerProvider = (!kIsWeb && (Platform.isIOS || Platform.isAndroid))
    ? Provider<GamesServicesController>((ref) => GamesServicesController()..initialize())
    : null;

// Subscribing to [InAppPurchase.instance.purchaseStream] as soon as possible in order not to miss any updates and
// ask the store what the player has bought already.
final inAppPurchaseControllerProvider = (!kIsWeb && (Platform.isIOS || Platform.isAndroid))
    ? StateNotifierProvider<InAppPurchaseController, AdRemovalPurchaseState>(
        (ref) => InAppPurchaseController(InAppPurchase.instance)
          ..subscribe()
          ..restorePurchases(),
      )
    : null;

final settingsControllerProvider = StateNotifierProvider<SettingsController, SettingsState>(
  (ref) => SettingsController(persistence: LocalStorageSettingsPersistence())..loadStateFromPersistence(),
);

final audioControllerProvider = ChangeNotifierProvider<AudioController>((ref) => AudioController(ref)..initialize());

final playerProgressProvider = StateNotifierProvider<PlayerProgress, int>(
  (ref) => PlayerProgress(LocalStoragePlayerProgressPersistence())..getLatestFromStore(),
);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: true,

    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainMenuScreen(key: Key('main menu')), routes: [
        GoRoute(
            path: 'play',
            pageBuilder: (context, state) => buildMyTransition(
                  child: const LevelSelectionScreen(key: Key('level selection')),
                  color: ref.read(paletteProvider).backgroundLevelSelection,
                ),
            routes: [
              GoRoute(
                path: 'session/:level',
                pageBuilder: (context, state) {
                  final levelNumber = int.parse(state.params['level']!);
                  final level = gameLevels.singleWhere((e) => e.number == levelNumber);
                  return buildMyTransition(
                    child: PlaySessionScreen(
                      level,
                      key: const Key('play session'),
                    ),
                    color: ref.read(paletteProvider).backgroundPlaySession,
                  );
                },
              ),
              GoRoute(
                path: 'won',
                pageBuilder: (context, state) {
                  final map = state.extra! as Map<String, dynamic>;
                  final score = map['score'] as Score;

                  return buildMyTransition(
                    child: WinGameScreen(
                      score: score,
                      key: const Key('win game'),
                    ),
                    color: ref.read(paletteProvider).backgroundPlaySession,
                  );
                },
              )
            ]),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(key: Key('settings')),
        ),
      ]),
    ], // All the routes can be found there
  );
});

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    ref.read(audioControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter Demo',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: ref.read(paletteProvider).darkPen,
          background: ref.read(paletteProvider).backgroundMain,
        ),
        textTheme: TextTheme(
          bodyText2: TextStyle(
            color: ref.read(paletteProvider).ink,
          ),
        ),
      ),
      routeInformationParser: ref.read(routerProvider).routeInformationParser,
      routeInformationProvider: ref.read(routerProvider).routeInformationProvider,
      routerDelegate: ref.read(routerProvider).routerDelegate,
      scaffoldMessengerKey: scaffoldMessengerKey,
    );
  }
}
