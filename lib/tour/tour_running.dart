import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/model/tourguide_place.dart';
import 'package:tourguide_app/tour/tour_creation.dart';
import 'package:tourguide_app/tour/tour_details_options.dart';
import 'package:tourguide_app/tour/tourguide_user_profile_view.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/ui/tour_rating_bookmark_buttons.dart';
import 'package:tourguide_app/ui/tourguide_theme.dart';
import 'package:tourguide_app/utilities/map_utils.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../utilities/custom_import.dart';
import 'package:http/http.dart' as http;
import '../utilities/providers/tourguide_user_provider.dart';
import '../utilities/services/tour_service.dart';
import '../utilities/singletons/tts_service.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;

class TourRunning extends StatefulWidget {
  const TourRunning({Key? key}) : super(key: key);

  @override
  State<TourRunning> createState() => _TourRunningState();
}

class _TourRunningState extends State<TourRunning> {
  final Completer<GoogleMapController> _mapControllerCompleter = Completer<GoogleMapController>();
  bool _isFullScreen = false;
  bool _isLoading = true, _isLoadingFullscreen = true;
  CameraPosition _currentCameraPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.0,
  );
  Set<Marker> _markers = Set<Marker>();
  Set<Polyline> _polylines = Set<Polyline>();
  final TtsService _ttsService = TtsService();
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _targetKeys = [];
  Tour _tour = Tour.empty();
  int _currentStep = 0;
  bool _currentStepVisible = true;
  bool _initialZoomToFirstWaypointComplete = false;
  List<BitmapDescriptor> _defaultMarkerBitmaps = [];
  List<BitmapDescriptor> _highlightedMarkerBitmaps = [];
  List<List<LatLng>> _routeSegments = [];
  int thisUsersRating = 0;
  bool _tourFinished = false;
  bool _mapCurrentlyPinnedAtTop = false;
  double _mapYposition = 0;
  final GlobalKey _mapKey = GlobalKey();
  final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizersEager = {
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())
  };
  final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizersPan = {
    Factory<PanGestureRecognizer>(() => PanGestureRecognizer())
  };



  @override
  void initState() {
    super.initState();
    TourProvider tourProvider = Provider.of<TourProvider>(context, listen: false);
    _tour = tourProvider.selectedTour!;
    thisUsersRating = _tour.thisUsersRating ?? 0;
    _addMarkers();
    _scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getMapPosition();
    });
  }

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }

  void _handleScroll() {
    // Get the scroll offset
    final scrollOffset = _scrollController.offset;

    // Determine the height of the SliverPinnedHeader
    //final pinnedHeaderHeight = kIsWeb ? 450.0 : 350.0;
    // Get the render box of the map widget
    final RenderBox renderBox = _mapKey.currentContext?.findRenderObject() as RenderBox;

    // Get the offset of the map widget relative to the screen
    final Offset position = renderBox.localToGlobal(Offset.zero);

    // Get the vertical position (Y-coordinate)
    final double yPosition = position.dy;

    // Check if the scroll offset has reached the point where the header is pinned
    final isPinned = scrollOffset >= _mapYposition;//pinnedHeaderHeight;

    // Update the state if the pinned state has changed
    if (_mapCurrentlyPinnedAtTop != isPinned) {
      logger.i('Map pinned at top: $isPinned, scrollOffset: $scrollOffset, yPosition: $yPosition');// pinnedHeaderHeight: $pinnedHeaderHeight');
      setState(() {
        _mapCurrentlyPinnedAtTop = isPinned;
      });
    }
  }

  void _getMapPosition() {
    // Get the render box of the map widget
    final RenderBox renderBox = _mapKey.currentContext?.findRenderObject() as RenderBox;

    // Get the offset of the map widget relative to the screen
    final Offset position = renderBox.localToGlobal(Offset.zero);

    // Get the vertical position (Y-coordinate)
    _mapYposition = position.dy;

    // Now you can use yPosition as needed
    //logger.t("Map Y Position: $_mapYposition");
  }



  Future<void> _addMarkers() async {
    // Clear previous bitmaps
    _defaultMarkerBitmaps.clear();
    _highlightedMarkerBitmaps.clear();

    //add tourguidePlace markers
    for (int i = 0; i < _tour.tourguidePlaces.length; i++) {
      TourguidePlace tourguidePlace = _tour.tourguidePlaces[i];

      // Create default and highlighted bitmaps
      final BitmapDescriptor defaultIcon = await MapUtils.createNumberedMarkerBitmap(i + 1);
      final BitmapDescriptor highlightedIcon = await MapUtils.createNumberedMarkerBitmap(i + 1, color: Theme.of(context).colorScheme.primary);

      // Store the bitmaps in the lists
      _defaultMarkerBitmaps.add(defaultIcon);
      _highlightedMarkerBitmaps.add(highlightedIcon);

      _targetKeys.add(GlobalKey());
      _markers.add(
        Marker(
          markerId: MarkerId(tourguidePlace.googleMapPlaceId),
          position: LatLng(tourguidePlace.latitude, tourguidePlace.longitude),
          icon: defaultIcon,
          infoWindow: InfoWindow(
            title: tourguidePlace.title,
            snippet: tourguidePlace.description,
            onTap: () {
              // Handle marker tap
              _setStep(i);
              logger.i('Marker tapped: ${tourguidePlace.title}');
            },
          ),
        ),
      );
    }

    _targetKeys.add(GlobalKey()); //add extra key for finish tour scroll

    setState(() {
      _markers = _markers;
    });

    //set zoom
    LatLngBounds bounds = MapUtils.createLatLngBounds(_tour.tourguidePlaces.map((place) => LatLng(place.latitude, place.longitude)).toList());
    final GoogleMapController controller = await _mapControllerCompleter.future;
    controller.moveCamera(CameraUpdate.newLatLngBounds(bounds, 50));

    // Fetch directions and draw polyline
    _fetchDirections();
  }

  Future<void> _fetchDirections() async {
    // Replace with your Google Maps API key
    String apiKey = remoteConfig.getString('google_api_key');

    // Prepare waypoints for directions API request
    //List<LatLng> waypoints = [];
    List<String> waypoints = [];
    for (var tourguidePlace in _tour.tourguidePlaces) {
      //waypoints.add(LatLng(tourguidePlace.latitude, tourguidePlace.longitude));
      waypoints.add(tourguidePlace.googleMapPlaceId);
    }

    //TODO: Address higher rate billing for 10+ waypoints
    // Create waypoints string for API request
    String waypointsString = "";
    if (waypoints.length > 2){
      /*waypointsString = waypoints.sublist(1, waypoints.length - 1)
          .map((point) => 'via:${point.latitude},${point.longitude}')
          .join('|');*/
      waypointsString = waypoints.sublist(1, waypoints.length - 1)
          .map((point) => 'via:place_id:${point}')
          .join('|');
    }

    logger.t('Waypoints.length: ${waypoints.length}');

    //TODO: Sometimes placeId works better, sometimes lat long, with placeIds it seems walking mode can be tricky -> address

    // Construct directions API URL
    int attempt = 0;
    while (attempt < 2) {
      logger.t('attempt: ${attempt}');
      try {
        String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        //'origin=${waypoints.first.latitude},${waypoints.last.longitude}&'
        //'destination=${waypoints.last.latitude},${waypoints.last.longitude}&'
            'origin=place_id:${waypoints.first}&'
            'destination=place_id:${waypoints.last}&'
            '${waypointsString.isNotEmpty ? 'waypoints=$waypointsString&' : waypointsString}'
            'mode=${attempt == 0 ? 'walking&' : 'driving&'}'
            'key=$apiKey';

        //logger.i(url);

        final response = await http.get(Uri.parse(url));
        logger.t('response: ${response}');

        //logger.i(response.body);

        if (response.statusCode == 200) {
          attempt++;
          Map<String, dynamic> data = jsonDecode(response.body);
          // Check the status field
          String status = data['status'];

          if (status == 'ZERO_RESULTS') {
            // Handle case where no results were found
            logger.w('No results found for the given waypoints. Trying again with driving directions.');
            continue;
          }
          List<LatLng> points = _decodePolyline(data['routes'][0]['overview_polyline']['points']);

          // Convert waypoints to LatLng
          logger.t('convert:');
          List<LatLng> waypointLatLngs = _tour.tourguidePlaces
              .map((place) => LatLng(place.latitude, place.longitude))
              .toList();

          // Segment the polyline based on the waypoints
          logger.t('segment:');
          _routeSegments = _createRouteSegments(points, waypointLatLngs);

          logger.t('polyline:');
          // Initially add the full polyline
          _addPolyline(points);
          break;
        } else {
          throw Exception('Failed to load directions');
        }
      } catch (e, stack) {
        logger.e('Failed to get directions: $e \n $stack');
        attempt++;
      }
    }
  }

  List<int> _findWaypointIndices(List<LatLng> points, List<LatLng> waypoints) {
    List<int> waypointIndices = [];

    for (LatLng waypoint in waypoints) {
      double minDistance = double.infinity;
      int closestIndex = 0;

      for (int i = 0; i < points.length; i++) {
        double distance = MapUtils.calculateDistance(waypoint, points[i]);
        if (distance < minDistance) {
          minDistance = distance;
          closestIndex = i;
        }
      }

      // Ensure the index is strictly increasing
      if (waypointIndices.isNotEmpty && closestIndex <= waypointIndices.last) {
        // Adjust the index to be greater than the previous one
        closestIndex = waypointIndices.last + 1;
      }

      // Ensure the index is within bounds
      if (closestIndex < points.length) {
        waypointIndices.add(closestIndex);
      }
    }

    return waypointIndices;
  }

  List<List<LatLng>> _createRouteSegments(List<LatLng> points, List<LatLng> waypoints) {
    try {
      List<List<LatLng>> segments = [];
      List<int> waypointIndices = _findWaypointIndices(points, waypoints);

      for (int i = 0; i < waypointIndices.length - 1; i++) {
        int start = waypointIndices[i];
        int end = waypointIndices[i + 1];

        // Ensure valid range
        if (start <= end && end + 1 <= points.length) {
          segments.add(points.sublist(start, end + 1)); // Include end point
        } else {
          logger.w('Invalid segment range: start=$start, end=$end');
        }
      }

      // Add the last segment
      int lastSegmentStart = waypointIndices[waypointIndices.length - 1];
      if (lastSegmentStart < points.length) {
        segments.add(points.sublist(lastSegmentStart, points.length));
      } else {
        logger.w('Skipping last segment creation due to invalid lastSegmentStart=$lastSegmentStart');
      }

      return segments;
    } catch (e, stack) {
      logger.e('Failed to create route segments: $e \n $stack');
      return [];
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      double latitude = lat / 1E5;
      double longitude = lng / 1E5;
      points.add(LatLng(latitude, longitude));
    }
    return points;
  }

  void _addPolyline(List<LatLng> polylineCoordinates) {
    _polylines.add(
      Polyline(
        polylineId: PolylineId('Route'),
        color: Colors.blue,
        width: 5,
        points: polylineCoordinates,
      ),
    );

    setState(() {
      _polylines = _polylines;
    });
  }

  void _showOptionsDialog(BuildContext context) {
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TourDetailsOptions(
          onEditPressed: () {
            // Handle edit button press
            Navigator.of(context).pop(); // Close the dialog
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CreateEditTour(isEditMode: true,tour: _tour.copyWith(isOfflineCreatedTour: true))),
            );
          },
          onDeletePressed: () {
            // Handle delete button press
            Navigator.of(context).pop(); // Close the dialog
            _deleteTour();
          },
          tour: _tour,
        );
      },
    );
  }

  void _deleteTour() async {
    try {
      // Handle delete tour
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleting tour...')),
      );
      final tourProvider = Provider.of<TourProvider>(context, listen: false);
      await tourProvider.deleteTour(_tour);
      if (mounted){
        Navigator.of(context).pop();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully deleted tour.')),
        );
      }

    } catch (e) {
      logger.e('Failed to delete tour: $e');
      if (mounted){
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete tour due to an error.')),
        );
      }
    }


  }

  int? currentlyPlayingIndex; // Track the index of the currently playing place

  void _toggleTTS(String description, int index) {
    if (currentlyPlayingIndex == index) {
      _ttsService.stop(); // Stop the TTS service if the same button is pressed
      setState(() {
        currentlyPlayingIndex = null; // Reset the index
      });
    } else {
      _ttsService.speak(description); // Start speaking
      setState(() {
        currentlyPlayingIndex = index; // Set the currently playing index
      });
    }
  }

  void _scrollToTarget(int placeIndex, {bool delay = false}) {
    if (delay) {
      Future.delayed(const Duration(milliseconds: 350), () {
        _scrollToTarget(placeIndex);
      });
    } else {
      final context = _targetKeys[placeIndex].currentContext;
      if (context != null) {
        setState(() {
          _isFullScreen = false;
        });
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _moveCameraToMarkerAndHighlightMarker(int index) async {
    if (index >= 0 && index < _markers.length) {
      // Update the marker with the new bitmap
      setState(() {
        _markers = _markers.map((marker) {
          if (marker.markerId.value == _tour.tourguidePlaces[index].googleMapPlaceId) {
            // Use the highlighted bitmap for the selected marker
            return marker.copyWith(iconParam: _highlightedMarkerBitmaps[index]);
          } else {
            // Use the default bitmap for other markers
            return marker.copyWith(iconParam: _defaultMarkerBitmaps[_markers.toList().indexOf(marker)]);
          }
        }).toSet();
      });

      final marker = _markers.elementAt(index); // Get the marker at the specified index
      final targetPosition = LatLng(marker.position.latitude, marker.position.longitude);

      LatLngBounds bounds;

      if (index == 0) {
        // If it's the first marker, just zoom into that marker
        bounds = LatLngBounds(
          southwest: LatLng(marker.position.latitude - 0.005, marker.position.longitude - 0.005),
          northeast: LatLng(marker.position.latitude + 0.005, marker.position.longitude + 0.005),
        );
      } else {
        // Get the previous marker
        final previousMarker = _markers.elementAt(index - 1);
        final previousPosition = LatLng(previousMarker.position.latitude, previousMarker.position.longitude);

        // Create bounds to cover both markers
        bounds = LatLngBounds(
          southwest: LatLng(
            min(targetPosition.latitude, previousPosition.latitude) - 0.0002,
            min(targetPosition.longitude, previousPosition.longitude) - 0.0002,
          ),
          northeast: LatLng(
            max(targetPosition.latitude, previousPosition.latitude) + 0.0002,
            max(targetPosition.longitude, previousPosition.longitude) + 0.0002,
          ),
        );
      }

      final GoogleMapController mapController = await _mapControllerCompleter.future;

      // Move the camera to the bounds
      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100)); // The padding is set to 100

      _highlightSegment(index-1);
    }
  }

  void _highlightSegment(int segmentIndex) {
    // Clear existing polylines
    _polylines.clear();
    Color colPrimary = Theme.of(context).colorScheme.primary;

    // Add non-highlighted segments
    for (int i = 0; i < _routeSegments.length; i++) {
      _polylines.add(
        Polyline(
          polylineId: PolylineId('Segment_$i'),
          color: i == segmentIndex ? colPrimary : Colors.blue,
          width: 5,
          points: _routeSegments[i],
        ),
      );
    }

    setState(() {
      _polylines = _polylines;
    });
  }

  void _finishTour(){
    logger.i('Tour Finished');
    setState(() {
      _tourFinished = true;
    });
    _scrollToTarget(_tour.tourguidePlaces.length, delay: true);
  }

  void _setStep(int step){
    setState(() {
      if (_currentStep == step) {
        _currentStepVisible = !_currentStepVisible;
      } else {
        _currentStepVisible = true;
      }
      _currentStep = step;
    });
    _scrollToTarget(_currentStep, delay: true);
    _moveCameraToMarkerAndHighlightMarker(_currentStep);
  }



  @override
  Widget build(BuildContext context) {
    final tourProvider = Provider.of<TourProvider>(context);
    final tourguideUserProvider = Provider.of<TourguideUserProvider>(context);

    bool showMap = _tour.latitude != null && _tour.latitude != 0 && _tour.longitude != null && _tour.longitude != 0;
    if (showMap && _currentCameraPosition.target == LatLng(0, 0)) {
      _currentCameraPosition = CameraPosition(
        target: LatLng(_tour.latitude, _tour.longitude),
        zoom: 14.0,
      );
    }

    return Scaffold(
      appBar: _isFullScreen ? AppBar(
        title: Text(_tour.name),
        actions:
        [
          if (!_tour.isOfflineCreatedTour)
            IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: () {
                // Show options menu
                _showOptionsDialog(context);
              },
            ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isFullScreen = false;
            });
          },
        ),
      ) : null,
      body: PopScope(
        canPop: !_isFullScreen,
        onPopInvoked: (bool didPop) {
          if (!didPop && _isFullScreen){
            setState(() {
              _isFullScreen = false;
            });
          }
        },
        child: Stack(
          children: [CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                //title: Center(child: Text(_tour.name)),
                actions: [
                  if (!_tour.isOfflineCreatedTour)
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        _showOptionsDialog(context);
                      },
                    ),
                ],
                /*leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      Navigator.of(context).pop();
                    });
                  },
                ),*/
                foregroundColor: Theme.of(context).brightness == Brightness.light ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
                floating: false,
                pinned: false,
                expandedHeight: 230.0,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Transform.translate(
                    offset: Offset(0, -32),
                    child: Text(
                      textAlign: TextAlign.center,
                      _tour.name,
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                        color: Theme.of(context).brightness == Brightness.light ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
                      )
                    ),
                  ),
                  titlePadding: EdgeInsets.only(bottom: 0.0),
                  expandedTitleScale: 1,
                  collapseMode: CollapseMode.parallax,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        height: kIsWeb ? 400 : 230,
                        child: ClipRRect(
                          child: kIsWeb
                              ?
                          Image.network(_tour.imageUrl!,
                              width: MediaQuery.of(context).size.width,
                              height: 400.0,
                              fit: BoxFit.cover)
                              :
                          _tour.imageFile != null
                              ?  //add null safety for img to upload
                          Image.file(_tour.imageFile!,
                              width: MediaQuery.of(context).size.width,
                              height: 230.0,
                              fit: BoxFit.cover)
                              :
                          Container(
                            color: Colors.grey,
                            width: MediaQuery.of(context).size.width,
                            height: 230.0,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.2),
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    StandardLayout(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16.0),
                            Container(
                              height: 105,
                              child: Text(
                                _tour.description,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 16.0),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SliverPinnedHeader(
                child:
                  Container(
                    height: kIsWeb ? 450 : 350.0, // Adjust height as needed
                    child: Stack(
                      children: [
                        if (showMap)  //TODO - understand why this is necessary - Google Map appears transparent in spots without it
                          Container(
                            color: Color(0xffe8eaed),
                          ),
                        if (showMap)
                        GoogleMap(
                          key: _mapKey,
                          gestureRecognizers: _mapCurrentlyPinnedAtTop ? _gestureRecognizersEager : _gestureRecognizersPan,
                          mapType: MapType.normal,
                          myLocationEnabled: true,
                          initialCameraPosition: _currentCameraPosition,
                          markers: _markers,
                          polylines: _polylines,
                          onMapCreated: (GoogleMapController controller) async {
                            if (!_mapControllerCompleter.isCompleted) {
                              _mapControllerCompleter.complete(controller);
                            } else {
                              final GoogleMapController mapController = await _mapControllerCompleter.future;
                              mapController.moveCamera(CameraUpdate.newCameraPosition(_currentCameraPosition));
                            }
                            await Future.delayed(const Duration(milliseconds: 200)); //avoid flicker
                            setState(() {
                              _isLoading = false;
                            });
                          },
                          onCameraMove: (CameraPosition position) {
                            _currentCameraPosition = position;
                          },
                        ),
                        if (_isLoading)
                          Container(
                            color: Color(0xffe8eaed),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        if (!_isLoading)
                          Positioned(
                            bottom: 120,
                            right: 10,
                            child: SizedBox(
                              width: 42,
                              height: 42,
                              child: RawMaterialButton(
                                onPressed: () async {
                                  final controller = await _mapControllerCompleter.future;
                                  setState(() {
                                    _isFullScreen = !_isFullScreen;
                                    _isLoadingFullscreen = true;
                                  });
                                  controller.moveCamera(
                                    CameraUpdate.newCameraPosition(_currentCameraPosition),
                                  );
                                },
                                elevation: 1.0,
                                fillColor: Colors.white.withOpacity(0.9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0), // Adjust the radius as needed
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(1.0), // Adjust inner padding as needed
                                  child: Icon(
                                    _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                    color: const Color(0xff666666),
                                    size: 32.0, // Adjust the size of the icon as needed
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ),
              SliverToBoxAdapter(
                child: StandardLayout(
                  children: [
                    StandardLayoutChild(
                      fullWidth: true,
                      child: Column( //wrap in columnn to remove gap between stepper and bottom row, since stepper has a lot of margin by default
                        children: [
                          if (kIsWeb)
                            const SizedBox(height: 32.0),
                          if (_tour.tourguidePlaces.isNotEmpty)
                            Transform.translate( // Move the stepper up to hide top margin, seems to be the easiest way to achieve it
                              offset: Offset(0, -32),
                              child: Stepper(
                                currentStep: _currentStep,
                                physics: NeverScrollableScrollPhysics(),
                                onStepTapped: (step) {
                                  _setStep(step);
                                },
                                onStepContinue: () {
                                  if (_currentStep < _tour.tourguidePlaces.length) {
                                    setState(() {
                                      _currentStep += 1;
                                    });
                                    _scrollToTarget(_currentStep, delay: true);
                                    _moveCameraToMarkerAndHighlightMarker(_currentStep);
                                  }
                                },
                                onStepCancel: () {
                                  if (_currentStep > 0) {
                                    setState(() {
                                      _currentStep -= 1;
                                    });
                                    _scrollToTarget(_currentStep, delay: true);
                                    _moveCameraToMarkerAndHighlightMarker(_currentStep);
                                  }
                                },
                                controlsBuilder: (BuildContext context, ControlsDetails controlsDetails) {
                                  return Stack(
                                    children: [
                                      Visibility(
                                          visible: !_currentStepVisible,
                                          child: Container()),
                                      Visibility(
                                        visible: _currentStepVisible,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            children: <Widget>[
                                              const SizedBox(width: 8),
                                              if (_currentStep > 0)
                                                TextButton(
                                                  onPressed: controlsDetails.onStepCancel,
                                                  style: ElevatedButton.styleFrom(
                                                    elevation: 0,
                                                    backgroundColor: Colors.transparent,
                                                    foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                                                    //primary: Colors.blue, // Custom color for "Continue" button
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(3.0), // Custom radius
                                                    ),
                                                  ),
                                                  child: const Text('Previous Place'),
                                                ),
                                              const SizedBox(width: 24), // Add spacing between buttons if needed
                                              TextButton(
                                                onPressed: _currentStep != _tour.tourguidePlaces.length-1 ? controlsDetails.onStepContinue : !_tourFinished ? _finishTour : null,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                                  foregroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                                                  //primary: Colors.grey, // Custom color for "Back" button
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(3.0), // Custom radius
                                                  ),
                                                ),
                                                child: _currentStep != _tour.tourguidePlaces.length-1 ? const Text('Next Place') : const Text('Finish Tour'),
                                              ),
                                              Spacer(),
                                              /*if (_currentStep == 1)
                                                IconButton(
                                                    padding: EdgeInsets.all(10),
                                                    onPressed: (){},
                                                    icon: Icon(Icons.map))*/
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );

                                },
                                margin: EdgeInsets.zero,
                                steps: _tour.tourguidePlaces.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  var place = entry.value;
                                  return Step(
                                    title: Text(key: _targetKeys.isNotEmpty && _targetKeys.length > index ? _targetKeys[index] : null, place.title),
                                    isActive: _currentStep >= (index),
                                    state: _currentStep > (index) ? StepState.complete : StepState.indexed,
                                    content: Visibility(
                                      visible: _currentStepVisible,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(//Title Row
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      "${index+1}. ",
                                                      style: Theme.of(context).textTheme.titleMedium,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    SizedBox(width: 8.0),
                                                    Flexible(
                                                      child: Text(
                                                        "${place.title}",
                                                        style: Theme.of(context).textTheme.titleMedium,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                    onPressed: () => MapUtils.openMapWithQuery(place.title),
                                                    icon: Icon(Icons.directions),
                                                  ),
                                                ],
                                              ),
                                              IconButton(
                                                onPressed: () => _toggleTTS(place.description, index),
                                                icon: Icon(currentlyPlayingIndex == index ? Icons.stop : Icons.play_circle,),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 6.0),
                                          VisibilityDetector(
                                            key: Key('place$index'),
                                            onVisibilityChanged: (VisibilityInfo info) {
                                              if (info.visibleFraction == 1) {
                                                if (!_initialZoomToFirstWaypointComplete) {
                                                  logger.t('Place $index visibility: ${info.visibleFraction} - > _initialZoomToFirstWaypoint');
                                                  _initialZoomToFirstWaypointComplete = true;
                                                  _moveCameraToMarkerAndHighlightMarker(0);
                                                }
                                              }
                                            },
                                            child: Text(
                                              place.description, // Assuming each place has a 'description' field
                                              style: Theme.of(context).textTheme.bodyMedium,
                                              softWrap: true,
                                              maxLines: null,
                                              overflow: TextOverflow.visible,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          Visibility(
                            visible: _tourFinished,
                            child: Column(
                              children: [
                                Text(key: _targetKeys.isNotEmpty && _targetKeys.length > _tour.tourguidePlaces.length ? _targetKeys[_targetKeys.length-1] : null, 'We hope you\'ve enjoyed this tour!', style: Theme.of(context).textTheme.bodyMedium),
                                SizedBox(height: 32.0),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TourRatingBookmarkButtons(tour: _tour),
                                  ],
                                ),
                                SizedBox(height: 32.0),
                              ],
                            ),
                          ),
                          if (!_tour.isOfflineCreatedTour)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    'Created on ${_tour.createdDateTime!.toLocal().toString().split(' ')[0]} by:',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  TextButton(onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) =>
                                          TourguideUserProfileView(
                                              tourguideUserId: _tour.authorId,
                                              tourguideUserDisplayName: _tour.authorName)),
                                    );
                                  }, child: Text(_tour.authorName))
                                ],
                              ),
                            ),
                        ],
                      ),
                    )

                  ],
                ),
              )
            ],
          ),
          if (_isFullScreen)
            Positioned.fill(
              child: Stack(
                children: [
                  GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: _currentCameraPosition,
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (GoogleMapController controller) async {
                      if (!_mapControllerCompleter.isCompleted) {
                        _mapControllerCompleter.complete(controller);
                      } else {
                        final GoogleMapController mapController = await _mapControllerCompleter.future;
                        mapController.moveCamera(CameraUpdate.newCameraPosition(_currentCameraPosition));
                      }
                      await Future.delayed(const Duration(milliseconds: 300)); //avoid flicker
                      setState(() {
                        _isLoadingFullscreen = false;
                      });
                    },
                    onCameraMove: (CameraPosition position) {
                      _currentCameraPosition = position;
                    },
                  ),
                  if (_isLoadingFullscreen)
                    Container(
                      color: Color(0xffe8eaed),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (!_isLoadingFullscreen)
                    Positioned(
                      bottom: 120,
                      right: 10,
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: RawMaterialButton(
                          onPressed: () async {
                            final controller = await _mapControllerCompleter.future;
                            setState(() {
                              _isFullScreen = !_isFullScreen;
                            });
                            controller.moveCamera(
                              CameraUpdate.newCameraPosition(_currentCameraPosition),
                            );
                          },
                          elevation: 1.0,
                          fillColor: Colors.white.withOpacity(0.9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0), // Adjust the radius as needed
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(1.0), // Adjust inner padding as needed
                            child: Icon(
                              _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                              color: const Color(0xff666666),
                              size: 32.0, // Adjust the size of the icon as needed
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
        ),
      ),
    );
  }
}