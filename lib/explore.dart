import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/testing/debug_screen.dart';
import 'package:tourguide_app/signIn.dart';
import 'package:tourguide_app/tour_creation.dart';
import 'package:tourguide_app/ui/google_places_image.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/ui/horizontal_scroller.dart';
import 'package:tourguide_app/tour/rounded_tile.dart';
import 'package:tourguide_app/ui/place_autocomplete.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
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
  bool downloadingTours = false;
  List<Tour>? tours;
  Future<GooglePlacesImg?>? _fetchPhotoFuture;

  @override
  void initState() {
    logger.t('ExploreState.initState() !!!!!!!!!!!!!!!!!!!!');

    //Firebase auth
    FirebaseAuth.instance
        .userChanges()
        .listen((User? user) {
      if (user == null) {
        logger.t('ExploreState.initState() - FirabaseAuth listen - FIREBASE AUTH (EXPLORE) - User is currently signed out!');
      } else {
        logger.t('ExploreState.initState() - FirabaseAuth listen - FIREBASE AUTH (EXPLORE) - User is signed in!');
        if (!downloadingTours){
          downloadingTours = true;
          downloadTours();
        }
        FlutterNativeSplash.remove();
      }
    });

    super.initState();

    _fetchPhotoFuture = context.read<LocationProvider>().fetchPlacePhoto();

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
      if (_currentUser == null) logger.t("USER IS SIGNED OUT WHEN THEY SHOULDN'T BE!");
      return _currentUser!;
    } catch (error) {
      // Handle sign-in errors
      logger.t("Error during Google Sign-In: $error");
      return _currentUser!;
    }
  }

  //TODO: Move
  Future<void> downloadTours() async {
    logger.t('downloadTours');

    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    await tourProvider.fetchAndSetTours();
    List<Tour> toursFetched = tourProvider.tours;
    setState((){
      tours = toursFetched;

      downloadingTours = false;
      tiles = toursFetched.take(4).map((tour) {
        return TileData(
          tourId: tour.id,
          imageUrl: tour.imageUrl,
          title: tour.name,
          description: tour.description,
        );
      }).toList();
    });
  }

  void _showOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return OptionsDialog();
      },
    );
  }

  List<TileData> tiles = [
  TileData(
    tourId: "",
    imageUrl: "",
    title: "",
    description: "",
  ),
  TileData(
    tourId: "",
    imageUrl: "",
    title: "",
    description: "",
  ),
  TileData(
    tourId: "",
    imageUrl: "",
    title: "",
    description: "",
  ),
  TileData(
    tourId: "",
    imageUrl: "",
    title: "",
    description: "",
  ),
  // Add more tiles as needed
  ];

  final ScrollController _scrollController = ScrollController(); //for bg parallax effect
  double _scrollOffset = 0;


  @override
  Widget build(BuildContext context) {
    myAuth.AuthProvider authProvider = Provider.of(context);
    LocationProvider locationProvider = Provider.of<LocationProvider>(context);

    Future<void> _refresh() async {
      if (!downloadingTours){
        downloadingTours = true;
        downloadTours();
      }
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Shimmer(
            linearGradient: MyGlobals.shimmerGradient,
            child: Stack(
              children: [
                Selector<LocationProvider, GooglePlacesImg?>(
                  selector: (context, locationProvider) => locationProvider.currentPlaceImg,
                  builder: (context, currentPlaceImg, child) {
                    if (currentPlaceImg == null) {
                      return Stack(
                        children: [
                          Container(
                            height: 300,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xffebebf4), Color(0xff7b7b80)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xffebebf4),
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Transform.translate(
                        offset: Offset(0, _scrollOffset * 0.5),
                        child: ShaderMask(
                          shaderCallback: (rect) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white, Colors.black45],
                            ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
                          },
                          blendMode: BlendMode.multiply,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SizedBox(
                                width: constraints.maxWidth,
                                height: 300,
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  child: currentPlaceImg.placePhotoResponse.when(
                                    image: (image) => Image(
                                      image: image.image,
                                      gaplessPlayback: true,
                                    ),
                                    imageUrl: (imageUrl) => Image.network(
                                      imageUrl,
                                      gaplessPlayback: true,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }
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
                          height: 800,  //BAD! Hardcoded, but it's fine for now since it only needs to be enough to cover the google img on scroll
                        )
                      ],
                    ),
                    StandardLayout(
                        children: [
                          FutureBuilder(
                          future: _handleSignIn(),
                          builder: (context, snapshot) {
                            //Assemble welcome string
                            String displayName = authProvider.user!.displayName!;

                            // Stylized Welcome Banner text
                            return SizedBox(
                              height: 300,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 0),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: GradientText(
                                    gradient: const LinearGradient(colors: [
                                      Color(0xeeF2F8F8),
                                      Color(0xeeE4F0EF),
                                    ]),
                                    richText: RichText(
                                      text: TextSpan(
                                        style: Theme.of(context).textTheme.displayMedium,
                                        children: <TextSpan>[
                                          const TextSpan(text: 'Welcome'),
                                          if (locationProvider.currentCity != null)
                                            const TextSpan(text: ' to \r',),
                                          if (locationProvider.currentCity != null)
                                            TextSpan(
                                              text: locationProvider.currentCity,
                                              style: GoogleFonts.vollkorn(  //need to explicitly specify font for weight setting to work for some reason
                                                textStyle: Theme.of(context).textTheme.displayMedium,
                                                fontWeight: FontWeight.w600,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          if (displayName != null && displayName.isNotEmpty) TextSpan(text: ', ${displayName.split(' ').first}'),
                                        ],
                                      ),
                                    ),
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CreateTour()),
                              );
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const CreateTour()),
                                );
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const CreateTour()),
                                );
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
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                        child: IconButton(
                            onPressed: (){
                              _showOptionsDialog(context);
                            },
                            icon: const Icon(Icons.more_vert),
                            color: Color(0xeeF2F8F8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  const GradientText({
    required this.richText,
    required this.gradient,
  });

  final RichText richText;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: richText,
    );
  }
}

class OptionsDialog extends StatefulWidget {
  @override
  _OptionsDialogState createState() => _OptionsDialogState();
}

class _OptionsDialogState extends State<OptionsDialog> {
  final TextEditingController _cityEditController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showConfirm = false;
  Place? newPlace;

  @override
  Widget build(BuildContext context) {
    LocationProvider locationProvider = Provider.of<LocationProvider>(context);

    return AlertDialog(
      title: Text('Change Location'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlaceAutocomplete(
                  textEditingController: _cityEditController,
                  isFormSubmitted: false,
                  onItemSelected: (AutocompletePrediction prediction) {
                    // Handle item selection
                    logger.i('Selected place: ${prediction.fullText}');
                  },
                  onPlaceInfoFetched: (Place? place) {
                    // Handle place info fetched
                    setState(() {
                      logger.i('onPlaceInfoFetched: ${place}');
                      newPlace = place;
                      _showConfirm = true; // Show the Confirm button
                    });
                  },
                ),
                if (_showConfirm)
                  SizedBox(height: 32), // Add spacing between the dropdown and the button
                if (_showConfirm)
                  ElevatedButton(
                    onPressed: () {
                      // Validate form
                      if (_formKey.currentState!.validate()) {
                        locationProvider.setCurrentPlace(newPlace!);
                        // Handle the confirm action here
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text('Confirm'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}