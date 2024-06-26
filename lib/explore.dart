import 'package:google_sign_in/google_sign_in.dart';
import 'package:tourguide_app/debugScreen.dart';
import 'package:tourguide_app/signIn.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/utilities/locationProvider.dart';
import 'main.dart';
import 'package:tourguide_app/utilities/authProvider.dart' as myAuth;


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

    //Firebase auth
    FirebaseAuth.instance
        .userChanges()
        .listen((User? user) {
      if (user == null) {
        print('FIREBASE AUTH (EXPLORE) - User is currently signed out!');
      } else {
        print('FIREBASE AUTH (EXPLORE) - User is signed in!');
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
      body: Center(
          child: Container(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: FutureBuilder(
                    future: _handleSignIn(),
                      builder: (context, snapshot) {
                      return ListTile(
                        leading: GoogleUserCircleAvatar(
                          identity: authProvider.user!,
                        ),
                        title: Text(authProvider.user!.displayName ?? ''),
                        subtitle: Text(authProvider.user!.email),
                      );
                    }
                  ),
                ),
                /*
                FutureBuilder<String>(
                  future: locationProvider.getCurrentLocation(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator(); // Show a loading indicator
                    } else if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    } else if (snapshot.hasData) {
                      return Text(snapshot.data!); // Display the fetched text
                    } else {
                      return Text('No data found');
                    }
                  },
                ),*/
                Text("Welcome to ${locationProvider.currentCity}"),
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
                ),
              ],
            ),
          ),
      ),
    );
  }
}