import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/utilities/tourguide_navigation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const List<String> scopes = <String>['email',];
GoogleSignIn googleSignIn = GoogleSignIn(scopes: scopes,);

// AuthProvider handles login / logout, user auth state, and uses the provider
// package and change notifier to share information with the widget tree
//
// Written with help from https://medium.com/@JigneshWorld/how-to-implement-an-authentication-feature-using-a-provider-in-flutter-1f351447d09d
//
/// Uses Firebase Auth, which supports multiple auth providers including Google Sign In, the only one supported for now.
/// The User Id used is the Firebase Auth Id (User is a Firebase Auth class).
/// Google Sign In user is used for name, picture, profile purposes.
class AuthProvider with ChangeNotifier {
//#region REGION: AuthProvider fields and constructor
  User? _user;
  GoogleSignInAccount? _googleSignInUser;
  late StreamSubscription _userAuthSub;
  bool _isAuthorized = false;
  bool _isLoggingOut = false;
  bool _silentSignInFailed = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ////// PUBLIC /////
  User? get user => _user;
  GoogleSignInAccount? get googleSignInUser => _googleSignInUser;
  bool get isAuthorized => _isAuthorized;
  bool get isLoggingOut => _isLoggingOut;
  bool get silentSignInFailed => _silentSignInFailed;


  AuthProvider() {
    _init();
  }

  // Initialization method
  Future<void> _init() async {
    logger.t("AuthProvider._init()");
    _userAuthSub = googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
      // Check Scopes: In mobile, being authenticated means being authorized...
      bool newIsAuthorized = account != null;
      // However, on web...
      if (kIsWeb && account != null) {
        logger.t('AuthProvider.AuthProvider() - _googleSignIn.onCurrentUserChanged (web) -> account is null=${account == null}');
        newIsAuthorized = await googleSignIn.canAccessScopes(scopes);
      }

      logger.t('AuthProvider.AuthProvider() - _googleSignIn.onCurrentUserChanged (web) setState() - newIsAuthorized=${newIsAuthorized}');
      _googleSignInUser = account;
      _isAuthorized = newIsAuthorized;
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
    signInSilently();
  }

  @override
  void dispose() {
    if (_userAuthSub != null) {
      _userAuthSub.cancel();
    }
    super.dispose();
  }

  bool get isAuthenticated {
    return _googleSignInUser != null;
  }
//#endregion

//#region REGION: Sign in / out methods
  void signInSilently() async {
    GoogleSignInAccount? silentlySignedInUser = await googleSignIn.signInSilently();
    logger.t('AuthProvider.signInSilently() - silentlySignedInUser=$silentlySignedInUser');
    if (silentlySignedInUser == null) {
      _silentSignInFailed = true;
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
      _user = authResult.user;
      notifyListeners();
      logger.t('AuthProvider.signInWithFirebase() - Firebase User Info: ${_user?.displayName}, ${_user?.email}');
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
        _user = authResult.user;
        logger.t('AuthProvider.handleSignIn() -- SUCCESS! -- Firebase User Info: ${_user?.displayName}, ${_user?.email}');

        _googleSignInUser = googleSignInAccount;
        _isAuthorized = true;
        //Show success message
        SnackBarService.showSnackBar(content: 'You\'re signed in!');
        notifyListeners();
      }
    } catch (error) {
      logger.e(error);
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
    _isAuthorized = newIsAuthorized;
    notifyListeners();


    if (newIsAuthorized) {
      await signInWithFirebase(_googleSignInUser!); //from chatgpt
    }
  }

  // Sign user out and go back to login page
  void signOut() async {
    try {
      _isLoggingOut = true;
      logger.t('AuthProvider.signOut()');
      //Go to login page
      TourguideNavigation.router.go(
        TourguideNavigation.signInPath,
      );
      await FirebaseAuth.instance.signOut();
      await googleSignIn.disconnect();
      _user = null;
      _googleSignInUser = null;
      _isAuthorized = false;
      _silentSignInFailed = false;
      _isLoggingOut = false;
      SnackBarService.showSnackBar(content: 'You\'re signed out!');
    } catch (e){
      logger.e(e);
      _isLoggingOut = false;
    }
  }

  void resetAuthProvider(){
    _user = null;
    _googleSignInUser = null;
    _isAuthorized = false;
    _silentSignInFailed = false;
    googleSignIn.disconnect();
  }
//#endregion
}