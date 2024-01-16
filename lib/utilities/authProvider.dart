import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

const List<String> scopes = <String>[
  'email',
  //'https://www.googleapis.com/auth/contacts.readonly',  //CONTACT DEMO - for demo of using people API to get contacts etc
];

GoogleSignIn googleSignIn = GoogleSignIn(
  // Optional clientId
  // clientId: 'your-client_id.apps.googleusercontent.com',
  scopes: scopes,
);

//with help from https://medium.com/@JigneshWorld/how-to-implement-an-authentication-feature-using-a-provider-in-flutter-1f351447d09d
class AuthProvider with ChangeNotifier {
  ////// PUBLIC /////
  GoogleSignInAccount? user; //(formerly _currentUser)
  late StreamSubscription userAuthSub;
  bool isAuthorized = false; // has granted permissions?

  ////// PRIVATE /////
  final FirebaseAuth _auth = FirebaseAuth.instance;



  AuthProvider() {
    /* //from Medium
    userAuthSub =   FirebaseAuth.instance.onAuthStateChanged.listen((newUser) {
      print('AuthProvider - FirebaseAuth - onAuthStateChanged - $newUser');
      //user = newUser; //TODO
      notifyListeners();
    }, onError: (e) {
      print('AuthProvider - FirebaseAuth - onAuthStateChanged - $e');
    });*/







    userAuthSub = googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
// #docregion CanAccessScopes
      // In mobile, being authenticated means being authorized...
      bool newIsAuthorized = account != null;
      // However, on web...
      if (kIsWeb && account != null) {
        print(' -- AuthProvider() - _googleSignIn.onCurrentUserChanged (web) -> account is null=${account == null}');
        newIsAuthorized = await googleSignIn.canAccessScopes(scopes);
      }
// #enddocregion CanAccessScopes

      print(' -- AuthProvider() - _googleSignIn.onCurrentUserChanged (web) setState() - newIsAuthorized=${newIsAuthorized}');
      user = account;
      notifyListeners();
      //MyGlobals.user = _currentUser;
      isAuthorized = newIsAuthorized;

      // Now that we know that the user can access the required scopes, the app
      // can call the REST API.
      if (newIsAuthorized) {
        //unawaited(_handleGetContact(account!)); //CONTACT DEMO
        await signInWithFirebase(account!); //from chatgpt
      } else {
        handleAuthorizeScopes();
      }
    });
  }

  @override
  void dispose() {
    if (userAuthSub != null) {
      userAuthSub.cancel();
      //userAuthSub = null; //old code? seems no longer valid
    }
    super.dispose();
  }

  /* //not needed? From Medium
  bool get isAnonymous {
    assert(user != null);
    bool isAnonymousUser = true;
    for (UserInfo info in user.providerData) {
      if (info.providerId == "facebook.com" ||
          info.providerId == "google.com" ||
          info.providerId == "password") {
        isAnonymousUser = false;
        break;
      }
    }
    return isAnonymousUser;
  }*/

  bool get isAuthenticated {
    return user != null;
  }

  /* //not needed? From Medium
  void signInAnonymously() {
    FirebaseAuth.instance.signInAnonymously();
  }*/

  void signOut() {
    FirebaseAuth.instance.signOut();
  }

  // Add the following function to sign in with Firebase
  Future<void> signInWithFirebase(GoogleSignInAccount account) async {
    try {
      GoogleSignInAuthentication googleAuth = await account.authentication;
      AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential authResult = await _auth.signInWithCredential(credential);

      // Access the logged-in user using FirebaseAuth.instance.currentUser
      User? firebaseUser = authResult.user;
      print('Firebase User Info: ${firebaseUser?.displayName}, ${firebaseUser?.email}');
    } catch (error) {
      print('Error signing in with Firebase: $error');
    }
  }




  // Prompts the user to authorize `scopes`.
  //
  // This action is **required** in platforms that don't perform Authentication
  // and Authorization at the same time (like the web).
  //
  // On the web, this must be called from an user interaction (button click).
  // #docregion RequestScopes
  Future<void> handleAuthorizeScopes() async {
    final bool newIsAuthorized = await googleSignIn.requestScopes(scopes);
    // #enddocregion RequestScopes
    isAuthorized = newIsAuthorized;
    notifyListeners();
    // #docregion RequestScopes
    if (newIsAuthorized) {
      //unawaited(_handleGetContact(_currentUser!)); //CONTACT DEMO
      //TODO: DO ON LOGIN
    }

    print('_handleAuthorizeScopes - newIsAuthorized=${newIsAuthorized}');
    if (newIsAuthorized) {
      //unawaited(_handleGetContact(account!)); //CONTACT DEMO
      await signInWithFirebase(user!); //from chatgpt
    }
    // #enddocregion RequestScopes
  }





  // This is the on-click handler for the Sign In button that is rendered by Flutter.
  //
  // On the web, the on-click handler of the Sign In button is owned by the JS
  // SDK, so this method can be considered mobile only.
  // #docregion SignIn
  Future<void> handleSignIn() async {
    print(' -- _handleSignIn()');
    try {
      GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();

      print(' -- _handleSignIn() - 1 googleSignInAccount is null=${googleSignInAccount == null}');
      if (googleSignInAccount != null) {
        print(' -- _handleSignIn() - 2 start await');
        GoogleSignInAuthentication googleAuth = await googleSignInAccount.authentication;
        print(' -- _handleSignIn() - 3 finished await');
        AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        print(' -- _handleSignIn() - 4 sign in');
        // Sign in with Firebase using the obtained credentials
        UserCredential authResult = await _auth.signInWithCredential(credential);

        print(' -- _handleSignIn() - 5 access');
        // Access the logged-in user using FirebaseAuth.instance.currentUser
        User? firebaseUser = authResult.user;
        print(' -- SUCCESS! -- Firebase User Info: ${firebaseUser?.displayName}, ${firebaseUser?.email}');

        user = googleSignInAccount;
        isAuthorized = true;
        notifyListeners();
      }
    } catch (error) {
      print(error);
    }
  }
}