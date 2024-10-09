import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/sign_in.dart';
import 'package:tourguide_app/ui/tourguide_theme.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'package:tourguide_app/utilities/tourguide_navigation.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart'
    as my_auth;
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';

class TourguideOnboard extends StatefulWidget {
  const TourguideOnboard({super.key});

  @override
  State createState() => _TourguideOnboardState();
}

class _TourguideOnboardState extends State<TourguideOnboard> {
  final _introKey = GlobalKey<IntroductionScreenState>();
  String pathToGoToNext = TourguideNavigation.signInPath;

  @override
  void initState() {
    FlutterNativeSplash.remove();
    super.initState();

    MyGlobals.initProviders(context);
    my_auth.AuthProvider authProvider =
        Provider.of<my_auth.AuthProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      authProvider.addListener(() {
        _refreshRedirectPath(authProvider);
      });
    });
    _refreshRedirectPath(authProvider);
    FirebaseAnalytics.instance.logTutorialBegin(
      parameters: {
        'tutorialName': 'onboarding',
      },
    );
  }

  void _refreshRedirectPath(my_auth.AuthProvider authProvider) {
    if (authProvider.user != null && authProvider.isAuthorized) {
      logger.t(
          "signIn.initState().authProviderListener -> user is no longer null, will skip signIn page");
      pathToGoToNext = TourguideNavigation.explorePath;
    }
  }

  void _completeOnboarding() async {
    var _prefs = await SharedPreferences.getInstance();
    _prefs.setBool('firstTimeUser', false);
    TourguideNavigation.router.go(
      pathToGoToNext,
    );
    FirebaseAnalytics.instance.logTutorialComplete(
      parameters: {
        'tutorialName': 'onboarding',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double contentMargin = MediaQuery.of(context).size.height < 1000
        ? MediaQuery.of(context).size.height / 20
        : 50;
    double imageSize = MediaQuery.of(context).size.height < 1000
        ? MediaQuery.of(context).size.height / 4
        : 250;
    double imagePadding = MediaQuery.of(context).size.height < 1000
        ? MediaQuery.of(context).size.height / 40
        : 25;

    PageDecoration pageDecoration = PageDecoration(
      titleTextStyle: Theme.of(context).textTheme.displaySmall!.copyWith(
            color: Colors.white,
          ),
      bodyTextStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
            color: Colors.white,
          ),
      pageMargin: const EdgeInsets.only(bottom: 80.0),
      contentMargin: MediaQuery.of(context).size.height < 1000
          ? EdgeInsets.symmetric(horizontal: contentMargin, vertical: 5)
          : EdgeInsets.all(contentMargin),
      imagePadding: EdgeInsets.only(bottom: imagePadding),
      titlePadding:
          EdgeInsets.only(top: imagePadding / 1.5, bottom: imagePadding),
      safeArea: 10,
      imageFlex: 9,
      bodyFlex: 10,
    );

    return Scaffold(
      body: IntroductionScreen(
        key: _introKey,
        pages: [
          PageViewModel(
            title: 'Welcome to Tourguide',
            bodyWidget: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text:
                        'Tourguide helps you find your way around and learn about the places you visit.',
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  TextSpan(
                    text: "\n\n",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextSpan(
                    text:
                        'This app is still in development and may not work as expected. Please report any issues to the developers.',
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
            ),
            image: Image.asset('assets/onboarding/onboard1.png',
                width: imageSize, height: imageSize),
            decoration: pageDecoration.copyWith(
              pageColor: Color(0x00ffffff),
            ),
          ),
          PageViewModel(
            title: 'Explore your destination',
            body:
                'Plan your day and route, find your way around, discover new places, and chat with an AI tourguide.',
            image: Image.asset('assets/onboarding/onboard2.png',
                width: imageSize, height: imageSize),
            decoration: pageDecoration.copyWith(
              pageColor: Color(0x11ffffff),
            ),
          ),
          PageViewModel(
            title: 'Contribute',
            bodyWidget: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text:
                        "Tourguide is a community-driven app. You can contribute by adding new tours, updating information, and sharing your experiences.",
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: Colors.white),
                  ),
                  TextSpan(
                    text: "\n\n",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(color: Colors.white),
                  ),
                  TextSpan(
                    text: "Please take a moment to review our ",
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: Colors.white),
                  ),
                  TextSpan(
                    text: "community guidelines",
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Colors.white,
                          decorationColor: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(Uri.parse(
                            "https://tourguide.rmichels.com/communityGuidelines.html"));
                      },
                  ),
                  TextSpan(
                    text: ".",
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            image: Image.asset('assets/onboarding/onboard3.png',
                width: imageSize, height: imageSize),
            decoration: pageDecoration.copyWith(
              pageColor: Color(0x22ffffff),
            ),
          ),
          PageViewModel(
            title: 'Safe Travels!',
            body:
                'Start exploring local tours, and have a great time! Please share any feedback with us.',
            image: Image.asset('assets/onboarding/onboard4.png',
                width: imageSize, height: imageSize),
            decoration: pageDecoration.copyWith(
              pageColor: Color(0x33ffffff),
            ),
          ),
        ],
        showSkipButton: true,
        skip: const Text('Skip',
            style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        next: const Icon(Icons.arrow_forward, color: Colors.white),
        done: const Text("Get Started",
            style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        onDone: () => _completeOnboarding(),
        onSkip: () => _introKey.currentState?.skipToEnd(),
        curve: Curves.fastLinearToSlowEaseIn,
        controlsMargin: EdgeInsets.zero,
        dotsDecorator: const DotsDecorator(
            size: Size(10.0, 10.0),
            color: Colors.white,
            activeSize: Size(22.0, 10.0),
            activeShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(25.0)),
            ),
            activeColor: Color(0xff70dad3)),
        /*dotsContainerDecorator: const ShapeDecoration(
          color: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
        ),*/
        globalBackgroundColor: TourguideTheme.tourguideColor,
        scrollPhysics: ClampingScrollPhysics(),

        //next: Icon(Icons.arrow_forward, color: Colors.white),
        //doneButtonPersist: true, // Persist done button across pages
        //animationDuration: 500, // Animation speed in milliseconds
      ),
    );
  }
}
