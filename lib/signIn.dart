import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tourguide_app/debugScreen.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


//from https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in/example/lib/main.dart
/// The scopes required by this application.
// #docregion Initialize
const List<String> scopes = <String>[
  'email',
];

GoogleSignIn _googleSignIn = GoogleSignIn(
  // Optional clientId
  // clientId: 'your-client_id.apps.googleusercontent.com',
  scopes: scopes,
);
// #enddocregion Initialize


Future<UserCredential> signInWithGoogle() async {
  // Trigger the authentication flow
  final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

  // Obtain the auth details from the request
  final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

  // Create a new credential
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth?.accessToken,
    idToken: googleAuth?.idToken,
  );

  // Sign in with the credential
  UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

  //Get Google Analytics to log login / signup events
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  // Check if it's the first time the user is signing up
  if (userCredential.additionalUserInfo?.isNewUser == true) {
    // Perform actions for a new user (e.g., store additional user data, send welcome emails, etc.)
    print("New user signed up with Google!");

    // Log signup event
    await analytics.logSignUp(signUpMethod: 'google');
  } else {
    // Perform actions for an existing user
    print("Existing user signed in with Google!");

    CustomNavigationHelper.router.go(
      CustomNavigationHelper.explorePath,
    );

    // Log login event
    await analytics.logLogin(loginMethod: 'google');
  }

  // Once signed in, return the UserCredential
  return userCredential;
}






//because I update the login status dynamically, the Explore screen needs to be a stateful widget (from Chat GPT)
class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => SignInState();
}

class SignInState extends State<SignIn> {
  String loginStatus = "no login status";
  GoogleSignInAccount? _currentUser;
  bool _isAuthorized = false; // has granted permissions?
  String _contactText = '';

  @override
  void initState() {
    super.initState();

    //FIREBASE AUTH

    FirebaseAuth.instance
        .userChanges()
        .listen((User? user) {
      if (user == null) {
        print('User is currently signed out :(');
        if (this.mounted) {
          setState(() {
            loginStatus = 'User is currently signed out :(';
          });
        }
        CustomNavigationHelper.router.go(
          CustomNavigationHelper.signInPath,
        );
      } else {
        print('User is signed in! :)');
        if (this.mounted) {
          setState(() {
            loginStatus = 'User is signed in! :)';
          });
        }
        CustomNavigationHelper.router.go(
          CustomNavigationHelper.explorePath,
        );
      }
    });

    _googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
      // In mobile, being authenticated means being authorized...
      bool isAuthorized = account != null;
      // However, on web...
      if (kIsWeb && account != null) {
        isAuthorized = await _googleSignIn.canAccessScopes(scopes);
      }

      setState(() {
        _currentUser = account;
        _isAuthorized = isAuthorized;
      });

      // Now that we know that the user can access the required scopes, the app
      // can call the REST API.
      if (isAuthorized) {
        unawaited(_handleGetContact(account!));
      }
    });

    // In the web, _googleSignIn.signInSilently() triggers the One Tap UX.
    //
    // It is recommended by Google Identity Services to render both the One Tap UX
    // and the Google Sign In button together to "reduce friction and improve
    // sign-in rates" ([docs](https://developers.google.com/identity/gsi/web/guides/display-button#html)).
    _googleSignIn.signInSilently();
  }

  // Calls the People API REST endpoint for the signed-in user to retrieve information.
  Future<void> _handleGetContact(GoogleSignInAccount user) async {
    print('handleGetContact');
  }

  // This is the on-click handler for the Sign In button that is rendered by Flutter.
  //
  // On the web, the on-click handler of the Sign In button is owned by the JS
  // SDK, so this method can be considered mobile only.
  // #docregion SignIn
  Future<void> _handleSignIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      print(error);
    }
  }
  // #enddocregion SignIn

  // Prompts the user to authorize `scopes`.
  //
  // This action is **required** in platforms that don't perform Authentication
  // and Authorization at the same time (like the web).
  //
  // On the web, this must be called from an user interaction (button click).
  // #docregion RequestScopes
  Future<void> _handleAuthorizeScopes() async {
    final bool isAuthorized = await _googleSignIn.requestScopes(scopes);
    // #enddocregion RequestScopes
    setState(() {
      _isAuthorized = isAuthorized;
    });
    // #docregion RequestScopes
    if (isAuthorized) {
      unawaited(_handleGetContact(_currentUser!));
    }
    // #enddocregion RequestScopes
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(loginStatus),
            ElevatedButton(
              onPressed: () {
                signInWithGoogle();
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}


Future<void> handleSignOut() {
  _googleSignIn.disconnect();
  return FirebaseAuth.instance.signOut();
}