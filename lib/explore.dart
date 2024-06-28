import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tourguide_app/testing/debug_screen.dart';
import 'package:tourguide_app/signIn.dart';
import 'package:tourguide_app/ui/google_places_image.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/ui/horizontal_scroller.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'main.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'dart:ui' as ui;


// #docregion Initialize
const List<String> scopes = <String>[
  'email',
  //'https://www.googleapis.com/auth/contacts.readonly',  //CONTACT DEMO - for demo of using people API to get contacts etc
];

GoogleSignIn _googleSignIn = GoogleSignIn(
  // Optional clientId
  // clientId: 'your-client_id.apps.googleusercontent.com',
  scopes: scopes,
);



//because I update the login status dynamically, the Explore screen needs to be a stateful widget (from Chat GPT)
class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  State<Explore> createState() => ExploreState();
}

class ExploreState extends State<Explore> {
  GoogleSignInAccount? _currentUser;

  @override
  void initState() {
    print('ExploreState.initState() !!!!!!!!!!!!!!!!!!!!');

    //Firebase auth
    FirebaseAuth.instance
        .userChanges()
        .listen((User? user) {
      if (user == null) {
        print('ExploreState.initState() - FirabaseAuth listen - FIREBASE AUTH (EXPLORE) - User is currently signed out!');
      } else {
        print('ExploreState.initState() - FirabaseAuth listen - FIREBASE AUTH (EXPLORE) - User is signed in!');
        FlutterNativeSplash.remove();
      }
    });

    super.initState();

    //for parallax
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }


  //TODO: fix bad code
  Future<GoogleSignInAccount> _handleSignIn() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser == null) print("USER IS SIGNED OUT WHEN THEY SHOULDN'T BE!");
      return _currentUser!;
    } catch (error) {
      // Handle sign-in errors
      print("Error during Google Sign-In: $error");
      return _currentUser!;
    }
  }







  final List<TileData> tiles = [
  TileData(
  imageUrl: 'https://via.placeholder.com/150',
  title: 'Title 1',
  description: 'Description 1',
  ),
  TileData(
  imageUrl: 'https://via.placeholder.com/150',
  title: 'Title 2',
  description: 'Description 2',
  ),
  TileData(
  imageUrl: 'https://via.placeholder.com/150',
  title: 'Title 3',
  description: 'Description 3',
  ),
  TileData(
    imageUrl: 'https://via.placeholder.com/150',
    title: 'Title 4',
    description: 'Description 4',
  ),
  // Add more tiles as needed
  ];

  final ScrollController _scrollController = ScrollController(); //for bg parallax effect
  double _scrollOffset = 0;


  @override
  Widget build(BuildContext context) {
    myAuth.AuthProvider authProvider = Provider.of(context);
    LocationProvider locationProvider = Provider.of<LocationProvider>(context);

    return Scaffold(
      /*appBar: AppBar(
        title: Text('AppBar'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_vert),
          ),
        ],
      ),*/
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Shimmer(
          linearGradient: MyGlobals.shimmerGradient,
          child: Stack(
            children: [
              Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  return FutureBuilder<GooglePlacesImg?>(
                    future: locationProvider.fetchPlacePhoto(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !(snapshot.hasData && snapshot.data != null)) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (snapshot.hasData && snapshot.data != null) {
                        final googlePlacesImg = snapshot.data!;
                        //return googlePlacesImg;
                        return Stack(
                          children: [
                            Transform.translate(
                              offset: Offset(0, _scrollOffset * 0.5), // Adjust the multiplier for the parallax effect
                              child: ShaderMask(
                                shaderCallback: (rect) {
                                  return const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.white, Colors.black45],
                                  ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                                },
                                blendMode: BlendMode.multiply,
                                child: googlePlacesImg.placePhotoResponse.when(
                                  image: (image) => Image(
                                    image: image.image,
                                    gaplessPlayback: true,
                                  ),
                                  imageUrl: (imageUrl) => Image.network(
                                    imageUrl,
                                    gaplessPlayback: true,
                                  ),
                                )
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                                child: IconButton(
                                    onPressed: (){},
                                    icon: const Icon(Icons.more_vert),
                                    color: Color(0xeeF2F8F8)),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return const Text('No photo available');
                      }
                    },
                  );
                },
              ),
              Stack( //helps with the parallax effect by providing a spacer + white bg to cover the google img on scroll
                children: [
                  Column(
                    children: [
                      Container(
                        height: 300,  //should match google image (TODO: ensure it's never under 300)
                        color: Colors.transparent,
                      ),
                      Container(
                        color: Colors.white,
                        height: 400,  //BAD! Hardcoded, but it's fine for now since it only needs to be enough to cover the google img on scroll
                      )
                    ],
                  ),
                  StandardLayout(
                      children: [
                        FutureBuilder(
                        future: _handleSignIn(),
                        builder: (context, snapshot) {
                          //Assemble welcome string
                          String title = "Welcome";
                          if (locationProvider.currentCity != null) title += " to ${locationProvider.currentCity}";
                          String displayName = authProvider.user!.displayName!;
                          if (displayName != null && displayName.isNotEmpty) title += ", ${displayName.split(' ').first}";

                          //Stylized Welcome Banner text
                          return SizedBox(
                            height: 300,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 0),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: GradientText(
                                    title,
                                    style: Theme.of(context).textTheme.displayMedium,
                                    gradient: const LinearGradient(colors: [
                                      Color(0xeeF2F8F8),
                                      Color(0xeeE4F0EF),
                                    ]),
                                  ),
                              ),
                            ),
                          );
                        }
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Explore local tours", style: Theme.of(context).textTheme.headlineSmall),
                          IconButton(onPressed: (){

                          }, icon: const Icon(Icons.add_circle_outline_sharp))
                        ],
                      ),
                      StandardLayoutChild(
                        fullWidth: true,
                        child: SizedBox(
                          height: 200.0, // Set a fixed height for the horizontal scroller
                          child: HorizontalScroller(tiles: tiles),
                        ),
                      ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Local activities", style: Theme.of(context).textTheme.headlineSmall),
                            IconButton(onPressed: (){

                            }, icon: const Icon(Icons.add_circle_outline_sharp))
                          ],
                        ),
                      StandardLayoutChild(
                          fullWidth: true,
                          child: SizedBox(
                            height: 200.0, // Set a fixed height for the horizontal scroller
                            child: HorizontalScroller(tiles: tiles),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Tours in your province", style: Theme.of(context).textTheme.headlineSmall),
                            IconButton(onPressed: (){

                            }, icon: const Icon(Icons.add_circle_outline_sharp))
                          ],
                        ),
                        StandardLayoutChild(
                          fullWidth: true,
                          child: SizedBox(
                            height: 200.0, // Set a fixed height for the horizontal scroller
                            child: HorizontalScroller(tiles: tiles),
                          ),
                        ),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Tours in your province", style: Theme.of(context).textTheme.headlineSmall),
                          ],
                        ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const DebugScreen()),
                              );
                            },
                            child: const Text('Debug Screen'),
                          ),
                          ElevatedButton(
                            onPressed: authProvider.signOut,
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                      //Text('User is signed in!!  :)\n\nUsername: ${FirebaseAuth.instance.currentUser!.displayName}\nEmail: ${FirebaseAuth.instance.currentUser!.email}'),
                    ]
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  const GradientText(
      this.text, {
        required this.gradient,
        this.style,
      });

  final String text;
  final TextStyle? style;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, style: style),
    );
  }
}