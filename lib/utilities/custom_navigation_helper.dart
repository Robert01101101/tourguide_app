import 'package:scroll_to_hide/scroll_to_hide.dart';
import 'package:tourguide_app/signIn.dart';
import 'package:tourguide_app/tour_creation/gemini_chat.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:go_router/go_router.dart';

//______________________________________________________________________________________________ CustomNavigationHelper
// from https://medium.com/flutter-community/integrating-bottom-navigation-with-go-router-in-flutter-c4ec388da16a
// example https://dartpad.dev/?id=aed0372c987b4ae32311fe32bb4c1209
class CustomNavigationHelper {
  static final CustomNavigationHelper _instance =
  CustomNavigationHelper._internal();

  static CustomNavigationHelper get instance => _instance;

  static late final GoRouter router;

  static final GlobalKey<NavigatorState> parentNavigatorKey =
  GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> exploreTabNavigatorKey =
  GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> mapTabNavigatorKey =
  GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> myToursTabNavigatorKey =
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
  static const String myToursPath = '/myTours'; //search
  static const String profilePath = '/profile'; //NEW
  static const String geminiChatPath = '/geminiChat'; //NEW

  static const String debugPath = '/debug'; //signUp
  static const String mapSamplePath = '/mapSample'; //signIn
  static const String mapRoutingPath = '/mapRouting'; //detail //TODO: Figure out what this was used for (see below in code as well)
  static const String routeTwoPath = '/routeTwo'; //NEW
  static const String rootDetailPath = '/rootDetail'; //rootDetail
  static const String listViewAPath = '/listViewA';



  static const String signInPath = '/signIn';

  factory CustomNavigationHelper() {
    return _instance;
  }

  CustomNavigationHelper._internal() {
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
            navigatorKey: mapTabNavigatorKey,
            routes: [
              GoRoute(
                path: mapPath,
                pageBuilder: (context, state) {
                  return getPage(
                    child: const MapScreen(),
                    state: state,
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: myToursTabNavigatorKey,
            routes: [
              GoRoute(
                path: myToursPath,
                pageBuilder: (context, state) {
                  return getPage(
                    child: const MyTours(),
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
      )
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
      initialLocation: signInPath,
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
  Widget build(BuildContext context) {
    return Scaffold(
      /*
      appBar: AppBar(
        title: const Text('Bottom Navigator Shell'),    //TODO - decide if I can remove this, use for optional shell header bar
      ),*/
      body: SafeArea(
        child: widget.child,
      ),
      bottomNavigationBar: ScrollToHide (
        scrollController: MyGlobals.scrollController,
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
              icon: Icon(Icons.map),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite),
              label: 'My Tours',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat),
              label: 'AI Chat',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('2'),
                child: Icon(Icons.account_circle),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}