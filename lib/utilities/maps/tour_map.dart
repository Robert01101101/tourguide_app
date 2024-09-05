import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/model/tourguide_place.dart';
import 'package:tourguide_app/tour/tour_tag.dart';
import 'package:tourguide_app/tour/tour_creation.dart';
import 'package:tourguide_app/tour/tour_details_options.dart';
import 'package:tourguide_app/tour/tourguide_user_profile_view.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/tour/tour_rating_bookmark_buttons.dart';
import 'package:tourguide_app/ui/tourguide_theme.dart';
import 'package:tourguide_app/utilities/maps/map_utils.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/singletons/tts_service.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:http/http.dart' as http;
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;

class TourMap extends StatefulWidget {
  final TourMapController tourMapController;
  final Tour tour;
  final Function(int step) onInfoTapped;
  final GlobalKey mapKey;
  final bool mapCurrentlyPinnedAtTop;
  
  const TourMap({
    super.key,
    required this.tourMapController,
    required this.tour,
    required this.onInfoTapped,
    required this.mapKey,
    required this.mapCurrentlyPinnedAtTop,
  });

  @override
  State<TourMap> createState() => _TourMapState();
}

class TourMapController {
  //VoidCallback? moveCameraToMarkerAndHighlightMarker;
  void Function(int step)? moveCameraToMarkerAndHighlightMarker;

  void triggerMoveCameraToMarkerAndHighlightMarker(int step) {
    if (moveCameraToMarkerAndHighlightMarker != null) {
      moveCameraToMarkerAndHighlightMarker!(step);
    }
  }
}

class _TourMapState extends State<TourMap> {
  final Completer<GoogleMapController> _mapControllerCompleter = Completer<GoogleMapController>();
  bool _isFullScreen = false;
  bool _isLoading = true, _isLoadingFullscreen = true;
  CameraPosition _currentCameraPosition = CameraPosition(
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



  @override
  void initState() {
    super.initState();

    // Assign the functions to the controller
    widget.tourMapController.moveCameraToMarkerAndHighlightMarker = (int step) {
      // Your logic to move the camera and highlight marker
      _moveCameraToMarkerAndHighlightMarker(step);
    };

    _addMarkers();
  }

  dispose() {
    widget.tourMapController.moveCameraToMarkerAndHighlightMarker = null;
    super.dispose();
  }
  
  
  

  Future<void> _addMarkers() async {
    // Clear previous bitmaps
    _defaultMarkerBitmaps.clear();
    _highlightedMarkerBitmaps.clear();

    //add tourguidePlace markers
    for (int i = 0; i < widget.tour.tourguidePlaces.length; i++) {
      TourguidePlace tourguidePlace = widget.tour.tourguidePlaces[i];

      // Create default and highlighted bitmaps
      final BitmapDescriptor defaultIcon = await MapUtils.createNumberedMarkerBitmap(i + 1);
      final BitmapDescriptor highlightedIcon = await MapUtils.createNumberedMarkerBitmap(i + 1, color: Theme.of(context).colorScheme.primary);

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
              widget.onInfoTapped(i);
              logger.i('Marker tapped: ${tourguidePlace.title}');
            },
          ),
        ),
      );
    }

    setState(() {
      _markers = _markers;
    });

    //set zoom
    LatLngBounds bounds = MapUtils.createLatLngBounds(widget.tour.tourguidePlaces.map((place) => LatLng(place.latitude, place.longitude)).toList());
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
    for (var tourguidePlace in widget.tour.tourguidePlaces) {
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
          List<LatLng> waypointLatLngs = widget.tour.tourguidePlaces
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

  void _moveCameraToMarkerAndHighlightMarker(int index) async {
    if (index >= 0 && index < _markers.length) {
      // Update the marker with the new bitmap
      setState(() {
        _markers = _markers.map((marker) {
          if (marker.markerId.value == widget.tour.tourguidePlaces[index].googleMapPlaceId) {
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
  
  
  @override
  Widget build(BuildContext context) {

    bool showMap = widget.tour.latitude != null && widget.tour.latitude != 0 && widget.tour.longitude != null && widget.tour.longitude != 0;
    if (showMap && _currentCameraPosition.target == LatLng(0, 0)) {
      _currentCameraPosition = CameraPosition(
        target: LatLng(widget.tour.latitude, widget.tour.longitude),
        zoom: 14.0,
      );
    }
    
    return Container(
      height: kIsWeb ? 450 : 350.0, // Adjust height as needed
      child: Stack(
        children: [
          if (showMap)  //TODO - understand why this is necessary - Google Map appears transparent in spots without it
            Container(
              color: Color(0xffe8eaed),
            ),
          if (showMap)
            GoogleMap(
              key: widget.mapKey,
              gestureRecognizers: widget.mapCurrentlyPinnedAtTop ? _gestureRecognizersEager : _gestureRecognizersPan,
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
    );
  }
}