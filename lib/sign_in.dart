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
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ui/sign_in_button.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as my_auth;
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

    // Init providers
    MyGlobals.initProviders(context);
    my_auth.AuthProvider authProvider = Provider.of(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      authProvider.addListener(() {
        logger.t("signIn.initState().authProviderListener -> user=${authProvider.user != null}, googleSignInUser=${authProvider.googleSignInUser != null}, isAuthorized=${authProvider.isAuthorized}, silentSignInFailed=${authProvider.silentSignInFailed}");
        if (authProvider.googleSignInUser != null && authProvider.user != null && !navigatedAwayFromSignIn) {
          logger.t("signIn.initState().authProviderListener -> user is no longer null");
          navigatedAwayFromSignIn = true;
          MyGlobals.userSignedIn = true; //for web
          // Navigate to the new screen once login is complete
          TourguideNavigation.router.go(
            MyGlobals.signInReroutePath ?? TourguideNavigation.explorePath,
          );
          FirebaseAnalytics.instance.logLogin(loginMethod:'google');
        } else if (authProvider.googleSignInUser == null || authProvider.silentSignInFailed){
          logger.t("signIn.initState().authProviderListener -> user is null or silentSignInFailed");
          FlutterNativeSplash.remove();
        }
      });

      if (kIsWeb){
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
    final GoogleSignInAccount? googleSignInAccount = authProvider.googleSignInUser;
    final User? user = authProvider.user;
    if (false && googleSignInAccount != null && !authProvider.isAuthorized && user == null) {
      // The user is Authenticated, but not authorized or signed into firebase
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            if (!authProvider.isAuthorized) ...<Widget>[
              // The user has NOT Authorized all required scopes.
              // (Mobile users may never see this button!)
              const Text('Additional permissions needed to authorize your account.'),
              ElevatedButton(
                onPressed: authProvider.handleAuthorizeScopes,
                child: const Text('REQUEST PERMISSIONS'),
              ),
            ],
          ],
        ),
      );
    } else if (googleSignInAccount != null && user == null) {
      // The user is Authenticated and authorized, but not signed into firebase
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Text('Sign into the Firebase service for access to Tourguide.'),
            ElevatedButton(
              onPressed: () => authProvider.signInWithFirebase(authProvider.googleSignInUser!),
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
            const Text('You are signed out.'),
            // This method is used to separate mobile from web code with conditional exports.
            // See: src/sign_in_button.dart
            buildSignInButton(
              onPressed: authProvider.handleSignIn,
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
                child: ((authProvider.googleSignInUser != null && authProvider.isAuthorized && authProvider.user != null) || authProvider.isLoggingOut)
                    ? _buildProcessingBody()
                    : _buildButtonBody(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  children: [
                    const TextSpan(text: 'By signing in, you agree to the \n'),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(decoration: TextDecoration.underline, color: Theme.of(context).colorScheme.primary),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          launchUrl(Uri.parse("https://tourguide.rmichels.com/termsOfService.html"));
                        },
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(decoration: TextDecoration.underline, color: Theme.of(context).colorScheme.primary),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          launchUrl(Uri.parse("https://tourguide.rmichels.com/privacyPolicy.html"));
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