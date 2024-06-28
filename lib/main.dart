import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'firebase_options.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';


void main() async {
  //ROUTING
  TourguideNavigation.instance;

  //FIREBASE INIT
  //https://stackoverflow.com/a/63537567/7907510
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  //Splash
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(const MyApp());
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
    print("clearPrefsOnClose()");
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('chat_messages');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()..getCurrentLocation())
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
        displayLarge: GoogleFonts.vollkorn(textStyle: textTheme.displayLarge, color: const Color(0xff3b4948), fontWeight: FontWeight.w300),
        displayMedium: GoogleFonts.vollkorn(textStyle: textTheme.displayMedium, color: const Color(0xff3b4948), fontWeight: FontWeight.w300),
        displaySmall: GoogleFonts.vollkorn(textStyle: textTheme.displaySmall, color: const Color(0xff3b4948), fontWeight: FontWeight.w300),
      ),
    );
  }
}



class MyGlobals {
  static final AutoScrollController scrollController = AutoScrollController();
  static const String googleApiKey = "AIzaSyBa7mCp1FUiWMhfTHPWNJ2Cy-A84w4i2I4";
}

class SnackBarService {
  static final scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  static void showSnackBar({required String content}) {
    scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(content)));
  }
}