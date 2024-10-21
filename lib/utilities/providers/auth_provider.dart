import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/utilities/tourguide_navigation.dart';
import 'package:universal_html/js_util.dart';

const List<String> scopes = <String>[
  'email',
];
GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: scopes,
);

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
  User? _user; //firebase user
  GoogleSignInAccount? _googleSignInUser;
  late StreamSubscription _userAuthSub;
  bool _isAuthorized = false;
  bool _isLoggingOut = false;
  bool _silentSignInFailed = false;
  bool _isLoggingIntoFirebaseMobile = false;
  bool _isAnonymous = false;
  bool _isLoggingInAnonymously = false;
  bool _isSilentWebSignInProcessing = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // PUBLIC //
  /// Firebase User
  User? get user => _user;

  /// Google Sign In User
  GoogleSignInAccount? get googleSignInUser => _googleSignInUser;
  bool get isAuthorized => _isAuthorized;
  bool get isLoggingOut => _isLoggingOut;
  bool get silentSignInFailed => _silentSignInFailed;
  bool get isAnonymous => _isAnonymous;
  bool get isLoggingIntoFirebaseMobile => _isLoggingIntoFirebaseMobile;
  bool get isLoggingInAnonymously => _isLoggingInAnonymously;
  bool get isSilentWebSignInProcessing => _isSilentWebSignInProcessing;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    logger.t("AuthProvider._init()");
    _googleSignIn.onCurrentUserChanged
        .listen((GoogleSignInAccount? account) async {
      // In mobile, being authenticated means being authorized...
      bool isAuthorized = account != null;
      // However, on web...
      if (kIsWeb && account != null) {
        isAuthorized = await _googleSignIn.canAccessScopes(scopes);
        logger.t(
            'AuthProvider.AuthProvider() - _googleSignIn.onCurrentUserChanged (web) -> account is null=${account == null}, isAuthorized=$isAuthorized');
      }

      _googleSignInUser = account;
      _isAuthorized = isAuthorized;
      _isAnonymous = _isAuthorized;
      logger.t(
          "AuthProvider._googleSignIn.onCurrentUserChanged -> isAuthorized=${_isAuthorized}, _googleSignInUser=$_googleSignInUser, _user=$_user");
      notifyListeners();

      //sign in with Firebase if authorized (on web the user has to press the button)
      if (_isAuthorized && !kIsWeb) {
        _isLoggingIntoFirebaseMobile = true;
        await signInWithFirebase(account!);
      }
    });

    //Listen to Firebase auth changes. Only used here to help log returning web users back in
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        logger.i('User is currently signed out!');
      } else {
        logger.i('User is signed in! userId=${user.uid}');
        if (kIsWeb &&
            _googleSignInUser == null &&
            !isAnonymous &&
            !_isLoggingInAnonymously) {
          _user = user;
          _isSilentWebSignInProcessing = true;
          logger.t('AuthProvider._init() - _googleSignIn.signInSilently()');
          _googleSignIn.signInSilently().then((GoogleSignInAccount? account) {
            _handleSilentGoogleSignInWeb(account);
          });
        }
      }
    });

    // In the web, _googleSignIn.signInSilently() triggers the One Tap UX.
    //
    // It is recommended by Google Identity Services to render both the One Tap UX
    // and the Google Sign In button together to "reduce friction and improve
    // sign-in rates" ([docs](https://developers.google.com/identity/gsi/web/guides/display-button#html)).
    if (!kIsWeb) _signInSilently();
    // TODO - check for fixes to the google_sign_in package. This code is an example taken from the example application linked there.
    // TODO - however, it does not work as intended. The signInSilently() method triggers an error with FedCM / GIS on web.
    // TODO - it seems like it's no longer best practice to use this method on web.
  }

  /// Specifically for the case where we had duplicate accounts created on the web
  /// https://trello.com/c/iQPPJtW2/92-duplicate-user-accounts
  Future<void> _handleSilentGoogleSignInWeb(
      GoogleSignInAccount? account) async {
    _googleSignInUser = account;
    _isAuthorized = account != null;

    logger.t(
        '_handleSilentGoogleSignInWeb() - _googleSignInUser=$account, _isAuthorized=$_isAuthorized');

    if (_isAuthorized) {
      logger.i('Trying to link with credential');
      GoogleSignInAuthentication googleAuth = await account!.authentication;
      AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      try {
        logger.i(
            'before credential linking _auth.currentUser?.uid=${_auth.currentUser?.uid}, '
            '_auth.currentUser?.isAnonymous=${_auth.currentUser?.isAnonymous}'
            'GoogleSignInAccount param account.id=${account.id}');
        final userCredential = await FirebaseAuth.instance.currentUser
            ?.linkWithCredential(credential);
        logger.i(
            'after credential linking userId=${userCredential?.user?.uid}, firebaseAuthId=${_auth.currentUser?.uid}');
      } on FirebaseAuthException catch (e) {
        switch (e.code) {
          case "provider-already-linked":
            logger.e("The provider has already been linked to the user.");
            break;
          case "invalid-credential":
            logger.e("The provider's credential is not valid.");
            break;
          case "credential-already-in-use":
            logger.e(
                "The account corresponding to the credential already exists, "
                "or is already linked to a Firebase User.");
            await _auth.signInWithCredential(credential);
            logger.i(
                'after _auth.signInWithCredential: _auth.currentUser?.uid=${_auth.currentUser?.uid}, '
                '_auth.currentUser?.isAnonymous=${_auth.currentUser?.isAnonymous}'
                'GoogleSignInAccount param account.id=${account.id}');
            break;
          // See the API reference for the full list of error codes.
          default:
            logger.e("Unknown error.");
        }
      }
      logger.t('_handleSilentGoogleSignInWeb() - Done');
    }
    _isSilentWebSignInProcessing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    logger.t('AuthProvider.dispose()');
    if (_userAuthSub != null) {
      _userAuthSub.cancel();
    }
    super.dispose();
  }

  void _signInSilently() async {
    GoogleSignInAccount? silentlySignedInUser =
        await _googleSignIn.signInSilently();
    logger.t(
        'AuthProvider.signInSilently() - silentlySignedInUser=$silentlySignedInUser');
    if (silentlySignedInUser == null) {
      _silentSignInFailed = true;
      notifyListeners();
    }
  }

  // This is the on-click handler for the Sign In button that is rendered by Flutter.
  //
  // On the web, the on-click handler of the Sign In button is owned by the JS
  // SDK, so this method can be considered mobile only.
  // #docregion SignIn
  Future<void> handleSignIn() async {
    logger.t('AuthProvider.handleSignIn()');
    try {
      GoogleSignInAccount? googleSignInAccount = await _googleSignIn.signIn();
      logger.t(
          'AuthProvider.handleSignIn() - googleSignInAccount=$googleSignInAccount');
    } catch (error) {
      print(error);
    }
  }
  // #enddocregion SignIn

  // Called when the current auth user changes (google sign in), so we automatically log into Firebase as well.
  // This is seperate form the google sign in / authorization worfklow and just for access to firebase.
  Future<void> signInWithFirebase(GoogleSignInAccount account) async {
    logger.t('AuthProvider.signInWithFirebase()');
    try {
      GoogleSignInAuthentication googleAuth = await account.authentication;
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential authResult = kIsWeb
          ? await _auth.signInWithPopup(googleProvider)
          : await _auth.signInWithCredential(credential);

      // Access the logged-in user using FirebaseAuth.instance.currentUser
      _user = authResult.user;
      if (_user != null) {
        _isAnonymous = false;
      }
      _isLoggingIntoFirebaseMobile = false;
      _isSilentWebSignInProcessing = false;
      notifyListeners();
      logger.t(
          'AuthProvider.signInWithFirebase() - Firebase User Info: ${_user?.displayName}, ${_user?.email}');
    } catch (error) {
      _isLoggingIntoFirebaseMobile = false;
      notifyListeners();
      logger.e(
          'AuthProvider.signInWithFirebase() - Error signing in with Firebase: $error');
    }
  }

  Future<void> signInWithFirebaseAnonymously() async {
    logger.t('AuthProvider.signInWithFirebaseAnonymously()');
    try {
      _isLoggingInAnonymously = true;
      notifyListeners();
      UserCredential authResult = await _auth.signInAnonymously();

      // Access the logged-in user using FirebaseAuth.instance.currentUser
      _user = authResult.user;
      _isAnonymous = true;
      _isLoggingInAnonymously = false;
      _isSilentWebSignInProcessing = false;
      notifyListeners();
      logger.t(
          'AuthProvider.signInWithFirebase() - Firebase User Info: ${_user?.displayName}, ${_user?.email}');
    } catch (error) {
      _isLoggingInAnonymously = false;
      notifyListeners();
      logger.e(
          'AuthProvider.signInWithFirebase() - Error signing in with Firebase: $error');
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
      if (_googleSignInUser != null) await _googleSignIn.disconnect();
      _user = null;
      _googleSignInUser = null;
      _isAuthorized = false;
      _silentSignInFailed = false;
      _isLoggingOut = false;
      _isSilentWebSignInProcessing = false;
      notifyListeners();
      //SnackBarService.showSnackBar(content: 'You\'re signed out!');
      logger.t('AuthProvider.signOut() - User signed out.');
    } catch (e) {
      logger.e(e);
      _isLoggingOut = false;
    }
  }

  //TODO - merge with signOut()?
  void deleteUser() {
    if (_googleSignInUser != null) _googleSignIn.disconnect();
    _user = null;
    _googleSignInUser = null;
    _isAuthorized = false;
    _silentSignInFailed = false;
    _isLoggingOut = false;
    _isLoggingIntoFirebaseMobile = false;
    _isAnonymous = false;
    _isLoggingInAnonymously = false;
    _isSilentWebSignInProcessing = false;
    notifyListeners();
  }
}
