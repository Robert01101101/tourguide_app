import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tourguide_app/testing/debug_screen.dart';
import 'package:tourguide_app/signIn.dart';
import 'package:tourguide_app/ui/google_places_image.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'main.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'dart:ui' as ui;


// #docregion Initialize
const List<String> scopes = <String>[
  'email',
  //'https://www.googleapis.com/auth/contacts.readonly',  //CONTACT DEMO - for demo of using people API to get contacts etc
];

GoogleSignIn _googleSignIn = GoogleSignIn(
  // Optional clientId
  // clientId: 'your-client_id.apps.googleusercontent.com',
  scopes: scopes,
);



//because I update the login status dynamically, the Explore screen needs to be a stateful widget (from Chat GPT)
class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  State<Explore> createState() => ExploreState();
}

class ExploreState extends State<Explore> {
  GoogleSignInAccount? _currentUser;

  @override
  void initState() {
    print('ExploreState.initState() !!!!!!!!!!!!!!!!!!!!');

    //Firebase auth
    FirebaseAuth.instance
        .userChanges()
        .listen((User? user) {
      if (user == null) {
        print('ExploreState.initState() - FirabaseAuth listen - FIREBASE AUTH (EXPLORE) - User is currently signed out!');
      } else {
        print('ExploreState.initState() - FirabaseAuth listen - FIREBASE AUTH (EXPLORE) - User is signed in!');
        FlutterNativeSplash.remove();
      }
    });

    super.initState();
  }


  //TODO: fix bad code
  Future<GoogleSignInAccount> _handleSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser == null) print("USER IS SIGNED OUT WHEN THEY SHOULDN'T BE!");
      return _currentUser!;
    } catch (error) {
      // Handle sign-in errors
      print("Error during Google Sign-In: $error");
      return _currentUser!;
    }
  }


  @override
  Widget build(BuildContext context) {
    myAuth.AuthProvider authProvider = Provider.of(context);
    LocationProvider locationProvider = Provider.of<LocationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
      ),
      body: Stack(
        children: [
          Consumer<LocationProvider>(
            builder: (context, locationProvider, child) {
              return FutureBuilder<GooglePlacesImg?>(
                future: locationProvider.fetchPlacePhoto(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (snapshot.hasData && snapshot.data != null) {
                    final googlePlacesImg = snapshot.data!;
                    //return googlePlacesImg;

                    return ShaderMask(
                      shaderCallback: (rect) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Colors.black45],
                        ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                      },
                      blendMode: BlendMode.multiply,
                      child: googlePlacesImg
                    );
                  } else {
                    return const Text('No photo available');
                  }
                },
              );
            },
          ),
          StandardLayout(
              children: [
                FutureBuilder(
                future: _handleSignIn(),
                builder: (context, snapshot) {
                  //Assemble welcome string
                  String title = "Welcome";
                  if (locationProvider.currentCity != null) title += " to ${locationProvider.currentCity}";
                  String displayName = authProvider.user!.displayName!;
                  if (displayName != null && displayName.isNotEmpty) title += ", ${displayName.split(' ').first}";

                  //Stylized Welcome Banner
                  return SizedBox(
                    height: 320,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 0),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: GradientText(
                            title,
                            style: Theme.of(context).textTheme.displayMedium,
                            gradient: const LinearGradient(colors: [
                              Color(0xffe8f3f3),
                              Color(0xffbdf3f0),
                            ]),
                          ),
                      ),
                    ),
                  );
                }
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DebugScreen()),
                  );
                },
                child: const Text('Debug Screen'),
              ),
              //Text('User is signed in!!  :)\n\nUsername: ${FirebaseAuth.instance.currentUser!.displayName}\nEmail: ${FirebaseAuth.instance.currentUser!.email}'),
              ElevatedButton(
                onPressed: authProvider.signOut,
                child: const Text('Sign Out'),
              ),]
          ),
        ],
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  const GradientText(
      this.text, {
        required this.gradient,
        this.style,
      });

  final String text;
  final TextStyle? style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}