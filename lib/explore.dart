import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/explore_map.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/ui/horizontal_scroller.dart';
import 'package:tourguide_app/ui/place_autocomplete.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'main.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import '../../ui/google_places_img.dart'
    if (dart.library.html) '../../ui/google_places_img_web.dart' as gpi;
import 'dart:ui' as ui;

import 'model/tour.dart';

//because I update the login status dynamically, the Explore screen needs to be a stateful widget (from Chat GPT)
class Explore extends StatefulWidget {
  const Explore({super.key});

  @override
  State<Explore> createState() => ExploreState();
}

class ExploreState extends State<Explore> {
  Future<TourguidePlaceImg?>? _fetchPhotoFuture;
  final GlobalKey _contentKey =
      GlobalKey(); // to measure height of page accurately
  double _contentHeight = 600;

  @override
  void initState() {
    logger.t('ExploreState.initState()');

    if (MyGlobals.webRoutingFix(TourguideNavigation.explorePath)) {
      super.initState();
      return;
    } else {
      _checkIfFirstTimeUserAfterAccountDeletion();

      //Firebase auth
      FirebaseAuth.instance.userChanges().listen((User? user) {
        if (!mounted) return;
        final tourProvider = Provider.of<TourProvider>(context, listen: false);
        if (user == null) {
          logger.t(
              'ExploreState.initState() - FirabaseAuth listen - FIREBASE AUTH (EXPLORE) - User is currently signed out!');
        } else {
          logger.t(
              'ExploreState.initState() - FirabaseAuth listen - FIREBASE AUTH (EXPLORE) - User is signed in!');
          if (!tourProvider.isLoadingTours) {
            _downloadTours();
          }
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

      //to accurately measure height of page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measureContentHeight();
        _fetchPhotoFuture = context.read<LocationProvider>().fetchPlacePhoto();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkIfFirstTimeUserAfterAccountDeletion() async {
    var prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('firstTimeUser') == null) {
      logger.i('_checkIfFirstTimeUserAfterAccountDeletion -> true');
      TourguideNavigation.router.go(
        TourguideNavigation.onboardingPath,
      );
    }
  }

  //TODO: Move
  Future<void> _downloadTours() async {
    logger.t('downloadTours');

    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final myAuth.AuthProvider authProvider =
        Provider.of(context, listen: false);
    TourguideUserProvider userProvider =
        Provider.of<TourguideUserProvider>(context, listen: false);

    try {
      await Future.doWhile(() async {
        // Check if the currentPosition is null
        if (locationProvider.currentPosition == null ||
            (userProvider.user == null && !authProvider.isAnonymous)) {
          // Wait for a short duration before checking again
          await Future.delayed(const Duration(milliseconds: 100));
          return true; // Continue looping
        }
        return false; // Exit loop if currentPosition is not null
      }).timeout(const Duration(seconds: 3));
    } catch (e) {
      // Handle timeout
      logger.e('Timeout waiting for location or user provider');
      // You might want to handle this situation differently
      return;
    }

    // Ensure currentPosition is not null before proceeding
    if (locationProvider.currentPosition != null) {
      await tourProvider.fetchAndSetTours(
        locationProvider.currentPosition!.latitude,
        locationProvider.currentPosition!.longitude,
        authProvider.user!.uid,
        authProvider.isAnonymous ? [] : userProvider.user!.savedTourIds,
      );
      _measureContentHeight();
    } else {
      // Handle the case where currentPosition is still null after timeout
      logger.e('Current position is still null after timeout');
    }
  }

  void _showOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return OptionsDialog(
          onPlaceSet: _handlePlaceSet,
        );
      },
    );
  }

  void _handlePlaceSet() {
    TourProvider tourProvider =
        Provider.of<TourProvider>(context, listen: false);
    if (!tourProvider.isLoadingTours) {
      _downloadTours();
    }
  }

  void _measureContentHeight() {
    try {
      var renderObject = _contentKey.currentContext?.findRenderObject();
      if (renderObject == null) return;
      final RenderBox renderBox = renderObject as RenderBox;
      setState(() {
        _contentHeight = renderBox.size.height;
      });
    } catch (e) {
      logger.e('Error measuring content height: $e');
    }
  }

  final ScrollController _scrollController =
      ScrollController(); //for bg parallax effect and refresh
  double _scrollOffset = 0;

  @override
  Widget build(BuildContext context) {
    myAuth.AuthProvider authProvider = Provider.of(context);
    LocationProvider locationProvider = Provider.of<LocationProvider>(context);
    TourProvider tourProvider = Provider.of<TourProvider>(context);
    String displayName = authProvider.user?.displayName ?? '';

    Future<void> refresh() async {
      if (!tourProvider.isLoadingTours) {
        await locationProvider.refreshCurrentLocation();
        await _downloadTours();
      }
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Shimmer(
            linearGradient: MyGlobals.createShimmerGradient(context),
            child: Stack(
              key: _contentKey,
              children: [
                Consumer<LocationProvider>(
                  builder: (context, locationProvider, child) {
                    final currentPlaceImg = locationProvider.currentPlaceImg;
                    final permissionStatus = locationProvider.permissionStatus;
                    if (currentPlaceImg == null) {
                      return Stack(
                        children: [
                          Container(
                            height: 300,
                            width: double.infinity,
                            color: Colors.black,
                          ),
                          Container(
                            height: 300,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceDim
                                      .withOpacity(.6),
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceBright
                                      .withOpacity(.6)
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          if (permissionStatus == PermissionStatus.granted)
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
                              colors: [
                                kIsWeb ? Colors.transparent : Colors.white,
                                kIsWeb ? Colors.black87 : Colors.black45
                              ],
                            ).createShader(
                                Rect.fromLTRB(0, 0, rect.width, rect.height));
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
                                  child: kIsWeb
                                      ? gpi.GooglePlacesImg(
                                          //prevents CORS error, taken from places sdk example //TODO investigate if also usable on mobile
                                          photoMetadata: currentPlaceImg
                                              .googlePlacesImg!.photoMetadata,
                                          placePhotoResponse: currentPlaceImg
                                              .googlePlacesImg!
                                              .placePhotoResponse,
                                        )
                                      : currentPlaceImg
                                          .googlePlacesImg!.placePhotoResponse
                                          .when(
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
                Stack(
                  //helps with the parallax effect by providing a spacer + white bg to cover the google img on scroll
                  children: [
                    Column(
                      children: [
                        Container(
                          height:
                              300, //should match google image (TODO: ensure it's never under 300)
                          color: Colors.transparent,
                        ),
                        Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          height: _contentHeight - 300,
                        )
                      ],
                    ),
                    StandardLayout(children: [
                      SizedBox(
                        height: 290,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 0),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: GradientText(
                              gradient: const LinearGradient(colors: [
                                Color(0xeeF2F8F8),
                                Color(0xeeE4F0EF),
                              ]),
                              richText: RichText(
                                text: TextSpan(
                                  style:
                                      Theme.of(context).textTheme.displayMedium,
                                  children: <TextSpan>[
                                    const TextSpan(text: 'Welcome'),
                                    if (locationProvider.currentCity != null &&
                                        locationProvider.currentCity.isNotEmpty)
                                      TextSpan(text: ' to \r'),
                                    if (locationProvider.currentCity != null &&
                                        locationProvider.currentCity.isNotEmpty)
                                      TextSpan(
                                          text: locationProvider.currentCity,
                                          style: GoogleFonts.vollkorn(
                                            //need to explicitly specify font for weight setting to work for some reason
                                            textStyle: Theme.of(context)
                                                .textTheme
                                                .displayMedium,
                                            fontWeight: FontWeight.w600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              logger.t('Tapped city name');
                                              _showOptionsDialog(context);
                                            }),
                                    if (displayName != null &&
                                        displayName.isNotEmpty)
                                      TextSpan(
                                          text:
                                              ', ${displayName.split(' ').first}'),
                                    if (locationProvider.permissionStatus !=
                                        PermissionStatus.granted)
                                      TextSpan(
                                          text:
                                              '\n\nPlease enable location services',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                    if (locationProvider.permissionStatus !=
                                            PermissionStatus.granted &&
                                        locationProvider.currentCity != null &&
                                        locationProvider.currentCity.isNotEmpty)
                                      TextSpan(
                                          text: ' for full functionality',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                    if (locationProvider.permissionStatus !=
                                                PermissionStatus.granted &&
                                            locationProvider.currentCity ==
                                                null ||
                                        locationProvider.currentCity.isEmpty)
                                      TextSpan(
                                          text: ', or ',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                    if (locationProvider.permissionStatus !=
                                                PermissionStatus.granted &&
                                            locationProvider.currentCity ==
                                                null ||
                                        locationProvider.currentCity.isEmpty)
                                      TextSpan(
                                        text: 'set your location',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium!
                                            .copyWith(
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            logger
                                                .t('Tapped set your location');
                                            _showOptionsDialog(context);
                                          },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Popular tours near you",
                              style: Theme.of(context).textTheme.headlineSmall),
                          IconButton(
                              onPressed: tourProvider.popularTours.contains(Tour.addTourTileId) ? null : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => ExploreMap(
                                          tours: tourProvider.getTours(
                                              tourProvider.popularTours),
                                          name: "Popular tours near you")),
                                );
                              },
                              icon: const Icon(Icons.map))
                        ],
                      ),
                      StandardLayoutChild(
                        fullWidth: true,
                        child: HorizontalScroller(
                            tours: tourProvider
                                .getTours(tourProvider.popularTours)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Local tours",
                              style: Theme.of(context).textTheme.headlineSmall),
                          IconButton(
                              onPressed: tourProvider.localTours.contains(Tour.addTourTileId) ? null : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => ExploreMap(
                                          tours: tourProvider.getTours(
                                              tourProvider.localTours),
                                          name: "Local tours")),
                                );
                              },
                              icon: const Icon(Icons.map))
                        ],
                      ),
                      StandardLayoutChild(
                        fullWidth: true,
                        child: HorizontalScroller(
                            tours:
                                tourProvider.getTours(tourProvider.localTours)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Tours around the world",
                              style: Theme.of(context).textTheme.headlineSmall),
                          IconButton(
                              onPressed: tourProvider.globalTours.contains(Tour.addTourTileId) ? null : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => ExploreMap(
                                          tours: tourProvider.getTours(
                                              tourProvider.globalTours),
                                          name: "Tours around the world")),
                                );
                              },
                              icon: const Icon(Icons.map))
                        ],
                      ),
                      StandardLayoutChild(
                        fullWidth: true,
                        child: HorizontalScroller(
                            tours: tourProvider
                                .getTours((tourProvider.globalTours))),
                      ),
                      /*Text("Debug", style: Theme.of(context).textTheme.headlineSmall),
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
                            ],
                          ),*/
                    ]),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4.0, horizontal: 0),
                        child: IconButton(
                            onPressed: () {
                              _showOptionsDialog(context);
                            },
                            icon: const Icon(Icons.more_vert),
                            color: const Color(0xeeF2F8F8)),
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

//TODO - get rid of this?
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
  final VoidCallback onPlaceSet;

  const OptionsDialog({super.key, required this.onPlaceSet});

  @override
  _OptionsDialogState createState() => _OptionsDialogState();
}

class _OptionsDialogState extends State<OptionsDialog> {
  final TextEditingController _cityEditController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showConfirm = false;
  Place? newPlace;
  Alignment _alignment = Alignment.center;
  late StreamSubscription<bool> keyboardSubscription;

  @override
  void initState() {
    super.initState();

    KeyboardVisibilityController keyboardVisibilityController =
        KeyboardVisibilityController();
    keyboardSubscription =
        keyboardVisibilityController!.onChange.listen((bool visible) {
      setState(() {
        _alignment = visible ? Alignment.topCenter : Alignment.center;
      });
    });
  }

  @override
  void dispose() {
    keyboardSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LocationProvider locationProvider = Provider.of<LocationProvider>(context);

    return AlertDialog(
      title: Text('Change Location'),
      alignment: _alignment,
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
                  SizedBox(
                      height:
                          32), // Add spacing between the dropdown and the button
                if (_showConfirm)
                  ElevatedButton(
                    onPressed: () {
                      // Validate form
                      if (_formKey.currentState!.validate()) {
                        locationProvider.setCurrentPlace(newPlace!);
                        widget.onPlaceSet();
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
