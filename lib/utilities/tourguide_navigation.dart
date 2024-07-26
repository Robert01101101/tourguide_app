import 'package:scroll_to_hide/scroll_to_hide.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:tourguide_app/onboarding.dart';
import 'package:tourguide_app/profile/profile_settings.dart';
import 'package:tourguide_app/sign_in.dart';
import 'package:tourguide_app/gemini_chat.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

//______________________________________________________________________________________________ CustomNavigationHelper
// from https://medium.com/flutter-community/integrating-bottom-navigation-with-go-router-in-flutter-c4ec388da16a
// example https://dartpad.dev/?id=aed0372c987b4ae32311fe32bb4c1209
// Usage:
// Navigator.push(
//    context,
//    MaterialPageRoute(builder: (context) => const GeminiChat()),
// );
// Usage without push pop:
// TourguideNavigation.router.go(
//     TourguideNavigation.signInPath,
// );
//Usage with push pop sideways:
//Navigator.push(
//  context,
//  SlideTransitionRoute(
//    page: ProfileSettings(),
//    beginOffset: Offset(1.0, 0.0), // Slide in from right
//  ),
//);
class TourguideNavigation {
  static final TourguideNavigation _instance =
  TourguideNavigation._internal();

  static TourguideNavigation get instance => _instance;

  static late final GoRouter router;

  static final GlobalKey<NavigatorState> parentNavigatorKey =
  GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> exploreTabNavigatorKey =
  GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> contributeTabNavigatorKey =
  GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> profileTabNavigatorKey =
  GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> geminiChatTabNavigatorKey =
  GlobalKey<NavigatorState>();

  BuildContext get context =>
      router.routerDelegate.navigatorKey.currentContext!;

  GoRouterDelegate get routerDelegate => router.routerDelegate;

  GoRouteInformationParser get routeInformationParser =>
      router.routeInformationParser;

  static const String explorePath = '/explore'; //home
  static const String mapPath = '/map'; //settings
  static const String contributePath = '/contribute'; //search
  static const String profilePath = '/profile'; //NEW
  static const String geminiChatPath = '/geminiChat'; //NEW

  static const String debugPath = '/debug'; //signUp
  static const String mapSamplePath = '/mapSample'; //signIn
  static const String mapRoutingPath = '/mapRouting'; //detail //TODO: Figure out what this was used for (see below in code as well)
  static const String routeTwoPath = '/routeTwo'; //NEW
  static const String rootDetailPath = '/rootDetail'; //rootDetail
  static const String listViewAPath = '/listViewA';


  static const String onboardingPath = '/onboarding'; //onboarding
  static const String signInPath = '/signIn';

  factory TourguideNavigation() {
    return _instance;
  }

  TourguideNavigation._internal();

  Future<void> initialize() async {
    await _initializeRouter();
  }

