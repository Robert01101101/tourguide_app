import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';

var logger = Logger();
final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  //FIREBASE INIT
  //https://stackoverflow.com/a/63537567/7907510
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  //LOAD ENVIRONMENT (SECURE VARS)
  await fetchConfig();

  //LOGGING
  Logger.level = Level.trace;

  //ROUTING
  await TourguideNavigation.instance.initialize();

  //CRASHLYTICS
  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  //Splash
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(const MyApp());
}

Future<void> fetchConfig() async {
  try {
    // Set settings to fetch from the server with a timeout and a minimum fetch interval
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: Duration(minutes: 1),
        minimumFetchInterval: Duration(hours: 1),
      ),
    );
    // Fetch and activate the remote config values
    await remoteConfig.fetchAndActivate();
  } catch (e) {
    print("Failed to fetch remote config: $e");
  }
}

String getFormattedTime(){
  DateTime now = DateTime.now();
  return " - at ${DateFormat('HH:mm:ss.SSS').format(now)}";
}




class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}



class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      clearPrefsOnClose();
    }
  }

  void clearPrefsOnClose() async {
    logger.t("clearPrefsOnClose()");
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('chat_messages');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => TourProvider()),
        ChangeNotifierProxyProvider<AuthProvider, TourguideUserProvider>(
          create: (_) => TourguideUserProvider(), // Provide TourguideUserProvider with access to AuthProvider
          update: (_, authProvider, userProvider) => userProvider!..setAuthProvider(authProvider),
        ),
      ],
      child: MaterialApp.router(
        scaffoldMessengerKey: SnackBarService.scaffoldKey,
        title: 'Tourguide App',
        routerConfig: TourguideNavigation.router,
        theme: _buildTheme(),
      ),
    );
  }

  ThemeData _buildTheme() {
    const Color primaryColor = Color(0xFF6fece4);
    var baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
    );

    final textTheme = baseTheme.textTheme;

    return baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.white,
      textTheme: GoogleFonts.latoTextTheme(textTheme).copyWith(
        //Titles are GoogleFonts latoTextTheme but bold
        titleLarge: GoogleFonts.lato(textStyle: textTheme.titleLarge, color: const Color(0xff3b4948), fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.lato(textStyle: textTheme.titleMedium, color: const Color(0xff3b4948), fontWeight: FontWeight.bold),
        titleSmall: GoogleFonts.lato(textStyle: textTheme.titleSmall, color: const Color(0xff3b4948), fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.lato(textStyle: textTheme.headlineLarge, color: const Color(0xff3b4948), fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.lato(textStyle: textTheme.headlineMedium, color: const Color(0xff3b4948), fontWeight: FontWeight.bold),
        headlineSmall: GoogleFonts.lato(textStyle: textTheme.headlineSmall, color: const Color(0xff3b4948), fontWeight: FontWeight.bold),
        displayLarge: GoogleFonts.vollkorn(textStyle: textTheme.displayLarge, color: const Color(0xff3b4948), fontWeight: FontWeight.w400),
        displayMedium: GoogleFonts.vollkorn(textStyle: textTheme.displayMedium, color: const Color(0xff3b4948), fontWeight: FontWeight.w400),
        displaySmall: GoogleFonts.vollkorn(textStyle: textTheme.displaySmall, color: const Color(0xff3b4948), fontWeight: FontWeight.w400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}



class MyGlobals {
  static final AutoScrollController scrollController = AutoScrollController();
  static const shimmerGradient = LinearGradient(
    colors: [
      Color(0xFFEBEBF4),
      Color(0xFFF4F4F4),
      Color(0xFFEBEBF4),
    ],
    stops: [
      0.1,
      0.3,
      0.4,
    ],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
    tileMode: TileMode.clamp,
  );
}

class SnackBarService {
  static final scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  static void showSnackBar({required String content}) {
    scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(content)));
  }
}

