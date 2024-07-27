import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/model/tourguide_place.dart';
import 'package:tourguide_app/tour/tour_creation.dart';
import 'package:tourguide_app/tour/tour_details_options.dart';
import 'package:tourguide_app/tour/tourguide_user_profile_view.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/map_utils.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import '../utilities/custom_import.dart';
import 'package:http/http.dart' as http;
import '../utilities/singletons/tts_service.dart';

class FullscreenTourPage extends StatefulWidget {
  final Tour tour;

  const FullscreenTourPage({Key? key, required this.tour}) : super(key: key);

  @override
  State<FullscreenTourPage> createState() => _FullscreenTourPageState();
}

class _FullscreenTourPageState extends State<FullscreenTourPage> {
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


  @override
  void initState() {
    super.initState();
    _addMarkers();
  }



  Future<void> _addMarkers() async {
    // Add tour city marker
    /*
    _markers.add(
      Marker(
        markerId: MarkerId(widget.tour.id),
        position: LatLng(widget.tour.latitude, widget.tour.longitude),
        infoWindow: InfoWindow(
          title: widget.tour.name,
          snippet: widget.tour.description,
        ),
      ),
    );*/

    //add tourguidePlace markers
    for (int i = 0; i < widget.tour.tourguidePlaces.length; i++) {
      TourguidePlace tourguidePlace = widget.tour.tourguidePlaces[i];
      final BitmapDescriptor icon = await MapUtils.createNumberedMarkerBitmap(i + 1);
      _markers.add(
        Marker(
          markerId: MarkerId(tourguidePlace.googleMapPlaceId),
          position: LatLng(tourguidePlace.latitude, tourguidePlace.longitude),
          icon: icon,
          infoWindow: InfoWindow(
            title: tourguidePlace.title,
            snippet: tourguidePlace.description,
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

    //TODO: Sometimes placeId works better, sometimes lat long, with placeIds it seems walking mode can be tricky -> address

    // Construct directions API URL
    int attempt = 0;
    while (attempt < 2) {
      try {
        attempt++;
        String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        //'origin=${waypoints.first.latitude},${waypoints.last.longitude}&'
        //'destination=${waypoints.last.latitude},${waypoints.last.longitude}&'
            'origin=place_id:${waypoints.first}&'
            'destination=place_id:${waypoints.last}&'
            '${waypointsString.isNotEmpty ? 'waypoints=$waypointsString&' : waypointsString}'
            'mode=${attempt == 1 ? 'walking&' : 'driving&'}'
            'key=$apiKey';

        //logger.i(url);

        final response = await http.get(Uri.parse(url));

        //logger.i(response.body);

        if (response.statusCode == 200) {
          Map<String, dynamic> data = jsonDecode(response.body);

          // Check the status field
          String status = data['status'];

          if (status == 'ZERO_RESULTS') {
            // Handle case where no results were found
            logger.w('No results found for the given waypoints. Trying again with driving directions.');
            continue;
          }
          List<LatLng> points = _decodePolyline(data['routes'][0]['overview_polyline']['points']);
          _addPolyline(points);
          break;
        } else {
          throw Exception('Failed to load directions');
        }
      } catch (e) {
        logger.e('Failed to get directions: $e');
        attempt++;
      }
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
               MaterialPageRoute(builder: (context) => CreateEditTour(isEditMode: true,tour: widget.tour.copyWith(isOfflineCreatedTour: true))),
            );
          },
          onDeletePressed: () {
            // Handle delete button press
            Navigator.of(context).pop(); // Close the dialog
            _deleteTour();
          },
          tour: widget.tour,
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
      await tourProvider.deleteTour(widget.tour);
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



  @override
  Widget build(BuildContext context) {
    final tourProvider = Provider.of<TourProvider>(context);

    bool showMap = widget.tour.latitude != null && widget.tour.latitude != 0 && widget.tour.longitude != null && widget.tour.longitude != 0;
    if (showMap && _currentCameraPosition.target == LatLng(0, 0)) {
      _currentCameraPosition = CameraPosition(
        target: LatLng(widget.tour.latitude, widget.tour.longitude),
        zoom: 14.0,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tour.name),
        actions:
          [
            if (!widget.tour.isOfflineCreatedTour)
              IconButton(
              icon: Icon(Icons.more_vert),
              onPressed: () {
                  // Show options menu
                  _showOptionsDialog(context);
                },
              ),
          ],
        leading: _isFullScreen
            ? IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isFullScreen = false;
            });
          },
        )
            : null,
      ),
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
          children: [
            Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: StandardLayout(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.tour.imageUrl != null && widget.tour.imageUrl.isNotEmpty || widget.tour.isOfflineCreatedTour && widget.tour.imageToUpload != null)
                          Stack(
                            children: [
                              Container(
                                height: 230,
                                child: ClipRRect(
                                  child: widget.tour.isOfflineCreatedTour && widget.tour.imageToUpload != null  //add null safety for img to upload
                                  ? Image.file(widget.tour.imageToUpload!,
                                      width: MediaQuery.of(context).size.width,
                                      height: 200.0,
                                      fit: BoxFit.cover)
                                  : Image.network(
                                      widget.tour.imageUrl,
                                      width: MediaQuery.of(context).size.width,
                                      height: 230.0, // Adjust height as needed
                                      fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              if (tourProvider.isUserCreatedTour(widget.tour))
                                Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (widget.tour.reports.isNotEmpty)
                                            const CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Colors.black45,
                                              child: Icon(
                                                Icons.report_outlined,
                                                color: Colors.yellow,
                                                size: 22,),
                                            ),
                                          const CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.black45,
                                            child: Icon(
                                              Icons.attribution,
                                              color: Colors.white,),
                                          ),
                                        ],
                                      ),
                                    )),
                            ],
                          ),
                        const SizedBox(height: 16.0),
                        Container(
                          height: 105,
                          child: Text(
                            widget.tour.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    if (showMap)
                      Container(
                        height: 260.0, // Adjust height as needed
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
                    Text(
                      'Places you\'ll visit',
                      style: Theme.of(context).textTheme.titleLarge
                    ),
                    if (widget.tour.tourguidePlaces.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.tour.tourguidePlaces.map((place) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      place.title,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(
                                      place.description, // Assuming each place has a 'description' field
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                                IconButton(
                                    onPressed: () => _ttsService.speak(place.description),
                                    icon: Icon(Icons.play_circle),
                                )
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    if (!widget.tour.isOfflineCreatedTour)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'Created on ${widget.tour.createdDateTime!.toLocal().toString().split(' ')[0]} by:',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) =>
                                  TourguideUserProfileView(
                                      tourguideUserId: widget.tour.authorId,
                                      tourguideUserDisplayName: widget.tour.authorName)),
                            );
                          }, child: Text(widget.tour.authorName))
                        ],
                      ),
                  ],
                ),
              ),
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