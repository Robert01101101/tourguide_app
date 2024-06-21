import 'package:provider/provider.dart';
import 'package:tourguide_app/utilities/authProvider.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_sign_in/google_sign_in.dart';


void main() async {
  //ROUTING
  CustomNavigationHelper.instance;

  //FIREBASE INIT
  //https://stackoverflow.com/a/63537567/7907510
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  //FIREBASE AUTH
  /*
  FirebaseAuth.instance
      .userChanges()
      .listen((User? user) {
    if (user == null) {
      print('User is currently signed out!');
    } else {
      print('User is signed in!');
    }
  });*/

  runApp(const MyApp());
}




class MyApp extends StatelessWidget {
  const MyApp({super.key});


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider())
      ],
      child: MaterialApp.router(
        scaffoldMessengerKey: SnackBarService.scaffoldKey,
        title: 'Tourguide App',
        routerConfig: CustomNavigationHelper.router,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
          useMaterial3: true,
        ),
      ),
    );
  }
}




class MyGlobals {
  static final ScrollController scrollController = ScrollController();
  static final String googleMapsApiKey = "AIzaSyBa7mCp1FUiWMhfTHPWNJ2Cy-A84w4i2I4";
}

class SnackBarService {
  static final scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  static void showSnackBar({required String content}) {
    scaffoldKey.currentState?.showSnackBar(SnackBar(content: Text(content)));
  }
}