import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/model/tourguide_place.dart';
import 'package:tourguide_app/utilities/maps/map_utils.dart';
import 'package:http/http.dart' as http;

class TourMapController with ChangeNotifier {
  //VoidCallback? moveCameraToMarkerAndHighlightMarker;
  void Function(int step)? moveCameraToMarkerAndHighlightMarker;
  void Function(BuildContext context)? showOptionsDialog;
  Function(int step)? _onInfoTapped;
  Color? _primaryColor;

  TourMapController() {
    logger.t('TourMapController() - hashCode=$hashCode');
  }

  @override
  void dispose() {
    super.dispose();
    logger.t('dispose - hashCode=$hashCode');
    resetTourMapController();
  }

  void triggerMoveCameraToMarkerAndHighlightMarker(int step) {
    //logger.t('triggerMoveCameraToMarkerAndHighlightMarker - step=$step');
    if (moveCameraToMarkerAndHighlightMarker != null) {
      moveCameraToMarkerAndHighlightMarker!(step);
    }
  }

  void triggerShowOptionsDialog(BuildContext context) {
    //logger.t('triggerShowOptionsDialog');
    if (showOptionsDialog != null) {
      showOptionsDialog!(context);
    }
  }

  void triggerOnInfoTapped(int step) {
    //logger.t('triggerOnInfoTapped - step=$step');
    if (_onInfoTapped != null) {
      _onInfoTapped!(step);
    }
  }

  void initTourMapController({
    required Tour tour,
    required Color primaryColor,
    required Function(int step)
    onInfoTapped,
    required Function(BuildContext context) showOptionsDialog
  }) {
    logger.t('initTourMapController - hashCode=$hashCode');
    _tour = tour;
    _primaryColor = primaryColor;
    _onInfoTapped = onInfoTapped;
    _addMarkers();

    _currentCameraPosition = CameraPosition(
      target: LatLng(tour.latitude, tour.longitude),
      zoom: 14.0,
    );

    moveCameraToMarkerAndHighlightMarker = (int step) {
      // Your logic to move the camera and highlight marker
      _moveCameraToMarkerAndHighlightMarker(step);
    };
  }

  void resetTourMapController(){
    logger.t('resetTourMapController - hashCode=$hashCode');
    moveCameraToMarkerAndHighlightMarker = null;
    _tour = Tour.empty();
    _markers = Set<Marker>();
    _polylines = Set<Polyline>();
    _defaultMarkerBitmaps = [];
    _highlightedMarkerBitmaps = [];
    _routeSegments = [];
  }








