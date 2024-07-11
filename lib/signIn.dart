// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert' show json;
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
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
    my_auth.AuthProvider authProvider = Provider.of(context, listen: false);
    LocationProvider locationProvider = Provider.of(context, listen: false);
    TourProvider tourProvider = Provider.of(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      authProvider.addListener(() {
        if (authProvider.user != null && authProvider.isAuthorized && !navigatedAwayFromSignIn) {
          logger.t("signIn.initState().authProviderListener -> user is no longer null");
          navigatedAwayFromSignIn = true;
          // Navigate to the new screen once login is complete
          TourguideNavigation.router.go(
            TourguideNavigation.explorePath,
          );
        } else if (authProvider.user == null || authProvider.silentSignInFailed){
          logger.t("signIn.initState().authProviderListener -> user is null or silentSignInFailed");
          FlutterNativeSplash.remove();
        }
      });
      //authProvider.signInSilently();
    });
  }

  Widget _buildProcessingBody() {
    my_auth.AuthProvider authProvider = Provider.of(context);
    final GoogleSignInAccount? user = authProvider.user;

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
    final GoogleSignInAccount? user = authProvider.user;
    if (user != null) {
      // The user is Authenticated
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
    final GoogleSignInAccount? user = authProvider.user;

    return Scaffold(
        appBar: AppBar(
          title: const Text('Tourguide'),
        ),
        body: ConstrainedBox(
          constraints: const BoxConstraints.expand(),
          child: ((user != null && authProvider.isAuthorized) || authProvider.isLoggingOut) ? _buildProcessingBody() : _buildButtonBody(),
        ));
  }
}