  Future<void> _initializeRouter() async {
    await checkFirstTimeUser();

    final routes = [
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: parentNavigatorKey,
        branches: [
          StatefulShellBranch(
            navigatorKey: exploreTabNavigatorKey,
            routes: [
              GoRoute(
                path: explorePath,
                pageBuilder: (context, GoRouterState state) {
                  return getPage(
                    child: const Explore(), //TODO change
                    state: state,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: geminiChatTabNavigatorKey,
            routes: [
              GoRoute(
                path: geminiChatPath,
                pageBuilder: (context, state) {
                  return getPage(
                    child: const GeminiChat(),
                    state: state,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: contributeTabNavigatorKey,
            routes: [
              GoRoute(
                path: contributePath,
                pageBuilder: (context, state) {
                  return getPage(
                    child: const Contribute(),
                    state: state,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: profileTabNavigatorKey,
            routes: [
              GoRoute(
                path: profilePath,
                pageBuilder: (context, state) {
                  return getPage(
                    child: const Profile(),
                    state: state,
                  );
                },
              ),
            ],
          ),
        ],
        pageBuilder: (
            BuildContext context,
            GoRouterState state,
            StatefulNavigationShell navigationShell,
            ) {
          return getPage(
            child: BottomNavigationPage(
              child: navigationShell,
            ),
            state: state,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: parentNavigatorKey, //?? TODO figure out meaning
        path: debugPath,
        pageBuilder: (context, state) {
          return getPage(
            child: const DebugScreen(),
            state: state,
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: parentNavigatorKey, //?? TODO figure out meaning
        path: mapSamplePath,
        pageBuilder: (context, state) {
          return getPage(
            child: const MapSample(),
            state: state,
          );
        },
      ),
      GoRoute(
        path: mapRoutingPath,
        pageBuilder: (context, state) {
          return getPage(
            child: const MapSampleDrawRoute(),
            state: state,
          );
        },
      ),
      GoRoute(
        path: routeTwoPath,
        pageBuilder: (context, state) {
          return getPage(
            child: const SecondRoute(),
            state: state,
          );
        },
      ),
      GoRoute(
        path: listViewAPath,
        pageBuilder: (context, state) {
          return getPage(
            child: const ListViewA(),
            state: state,
          );
        },
      ),
      GoRoute(
        path: signInPath,
        pageBuilder: (context, state) {
          return getPage(
            child: const SignIn(),
            state: state,
          );
        },
      ),
      GoRoute(
        path: onboardingPath,
        pageBuilder: (context, state) {
          return getPage(
            child: const TourguideOnboard(),
            state: state,
          );
        },
      ),
      /* //TODO figure out what this was used for
      GoRoute(
        parentNavigatorKey: parentNavigatorKey,
        path: rootDetailPath,
        pageBuilder: (context, state) {
          return getPage(
            child: const DetailPage(),
            state: state,
          );
        },
      ),*/
    ];

    router = GoRouter(
      navigatorKey: parentNavigatorKey,
      initialLocation: isFirstTime ? onboardingPath : signInPath,
      routes: routes,
    );
  }


  static Page getPage({
    required Widget child,
    required GoRouterState state,
  }) {
    return MaterialPage(
      key: state.pageKey,
      child: child,
    );
  }

  bool isFirstTime = true;

  Future<void> checkFirstTimeUser() async {
    var _prefs = await SharedPreferences.getInstance();
    isFirstTime = _prefs.getBool('firstTimeUser') ?? true;
    logger.i('isFirstTime: $isFirstTime');
  }

}


class SlideTransitionRoute extends PageRouteBuilder {
  final Widget page;
  final Offset beginOffset;

  SlideTransitionRoute({required this.page, required this.beginOffset})
      : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      var tween = Tween(begin: beginOffset, end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOut));
      var offsetAnimation = animation.drive(tween);

      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );
}




//______________________________________________________________________________________________ BottomNavigationPage
class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({
    super.key,
    required this.child,
  });

  final StatefulNavigationShell child;

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> {

  @override
  void initState() {
    super.initState();
    MyGlobals.scrollController = AutoScrollController();
  }

  @override
  void dispose() {
    if (MyGlobals.scrollController != null) MyGlobals.scrollController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: widget.child,
      ),
      bottomNavigationBar: ScrollToHide (
        scrollController: MyGlobals.scrollController!,
        hideDirection: Axis.vertical,
        height: 80,
        duration: const Duration(milliseconds: 300),
        child: NavigationBar(
          onDestinationSelected: (int index) {
            widget.child.goBranch(
              index,
              initialLocation: index == widget.child.currentIndex,
            );
            setState(() {});
          },
          indicatorColor: Colors.amber,

          selectedIndex:  widget.child.currentIndex,
          destinations: const <Widget>[
            NavigationDestination(
              selectedIcon: Icon(Icons.home),
              icon: Icon(Icons.language),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat),
              label: 'AI Tourguide',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_add),
              label: 'Contribute',
            ),
            NavigationDestination(
              /*icon: Badge(
                label: Text('2'),
                child: Icon(Icons.account_circle),
              ),*/
              icon: Icon(Icons.account_circle),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}