  Tour _tour = Tour.empty();
  final Completer<GoogleMapController> _mapControllerCompleter = Completer<GoogleMapController>();
  bool _isFullScreen = false;
  bool _isLoading = true, _isLoadingFullscreen = true;
  CameraPosition _currentCameraPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.0,
  );
  CameraPosition _lastCameraPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.0,
  );
  Set<Marker> _markers = Set<Marker>();
  Set<Polyline> _polylines = Set<Polyline>();
  List<BitmapDescriptor> _defaultMarkerBitmaps = [];
  List<BitmapDescriptor> _highlightedMarkerBitmaps = [];
  List<List<LatLng>> _routeSegments = [];
  int thisUsersRating = 0;
  final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizersEager = {
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())
  };
  final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizersPan = {
    Factory<PanGestureRecognizer>(() => PanGestureRecognizer())
  };

  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  Completer<GoogleMapController> get mapControllerCompleter => _mapControllerCompleter;
  bool get isFullScreen => _isFullScreen;
  bool get isLoading => _isLoading;
  bool get isLoadingFullscreen => _isLoadingFullscreen;
  CameraPosition get currentCameraPosition => _currentCameraPosition;

  void setFullScreen(bool isFullScreen) {
    //logger.t('setFullScreen - isFullScreen=$isFullScreen');
    _isFullScreen = isFullScreen;
    notifyListeners();
  }

  void setLoading(bool isLoading) {
    //logger.t('setLoading - isLoading=$isLoading');
    _isLoading = isLoading;
    notifyListeners();
  }

  void setLoadingFullscreen(bool isLoadingFullscreen) {
    //logger.t('setLoadingFullscreen - isLoadingFullscreen=$isLoadingFullscreen');
    _isLoadingFullscreen = isLoadingFullscreen;
    notifyListeners();
  }

  void setCurrentCameraPosition(CameraPosition position) {
    //logger.t('setCurrentCameraPosition - position=$position');
    _currentCameraPosition = position;
    //notifyListeners();
  }

  void notifyCurrentCameraPosition() {
    if (_currentCameraPosition != _lastCameraPosition) {
      //logger.t('notifyCurrentCameraPosition - _currentCameraPosition=$_currentCameraPosition');
      _lastCameraPosition = _currentCameraPosition;
      notifyListeners();
    }
  }




  Future<void> _addMarkers() async {
    logger.t('_addMarkers');
    try {
      // Clear previous bitmaps
      _defaultMarkerBitmaps.clear();
      _highlightedMarkerBitmaps.clear();

      //add tourguidePlace markers
      for (int i = 0; i < _tour.tourguidePlaces.length; i++) {
        TourguidePlace tourguidePlace = _tour.tourguidePlaces[i];

        // Create default and highlighted bitmaps
        final BitmapDescriptor defaultIcon = await MapUtils.createNumberedMarkerBitmap(i + 1);
        final BitmapDescriptor highlightedIcon = await MapUtils.createNumberedMarkerBitmap(i + 1, color: _primaryColor!);

        // Store the bitmaps in the lists
        _defaultMarkerBitmaps.add(defaultIcon);
        _highlightedMarkerBitmaps.add(highlightedIcon);


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
                //_setStep(i);
                triggerOnInfoTapped(i);
                logger.i('Marker tapped: ${tourguidePlace.title}');
              },
            ),
          ),
        );
      }

      //set zoom
      LatLngBounds bounds = MapUtils.createLatLngBounds(_tour.tourguidePlaces.map((place) => LatLng(place.latitude, place.longitude)).toList());
      final GoogleMapController controller = await _mapControllerCompleter.future;
      controller.moveCamera(CameraUpdate.newLatLngBounds(bounds, 50));

      // Fetch directions and draw polyline
      _fetchDirections();
    } catch (e, stack) {
      logger.e('Failed to add markers: $e \n $stack');
    }
  }

  Future<void> _fetchDirections() async {
    logger.t('_fetchDirections');
    List<String> waypoints = [];
    String waypointsString = "";
    String apiKey = remoteConfig.getString('google_api_key');
    try {
      // Prepare waypoints for directions API request
      //List<LatLng> waypoints = [];

      for (var tourguidePlace in _tour.tourguidePlaces) {
        //waypoints.add(LatLng(tourguidePlace.latitude, tourguidePlace.longitude));
        waypoints.add(tourguidePlace.googleMapPlaceId);
      }

      //TODO: Address higher rate billing for 10+ waypoints
      // Create waypoints string for API request

      if (waypoints.length > 2){
        /*waypointsString = waypoints.sublist(1, waypoints.length - 1)
          .map((point) => 'via:${point.latitude},${point.longitude}')
          .join('|');*/
        waypointsString = waypoints.sublist(1, waypoints.length - 1)
            .map((point) => 'via:place_id:${point}')
            .join('|');
      }

      logger.t('Waypoints.length: ${waypoints.length}');
    } catch (e, stack) {
      logger.e('Failed to prepare to get directions: $e \n $stack');
    }

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
    logger.t('_findWaypointIndices');
    try {
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
    } catch (e, stack) {
      logger.e('Failed to find waypoint indices: $e \n $stack');
      return [];
    }
  }

  List<List<LatLng>> _createRouteSegments(List<LatLng> points, List<LatLng> waypoints) {
    logger.t('_createRouteSegments');
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
    try {
      logger.t('_decodePolyline');
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
    } catch (e, stack) {
      logger.e('Failed to decode polyline: $e \n $stack');
      return [];
    }
  }

  void _addPolyline(List<LatLng> polylineCoordinates) {
    logger.t('_addPolyline');
    _polylines.add(
      Polyline(
        polylineId: PolylineId('Route'),
        color: Colors.blue,
        width: 5,
        points: polylineCoordinates,
      ),
    );

    //setState(() {
      _polylines = _polylines;
      notifyListeners();
    //});
  }

  void _moveCameraToMarkerAndHighlightMarker(int index) async {
    if (index >= 0 && index < _markers.length) {
      // Update the marker with the new bitmap
      //setState(() {
        _markers = _markers.map((marker) {
          if (marker.markerId.value == _tour.tourguidePlaces[index].googleMapPlaceId) {
            // Use the highlighted bitmap for the selected marker
            return marker.copyWith(iconParam: _highlightedMarkerBitmaps[index]);
          } else {
            // Use the default bitmap for other markers
            return marker.copyWith(iconParam: _defaultMarkerBitmaps[_markers.toList().indexOf(marker)]);
          }
        }).toSet();
      //});

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
    Color colPrimary = _primaryColor!;

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

    //setState(() {
      _polylines = _polylines;
      notifyListeners();
    //});
  }
}

