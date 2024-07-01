import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/utilities/tourguide_navigation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const List<String> scopes = <String>[
  'email',
];

GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: scopes,
);

// AuthProvider handles login / logout, user auth state, and uses the provider
// package and change notifier to share information with the widget tree
//
// Written with help from https://medium.com/@JigneshWorld/how-to-implement-an-authentication-feature-using-a-provider-in-flutter-1f351447d09d
class AuthProvider with ChangeNotifier {
//#region REGION: AuthProvider fields and constructor
  ////// PUBLIC /////
  GoogleSignInAccount? user; //(formerly _currentUser)
  late StreamSubscription userAuthSub;
  bool isAuthorized = false; // has granted permissions?
  bool isLoggingOut = false;
  bool silentSignInFailed = false;

  ////// PRIVATE /////
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ////// CONSTRUCTOR /////
  AuthProvider() {
    userAuthSub = googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
      // Check Scopes: In mobile, being authenticated means being authorized...
      bool newIsAuthorized = account != null;
      // However, on web...
      if (kIsWeb && account != null) {
        logger.t('AuthProvider.AuthProvider() - _googleSignIn.onCurrentUserChanged (web) -> account is null=${account == null}');
        newIsAuthorized = await googleSignIn.canAccessScopes(scopes);
      }

      logger.t('AuthProvider.AuthProvider() - _googleSignIn.onCurrentUserChanged (web) setState() - newIsAuthorized=${newIsAuthorized}');
      user = account;
      isAuthorized = newIsAuthorized;
      notifyListeners();

      // Now that we know that the user can access the required scopes, the app  can call the REST API.
      if (newIsAuthorized) {
        await signInWithFirebase(account!); //from chatgpt

        //Go to main page
        /*CustomNavigationHelper.router.go(
          CustomNavigationHelper.explorePath,
        );*/
      } else {
        handleAuthorizeScopes();
      }
    });
  }

  @override
  void dispose() {
    if (userAuthSub != null) {
      userAuthSub.cancel();
    }
    super.dispose();
  }

  bool get isAuthenticated {
    return user != null;
  }
//#endregion

//#region REGION: Sign in / out methods
  void signInSilently() async {
    logger.t('AuthProvider.signInSilently()');
    GoogleSignInAccount? silentlySignedInUser = await googleSignIn.signInSilently();
    logger.t('AuthProvider.signInSilently() - silentlySignedInUser=$silentlySignedInUser');
    if (silentlySignedInUser == null) {
      silentSignInFailed = true;
      notifyListeners();
    }
  }

  // Called when the current auth user changes (google sign in), so we automatically log into Firebase as well
  Future<void> signInWithFirebase(GoogleSignInAccount account) async {
    logger.t('AuthProvider.signInWithFirebase()');
    try {
      GoogleSignInAuthentication googleAuth = await account.authentication;
      AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential authResult = await _auth.signInWithCredential(credential);

      // Access the logged-in user using FirebaseAuth.instance.currentUser
      User? firebaseUser = authResult.user;
      logger.t('AuthProvider.signInWithFirebase() - Firebase User Info: ${firebaseUser?.displayName}, ${firebaseUser?.email}');
    } catch (error) {
      logger.e('AuthProvider.signInWithFirebase() - Error signing in with Firebase: $error');
    }
  }


  // This is the on-click handler for the Sign In button that is rendered by Flutter.
  //
  // On the web, the on-click handler of the Sign In button is owned by the JS
  // SDK, so this method can be considered mobile only. - is this still true? not sure - > TODO: verify description
  // #docregion SignIn
  Future<void> handleSignIn() async {
    logger.t('AuthProvider.handleSignIn()');
    try {
      GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();

      logger.t('AuthProvider.handleSignIn() - 1 googleSignInAccount is null=${googleSignInAccount == null}');
      if (googleSignInAccount != null) {
        logger.t('AuthProvider.handleSignIn() - 2 start await');
        GoogleSignInAuthentication googleAuth = await googleSignInAccount.authentication;
        logger.t('AuthProvider.handleSignIn() - 3 finished await');
        AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        logger.t('AuthProvider.handleSignIn() - 4 sign in');
        // Sign in with Firebase using the obtained credentials
        UserCredential authResult = await _auth.signInWithCredential(credential);

        logger.t('AuthProvider.handleSignIn() - 5 access');
        // Access the logged-in user using FirebaseAuth.instance.currentUser
        User? firebaseUser = authResult.user;
        logger.t('AuthProvider.handleSignIn() -- SUCCESS! -- Firebase User Info: ${firebaseUser?.displayName}, ${firebaseUser?.email}');

        user = googleSignInAccount;
        isAuthorized = true;
        //Show success message
        SnackBarService.showSnackBar(content: 'You\'re signed in!');
        notifyListeners();
      }
    } catch (error) {
      logger.t(error);
    }
  }


  // Prompts the user to authorize `scopes`.
  //
  // This action is **required** in platforms that don't perform Authentication
  // and Authorization at the same time (like the web).
  //
  // On the web, this must be called from an user interaction (button click).
  Future<void> handleAuthorizeScopes() async {
    logger.t('AuthProvider.handleAuthorizeScopes()');
    final bool newIsAuthorized = await googleSignIn.requestScopes(scopes);
    isAuthorized = newIsAuthorized;
    notifyListeners();


    if (newIsAuthorized) {
      await signInWithFirebase(user!); //from chatgpt
    }
  }

  // Sign user out and go back to login page
  void signOut() async {
    try {
      isLoggingOut = true;
      logger.t('AuthProvider.signOut()');
      //Go to login page
      TourguideNavigation.router.go(
        TourguideNavigation.signInPath,
      );
      await FirebaseAuth.instance.signOut();
      await googleSignIn.disconnect();
      SnackBarService.showSnackBar(content: 'You\'re signed out!');
      isLoggingOut = false;
    } catch (e){
      logger.t(e);
      isLoggingOut = false;
    }

  }
//#endregion
}