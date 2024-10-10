// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert' show json;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ui/sign_in_button.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart'
    as my_auth;
import 'package:flutter_native_splash/flutter_native_splash.dart';

/// The SignIn app.
class SignIn extends StatefulWidget {
  ///
  const SignIn({super.key});

  @override
  State createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  GoogleSignInAccount? _currentUser;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool navigatedAwayFromSignIn = false;
  bool _guestSignInFormStep = false;
  final _guestFormKey = GlobalKey<FormState>();
  final _guestNameController = TextEditingController();
  final _guestEmailController = TextEditingController();
  final _guestCompanyController = TextEditingController();
  bool _guestSignInStarted = false;

  @override
  void initState() {
    super.initState();

    logger.t("signIn.initState()");
    // Init providers
    MyGlobals.initProviders(context);
    my_auth.AuthProvider authProvider = Provider.of(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      authProvider.addListener(() {
        logger.t(
            "signIn.initState().authProviderListener -> user=${authProvider.user != null}, googleSignInUser=${authProvider.googleSignInUser != null}, isAuthorized=${authProvider.isAuthorized}, silentSignInFailed=${authProvider.silentSignInFailed}, isAnonymous=${authProvider.isAnonymous}");
        if (authProvider.user != null &&
            (authProvider.googleSignInUser != null ||
                authProvider.isAnonymous) &&
            !navigatedAwayFromSignIn) {
          _redirect();
        } else if (authProvider.googleSignInUser == null ||
            authProvider.silentSignInFailed) {
          logger.t(
              "signIn.initState().authProviderListener -> user is null or silentSignInFailed");
          FlutterNativeSplash.remove();
        }
      });

      if (kIsWeb) {
        logger.t("signIn.initState() kIsWeb -> remove splash");
        FlutterNativeSplash.remove();
      }
      //authProvider.signInSilently();
    });
  }

  Future<void> _redirect() async{
    my_auth.AuthProvider authProvider = Provider.of(context, listen: false);
    logger.t(
        "signIn.initState().authProviderListener -> user is no longer null -> _redirect()");
    navigatedAwayFromSignIn = true;
    MyGlobals.userSignedIn = true; //for web
    // Navigate to the new screen once login is complete
    if (await _checkIfFirstTimeUserAfterAccountDeletion()) return;
    TourguideNavigation.router.go(
      MyGlobals.signInReroutePath ?? TourguideNavigation.explorePath,
    );
    //anonymous login is handled in _signInGuest()
    if (!authProvider.isAnonymous)
      FirebaseAnalytics.instance.logLogin(loginMethod: 'google');
  }

  Future<bool> _checkIfFirstTimeUserAfterAccountDeletion() async {
    var prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('firstTimeUser') == null) {
      logger.i('_checkIfFirstTimeUserAfterAccountDeletion -> true');
      TourguideNavigation.router.go(
        TourguideNavigation.onboardingPath,
      );
      return true;
    }
    return false;
  }

  Future<void> _signInGuest() async {
    if (_guestSignInStarted) return;
    _guestSignInStarted = true;
    my_auth.AuthProvider authProvider = Provider.of(context, listen: false);
    if (_guestFormKey.currentState!.validate()) {
      _guestFormKey.currentState!.save();
      logger.t(
          "signIn._signInGuest() -> name=${_guestNameController.text}, email=${_guestEmailController.text}, company=${_guestCompanyController.text}");
      //log to analytics
      FirebaseAnalytics.instance.logLogin(
        loginMethod: 'guest',
        parameters: <String, Object>{
          'name': _guestNameController.text,
          'email': _guestEmailController.text,
          'company': _guestCompanyController.text,
        },
      );
      //log to firestore (easier to view than GA)
      String identifier = _guestEmailController.text.isNotEmpty
          ? _guestEmailController.text
          : _guestNameController.text.isNotEmpty
              ? _guestNameController.text
              : _guestCompanyController.text;
      if (identifier.isNotEmpty) {
        identifier = safeIdentifierForFirestore(identifier);
        DocumentReference docRef = FirebaseFirestore.instance
            .collection('guests')
            .doc(safeIdentifierForFirestore(_guestEmailController.text));

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Try to get snapshot of existing guest doc
          DocumentSnapshot snapshot = await transaction.get(docRef);

          // If the document exists, update the count, otherwise set it to 1
          if (snapshot.exists) {
            // Get the current count value and increment it
            Map<String, dynamic>? data =
                snapshot.data() as Map<String, dynamic>?;
            int currentCount = data?['count'] ?? 0;
            transaction.update(docRef, {
              'name': _guestNameController.text,
              'email': _guestEmailController.text,
              'company': _guestCompanyController.text,
              'timestamp': FieldValue.serverTimestamp(),
              'count': currentCount + 1,
            });
          } else {
            // If the document doesn't exist, create it with a count of 1
            transaction.set(docRef, {
              'name': _guestNameController.text,
              'email': _guestEmailController.text,
              'company': _guestCompanyController.text,
              'timestamp': FieldValue.serverTimestamp(),
              'count': 1,
            });
          }
        });
      }
      _guestSignInFormStep = false;
      await authProvider.signInWithFirebaseAnonymously();
    }
  }

  String safeIdentifierForFirestore(String email) {
    // Replace unsafe characters with valid ones
    return email
        .replaceAll('.', 'DOT') // Replace '.' with '_'
        .replaceAll('#', 'HASHTAG')
        .replaceAll('\$', 'DOLLARSIGN')
        .replaceAll('[', 'SQBRACKETOPEN')
        .replaceAll(']', 'SQBRACKETCLOSE')
        .replaceAll('/', 'SLASH');
  }

  Widget _buildProcessingBody() {
    my_auth.AuthProvider authProvider = Provider.of(context);

    return Center(
      child: SizedBox(
        height: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const CircularProgressIndicator(
              semanticsLabel: 'Circular progress indicator',
            ),
            const SizedBox(
              height: 20,
            ),
            if (!authProvider.isLoggingOut) ...<Widget>[
              const Text('Signed in successfully.\nConnecting to servers...'),
            ],
            if (authProvider.isLoggingOut) ...<Widget>[
              const Text('Signing Out...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildButtonBody() {
    my_auth.AuthProvider authProvider = Provider.of(context);
    final GoogleSignInAccount? googleSignInAccount =
        authProvider.googleSignInUser;
    final User? user = authProvider.user;

    if (googleSignInAccount != null && user == null) {
      // The user is Authenticated and authorized, but not signed into firebase
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 0),
            const SizedBox(
                width: 240,
                child: Text('Sign into Tourguide with your Google account.',
                    textAlign: TextAlign.center)),
            ElevatedButton(
              onPressed: () => authProvider
                  .signInWithFirebase(authProvider.googleSignInUser!),
              child: const Text('SIGN INTO TOURGUIDE'),
            ),
          ],
        ),
      );
    } else if (!_guestSignInFormStep) {
      // The user is NOT Authenticated
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const SizedBox(height: 0),
            SizedBox(
              width: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('You are signed out.',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  Text(
                      'To continue, please sign in or create an account with Google.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            // This method is used to separate mobile from web code with conditional exports.
            // See: src/sign_in_button.dart
            Column(
              children: [
                buildSignInButton(
                  onPressed: authProvider.handleSignIn,
                ),
                const SizedBox(height: StandardLayout.defaultGap),
                TextButton(
                    onPressed: () {
                      setState(() {
                        _guestSignInFormStep = true;
                      });
                    },
                    //() =>
                    //authProvider.signInWithFirebaseAnonymously(),
                    child: Text('SIGN IN AS GUEST',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium!
                            .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold))),
              ],
            ),
          ],
        ),
      );
    } else {
      // The user is trying to sign in as guest, try to get more information about them
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const SizedBox(height: 0),
            SizedBox(
              width: min(MediaQuery.of(context).size.width - 48, 320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Guest Sign In',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  Text(
                      'In order to better understand who uses Tourguide, we would like to learn a little bit more about you. \n\nThis step is optional.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            SizedBox(
              width: min(MediaQuery.of(context).size.width - 48, 320),
              child: Form(
                  key: _guestFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _guestNameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                        ),
                        onChanged: (value) {
                          //authProvider.guestName = value;
                        },
                      ),
                      TextFormField(
                        controller: _guestEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                        ),
                        onChanged: (value) {
                          //authProvider.guestEmail = value;
                        },
                      ),
                      TextFormField(
                        controller: _guestCompanyController,
                        decoration: const InputDecoration(
                          labelText: 'Company',
                        ),
                        onChanged: (value) {
                          //authProvider.guestEmail = value;
                        },
                      ),
                    ],
                  )),
            ),
            // This method is used to separate mobile from web code with conditional exports.
            // See: src/sign_in_button.dart
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                    onPressed: () {
                      setState(() {
                        _guestSignInFormStep = false;
                      });
                    },
                    //() =>
                    //authProvider.signInWithFirebaseAnonymously(),
                    child: Text('CANCEL',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium!
                            .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold))),
                const SizedBox(width: StandardLayout.defaultGap),
                TextButton(
                    onPressed: _signInGuest,
                    child: Text('SIGN IN AS GUEST',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium!
                            .copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold))),
              ],
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    my_auth.AuthProvider authProvider = Provider.of(context);

    // logger.i("signIn.build() -> user=${authProvider.user != null}, googleSignInUser=${authProvider.googleSignInUser != null}, "
    //     "isAuthorized=${authProvider.isAuthorized}, silentSignInFailed=${authProvider.silentSignInFailed}, \n"
    //     "isAnonymous=${authProvider.isAnonymous}, isLoggingOut=${authProvider.isLoggingOut}, "
    //     "isLoggingIntoFirebaseMobile=${authProvider.isLoggingIntoFirebaseMobile}, isLoggingInAnonymously=${authProvider.isLoggingInAnonymously}");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourguide'),
        centerTitle: true,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight, // Take at least the full screen height
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      //set minHeight to
                      minHeight: 150,
                      maxHeight: constraints.maxHeight * 0.7, // Optional: Limit the maximum height to the screen height
                    ),
                    child: ((authProvider.googleSignInUser != null &&
                                authProvider.isAuthorized &&
                                authProvider.user != null) ||
                            authProvider.isLoggingOut ||
                            authProvider.isLoggingIntoFirebaseMobile ||
                            authProvider.isLoggingInAnonymously)
                        ? _buildProcessingBody()
                        : _buildButtonBody(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        children: [
                          const TextSpan(
                              text: 'By signing in, you agree to the \n'),
                          TextSpan(
                            text: 'Terms of Service',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                    decoration: TextDecoration.underline,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                launchUrl(Uri.parse(
                                    "https://tourguide.rmichels.com/termsOfService.html"));
                              },
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                    decoration: TextDecoration.underline,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                launchUrl(Uri.parse(
                                    "https://tourguide.rmichels.com/privacyPolicy.html"));
                              },
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