/// NOTE: not using ChangeNotifierProvider atm, because nesting it was causing problems as it's not how it's intended to be used
/// as a result, I'm not sure whether this is safe to use without nesting inside a TourMapFullscreen atm
class TourMap extends StatefulWidget {
  final TourMapController tourMapController;
  final Tour tour;
  final GlobalKey mapKey;
  final bool mapCurrentlyPinnedAtTop;

  const TourMap({
    super.key,
    required this.tourMapController,
    required this.tour,
    required this.mapKey,
    required this.mapCurrentlyPinnedAtTop,
  });

  @override
  State<TourMap> createState() => _TourMapState();
}


class _TourMapState extends State<TourMap> {
  int thisUsersRating = 0;
  final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizersEager = {
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())
  };
  final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizersPan = {
    Factory<PanGestureRecognizer>(() => PanGestureRecognizer())
  };


  @override
  void dispose() {
    //widget.tourMapController.dispose(); // Make sure to dispose the controller
    super.dispose();
  }
  
  
  @override
  Widget build(BuildContext context) {
    //logger.t('TourMap - build');
    return Consumer<TourMapController>(
      builder: (context, tourMapController, child) {
        //logger.t('TourMap - Consumer');
        return Container(
          height: kIsWeb ? 450 : 350.0, // Adjust height as needed
          child: Stack(
            children: [
                Container( //backdrop TODO - investigate why this is needed, otherwise sometimes I can see thru the map
                  color: Color(0xffe8eaed),
                ),
                GoogleMap(
                  key: widget.mapKey,
                  gestureRecognizers: widget.mapCurrentlyPinnedAtTop ? _gestureRecognizersEager : _gestureRecognizersPan,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  initialCameraPosition: widget.tourMapController.currentCameraPosition,
                  markers: widget.tourMapController.markers,
                  polylines: widget.tourMapController.polylines,
                  onMapCreated: (GoogleMapController controller) async {
                    if (!widget.tourMapController.mapControllerCompleter.isCompleted) {
                      widget.tourMapController.mapControllerCompleter.complete(controller);
                    } else {
                      final GoogleMapController mapController = await widget.tourMapController.mapControllerCompleter.future;
                      mapController.moveCamera(CameraUpdate.newCameraPosition(widget.tourMapController.currentCameraPosition));
                    }
                    await Future.delayed(const Duration(milliseconds: 200)); //avoid flicker
                    widget.tourMapController.setLoading(false);
                  },
                  onCameraMove: (CameraPosition position) {
                    widget.tourMapController.setCurrentCameraPosition(position);
                  },
                  onCameraIdle: () {
                    widget.tourMapController.notifyCurrentCameraPosition();
                  },
                ),
                if (widget.tourMapController.isLoading)
                Container(
                  color: Color(0xffe8eaed),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (!widget.tourMapController.isLoading)
                Positioned(
                  bottom: 120,
                  right: 10,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: RawMaterialButton(
                      onPressed: () async {
                        final controller = await widget.tourMapController.mapControllerCompleter.future;
                        widget.tourMapController.setFullScreen(!widget.tourMapController.isFullScreen);
                        widget.tourMapController.setLoadingFullscreen(true);
                        controller.moveCamera(
                          CameraUpdate.newCameraPosition(widget.tourMapController.currentCameraPosition),
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
                          widget.tourMapController.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          color: const Color(0xff666666),
                          size: 32.0, // Adjust the size of the icon as needed
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class TourMapFullscreen extends StatefulWidget {
  final TourMapController tourMapController;
  final Tour tour;
  final Widget child;

  const TourMapFullscreen({
    super.key,
    required this.tourMapController,
    required this.tour,
    required this.child,
  });

  @override
  State<TourMapFullscreen> createState() => _TourMapFullscreenState();
}


class _TourMapFullscreenState extends State<TourMapFullscreen> {
  int thisUsersRating = 0;


  @override
  void dispose() {
    //widget.tourMapController.dispose(); // Make sure to dispose the controller
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    //logger.t('TourMapFullscreen - build');
    return ChangeNotifierProvider(
      create: (_) => widget.tourMapController,
      child: Consumer<TourMapController>(
        builder: (context, tourMapController, child) {
          //logger.t('TourMapFullscreen - Consumer');
          return Scaffold(
            appBar: widget.tourMapController.isFullScreen ? AppBar(
              title: Text(widget.tour.name),
              actions:
              [
                if (!(widget.tour.isOfflineCreatedTour ?? false))
                  IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () {
                      // Show options menu
                      widget.tourMapController.triggerShowOptionsDialog(context);
                    },
                  ),
              ],
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  widget.tourMapController.setFullScreen(false);
                },
              ),
            ) : null,
            body: PopScope(
              canPop: !widget.tourMapController.isFullScreen,
              onPopInvoked: (bool didPop) {
                if (!didPop && widget.tourMapController.isFullScreen){
                  widget.tourMapController.setFullScreen(false);
                }
              },
              child: Stack(
                children: [
                  widget.child,
                  if (widget.tourMapController.isFullScreen)
                    Positioned.fill(
                      child: Stack(
                        children: [
                          GoogleMap(
                            mapType: MapType.normal,
                            initialCameraPosition: widget.tourMapController.currentCameraPosition,
                            markers: widget.tourMapController.markers,
                            polylines: widget.tourMapController.polylines,
                            onMapCreated: (GoogleMapController controller) async {
                              if (!widget.tourMapController.mapControllerCompleter.isCompleted) {
                                widget.tourMapController.mapControllerCompleter.complete(controller);
                              } else {
                                final GoogleMapController mapController = await widget.tourMapController.mapControllerCompleter.future;
                                mapController.moveCamera(CameraUpdate.newCameraPosition(widget.tourMapController.currentCameraPosition));
                              }
                              await Future.delayed(const Duration(milliseconds: 300)); //avoid flicker
                              widget.tourMapController.setLoadingFullscreen(false);
                            },
                            onCameraMove: (CameraPosition position) {
                              widget.tourMapController.setCurrentCameraPosition(position);
                            },
                            onCameraIdle: () {
                              widget.tourMapController.notifyCurrentCameraPosition();
                            },
                          ),
                          if (widget.tourMapController.isLoadingFullscreen)
                            Container(
                              color: Color(0xffe8eaed),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          if (!widget.tourMapController.isLoadingFullscreen)
                            Positioned(
                              bottom: 120,
                              right: 10,
                              child: SizedBox(
                                width: 42,
                                height: 42,
                                child: RawMaterialButton(
                                  onPressed: () async {
                                    final controller = await widget.tourMapController.mapControllerCompleter.future;
                                    widget.tourMapController.setFullScreen(!widget.tourMapController.isFullScreen);
                                    controller.moveCamera(
                                      CameraUpdate.newCameraPosition(widget.tourMapController.currentCameraPosition),
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
                                      widget.tourMapController.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
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
              )
            ),
          );
        },
      ),
    );
  }
}