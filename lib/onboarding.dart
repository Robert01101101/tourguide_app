import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:onboarding/onboarding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/signIn.dart';
import 'package:tourguide_app/utilities/tourguide_navigation.dart';

class TourguideOnboard extends StatefulWidget {
  const TourguideOnboard({super.key});

  @override
  State createState() => _TourguideOnboardState();
}

class _TourguideOnboardState extends State<TourguideOnboard> {
  @override
  void initState() {
    FlutterNativeSplash.remove();
    super.initState();
  }

  CompleteOnboarding() async {
    var _prefs = await SharedPreferences.getInstance();
    _prefs.setBool('firstTimeUser', false);
    TourguideNavigation.router.go(
      TourguideNavigation.signInPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Onboarding(
        // List of swipeable widgets
        swipeableBody: [
          Container(
            color: Theme.of(context).primaryColor.withOpacity(1),
            padding: EdgeInsets.all(50.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 50),
                Image.asset('assets/onboarding/onboard1.png', width: 250, height: 250,),
                SizedBox(height: 20),
                Text(
                  'Welcome to Tourguide',
                  textAlign: TextAlign.center,
                  //style from theme header
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '[Internal Testing]',
                  textAlign: TextAlign.center,
                  //style from theme header
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 40),
                Text(
                  'Tourguide helps you find your way around and learn about the places you visit.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'This app is still in development and may not work as expected. Please report any issues to the developers.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Theme.of(context).primaryColor.withOpacity(.93),
            padding: EdgeInsets.all(50.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 50),
                Image.asset('assets/onboarding/onboard2.png', width: 250, height: 250,),
                SizedBox(height: 20),
                Text(
                  'Explore your destination',
                  textAlign: TextAlign.center,
                  //style from theme header
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 40),
                Text(
                  'Plan your day and route, find your way around, discover new places, and chat with an AI tourguide.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Theme.of(context).primaryColor.withOpacity(.87),
            padding: EdgeInsets.all(50.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 50),
                Image.asset('assets/onboarding/onboard3.png', width: 250, height: 250,),
                SizedBox(height: 20),
                Text(
                  'Contribute',
                  textAlign: TextAlign.center,
                  //style from theme header
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 40),
                Text(
                  'Tourguide is a community-driven app. You can contribute by adding new tours, updating information, and sharing your experiences.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Theme.of(context).primaryColor.withOpacity(.8),
            padding: EdgeInsets.all(50.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 50),
                Image.asset('assets/onboarding/onboard4.png', width: 250, height: 250,),
                SizedBox(height: 20),
                Text(
                  'Safe Travels!',
                  textAlign: TextAlign.center,
                  //style from theme header
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 40),
                Text(
                  'Start exploring local tours, and have a great time! Please share any feedback with us.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
        startIndex: 0, // Starting index of the swipeable widgets
        onPageChanges: (dragDistance, pagesLength, currentIndex, slideDirection) {
          // Callback for page change
          print('Drag Distance: $dragDistance');
          print('Pages Length: $pagesLength');
          print('Current Index: $currentIndex');
          print('Slide Direction: $slideDirection');
        },
        /*buildHeader: (context, dragDistance, pagesLength, currentIndex, setIndex, slideDirection) {
          // Build a header that will display at all times
          return Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Text(
              'Onboarding Header',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
          );
        },*/
        buildFooter: (context, dragDistance, pagesLength, currentIndex, setIndex, slideDirection) {
          // Build a footer that will display at all times
          return Container(
            padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Indicator<LinePainter>(
                  painter: LinePainter(
                    currentPageIndex: currentIndex,
                    pagesLength: pagesLength,
                    netDragPercent: dragDistance,
                    lineWidth: 20,
                    activePainter: Paint()
                      ..color = Colors.black54
                      ..strokeWidth = 4.0,
                    inactivePainter: Paint()
                      ..color = Colors.black12
                      ..strokeWidth = 2.0,
                    translate: false, slideDirection: slideDirection,
                  ),
                ),
                TextButton(
                  onPressed: CompleteOnboarding,
                  child: Text(
                    currentIndex == 3 ?
                    'Get Started' : 'Skip',
                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                ),
              ],
            ),
          );
          /*return Indicator<LinePainter>(
            painter: LinePainter(
              currentPageIndex: currentIndex,
              pagesLength: pagesLength,
              netDragPercent: dragDistance,
              lineWidth: 20,
              translate: false, slideDirection: slideDirection,
            ),
          );*/
        },
        animationInMilliseconds: 500, // Animation speed in milliseconds
      ),
    );
  }
}