import 'dart:core';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart' as logger_mobile;
import 'package:logger/logger.dart';
import 'package:logger/web.dart' as logger_web;
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/ui/tourguide_theme.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:tourguide_app/utilities/providers/theme_provider.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;

import 'model/tour.dart';
import 'model/tourguide_place.dart';
import 'model/tourguide_report.dart';

var logger = kIsWeb
    ? logger_web.Logger(level: logger_web.Level.all,)
                        //filter: ProductionFilter())
    : logger_mobile.Logger(level: logger_mobile.Level.all,);
                        //filter: ProductionFilter());
final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  //FIREBASE INIT
  //https://stackoverflow.com/a/63537567/7907510
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    // You can also use a `ReCaptchaEnterpriseProvider` provider instance as an
    // argument for `webProvider`
    webProvider: ReCaptchaV3Provider('6LdoBC4qAAAAACZhq3EQuE5vVR8e_7X_2EE67oUp'),
    // Default provider for Android is the Play Integrity provider. You can use the "AndroidProvider" enum to choose
    // your preferred provider. Choose from:
    // 1. Debug provider
    // 2. Safety Net provider
    // 3. Play Integrity provider
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    // Default provider for iOS/macOS is the Device Check provider. You can use the "AppleProvider" enum to choose
    // your preferred provider. Choose from:
    // 1. Debug provider
    // 2. Device Check provider
    // 3. App Attest provider
    // 4. App Attest provider with fallback to Device Check provider (App Attest provider is only available on iOS 14.0+, macOS 14.0+)
    appleProvider: AppleProvider.appAttest,
  );

  //LOAD ENVIRONMENT (SECURE VARS)
  await fetchConfig();

  //HIVE DB
  if (!kIsWeb){
    await Hive.initFlutter();
    Hive.registerAdapter(TourAdapter());
    Hive.registerAdapter(TourguidePlaceAdapter());
    Hive.registerAdapter(TourguideReportAdapter());
  }

  //ROUTING
  await TourguideNavigation.instance.initialize();

  //CRASHLYTICS
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  // Pass all uncaught "fatal" errors from the framework to Crashlytics (except for web, which doesn't support it)
  if (!kIsWeb){
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
        return MaterialApp.router(
          scaffoldMessengerKey: SnackBarService.scaffoldKey,
          title: 'Tourguide App',
          routerConfig: TourguideNavigation.router,
          theme: TourguideTheme.lightTheme,
          darkTheme: TourguideTheme.darkTheme,
          themeMode: themeProvider.themeMode,
        );
      }),
    );
  }
}



class MyGlobals {
  ///For web only, as I don't currently have a clean solution for users manually loading to a page other than the root //TODO: fix web routing
  static bool? userSignedIn;
  static String? signInReroutePath;
  static AutoScrollController? scrollController; //TODO fix
  static List<String> processedImageUrls = [];
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

  static void initProviders(BuildContext context){
    logger.t("initProviders()");
    myAuth.AuthProvider authProvider = Provider.of(context, listen: false);
    LocationProvider locationProvider = Provider.of(context, listen: false);
    TourProvider tourProvider = Provider.of(context, listen: false);
    TourguideUserProvider tourguideUserProvider = Provider.of(context, listen: false);
    ThemeProvider themeProvider = Provider.of(context, listen: false);
  }

  /// Returns true if we have to reroute to sign in.
  /// For web only, as I don't currently have a clean solution for users manually loading to a page other than the root.
  /// TODO: fix web routing, looks like it shouldn't be too much work as parts of the app work when loading right into a non-root page
  static bool webRoutingFix(String currentRoutePath){
    if (!kIsWeb) return false;
    if ((userSignedIn ?? false) == false){ //for web
      signInReroutePath = currentRoutePath;
      TourguideNavigation.router.go(
        TourguideNavigation.signInPath,
      );
      return true;
    } else {
      return false;
    }
  }
}

class SnackBarService {
  static final scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  static void showSnackBar({required String content}) {
    scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(content)));
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}