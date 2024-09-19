// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert' show json;
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
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
          logger.t(
              "signIn.initState().authProviderListener -> user is no longer null");
          navigatedAwayFromSignIn = true;
          MyGlobals.userSignedIn = true; //for web
          // Navigate to the new screen once login is complete
          TourguideNavigation.router.go(
            MyGlobals.signInReroutePath ?? TourguideNavigation.explorePath,
          );
          FirebaseAnalytics.instance.logLogin(loginMethod: 'google');
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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const SizedBox(
                width: 240,
                child: Text(
                    'Sign into the Google Firebase Cloud service for access to Tourguide.',
                    textAlign: TextAlign.center)),
            ElevatedButton(
              onPressed: () => authProvider
                  .signInWithFirebase(authProvider.googleSignInUser!),
              child: const Text('SIGN INTO FIREBASE SERVICE'),
            ),
          ],
        ),
      );
    } else {
      // The user is NOT Authenticated
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
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
                    onPressed: () =>
                        authProvider.signInWithFirebaseAnonymously(),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourguide'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints.expand(),
                child: ((authProvider.googleSignInUser != null &&
                            authProvider.isAuthorized &&
                            authProvider.user != null) ||
                        authProvider.isLoggingOut ||
                        authProvider.isLoggingIntoFirebaseMobile)
                    ? _buildProcessingBody()
                    : _buildButtonBody(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  children: [
                    const TextSpan(text: 'By signing in, you agree to the \n'),
                    TextSpan(
                      text: 'Terms of Service',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          decoration: TextDecoration.underline,
                          color: Theme.of(context).colorScheme.primary),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          launchUrl(Uri.parse(
                              "https://tourguide.rmichels.com/termsOfService.html"));
                        },
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          decoration: TextDecoration.underline,
                          color: Theme.of(context).colorScheme.primary),
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
    );
  }
}
