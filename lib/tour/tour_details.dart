import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/model/tourguide_report.dart';
import 'package:tourguide_app/model/tourguide_user.dart';
import 'package:tourguide_app/tour/tour_creation.dart';
import 'package:tourguide_app/tour/tourguide_user_profile_view.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import '../utilities/custom_import.dart';
import 'package:http/http.dart' as http;
import '../utilities/singletons/tts_service.dart';
import 'tour_tile.dart'; // Ensure this imports your TileData model

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
    for (var tourguidePlace in widget.tour.tourguidePlaces) {
      _markers.add(
        Marker(
          markerId: MarkerId(tourguidePlace.googleMapPlaceId),
          position: LatLng(tourguidePlace.latitude, tourguidePlace.longitude),
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
    LatLngBounds bounds = _createLatLngBounds(widget.tour.tourguidePlaces.map((place) => LatLng(place.latitude, place.longitude)).toList());
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

  LatLngBounds _createLatLngBounds(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (LatLng point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
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

class TourDetailsOptions extends StatefulWidget {
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;
  final Tour tour;


  TourDetailsOptions({
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.tour,
  });

  @override
  State<TourDetailsOptions> createState() => _TourDetailsOptionsState();
}

//TODO: maybe find a better solution, state machine or something like that?
class _TourDetailsOptionsState extends State<TourDetailsOptions> {
  bool _isConfirmingDelete = false;
  bool _isReportingTour = false;
  bool _isViewingReports = false;
  bool _isRequestingReview = false;
  bool _isDeleteConfirmChecked = false;
  bool _isRequestReviewChecked = false;
  bool _reportSubmitted = false;
  String _selectedReportOption = '';
  final TextEditingController _reportDetailsController = TextEditingController();

  void _handleRadioValueChange(String? value) {
    setState(() {
      _selectedReportOption = value!;
    });
  }

  Future<void> _submitReport() async {
    if (_reportSubmitted) return;
    _reportSubmitted = true;
    String additionalDetails = _reportDetailsController.text;
    logger.t('Selected Option: $_selectedReportOption');
    logger.t('Additional Details: $additionalDetails');

    final tourguideUserProvider = Provider.of<TourguideUserProvider>(context, listen: false);
    TourguideReport report = TourguideReport(
      title: _selectedReportOption,
      additionalDetails: additionalDetails,
      reportAuthorId: tourguideUserProvider.user!.firebaseAuthId,
    );
    final TourguideUser? reportAuthor = await tourguideUserProvider.getUserInfo(widget.tour.authorId);
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    setState(() {
      tourProvider.reportTour(widget.tour, report, reportAuthor!);
    });

    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Thank You'),
          content: Text('Thank you for your report. We will review the content and take appropriate action if necessary.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestReview() async {
    logger.i('_requestReview()');

    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    tourProvider.requestReviewOfTour(widget.tour);

    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tour under Review'),
          content: const Text('Thank you for submitting your request for review. We will review the content and remove the reports if we deem the content to be in compliance with our community guidelines.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tourProvider = Provider.of<TourProvider>(context);
    bool isAuthor = tourProvider.isUserCreatedTour(widget.tour);
    return AlertDialog(
      title: Text(isAuthor ? (!_isConfirmingDelete ? (!_isViewingReports ? (!_isRequestingReview ? 'Author Options' : 'Request a Review') : 'Reports') : 'Delete Tour') : (!_isReportingTour ? 'Options' : 'Report Tour')),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Visibility( //Main Options
              visible: !_isConfirmingDelete && !_isReportingTour && !_isViewingReports && !_isRequestingReview,
              child: Column(
                children: [
                  if (isAuthor)
                    Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("You\'re the author of this tour."),
                            const SizedBox(height: 8.0),
                            if (widget.tour.reports.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 8.0),
                                  Text("Your tour was reported!", style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Theme.of(context).colorScheme.error)),
                                  if (widget.tour.requestReviewStatus.isNotEmpty)
                                    Column(
                                      children: [
                                        const SizedBox(height: 8.0),
                                        Text("You have requested a review, but we have not yet reviewed the reports.", style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),),
                                      ],
                                    ),
                                  const SizedBox(height: 8.0),
                                  const Text("There are reports for your tour, and it may be in violation of our community guidelines. Please review the reports and take appropriate action. In the meantime this tour is only visible to you."),
                                  const SizedBox(height: 8.0),
                                  const Text("If you believe you have addressed the reported issues, or that the reports are in error, you can request a review of your tour by selecting View Reports."),
                                  const SizedBox(height: 8.0),
                                  Align(
                                    alignment: Alignment.center,
                                    child: ElevatedButton.icon(
                                      onPressed: () => setState(() {
                                        _isViewingReports = true;
                                      }),
                                      icon: const Icon(Icons.report_outlined),
                                      label: const Text("View Reports"),
                                    ),
                                  ),
                                  const Divider(),
                                ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: widget.onEditPressed,
                        icon: const Icon(Icons.edit),
                        label: const Text("Edit Tour"),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isConfirmingDelete = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          //backgroundColor: Theme.of(context).colorScheme.error, // Background color of the button
                          foregroundColor: Theme.of(context).colorScheme.error, // Text color
                          side: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
                        ),
                        icon: const Icon(Icons.delete),
                        label: const Text("Delete Tour"),
                      ),
                    ],
                  )
                  else
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isReportingTour = true;
                            });
                          },
                          icon: const Icon(Icons.report),
                          label: const Text("Report Tour"),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Visibility( //Delete Confirmation Options
              visible: _isConfirmingDelete,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("Are you sure you'd like to delete this tour? This action cannot be undone.")),
                  ),
                  CheckboxListTile(
                    title: const Text("Confirm Delete"),
                    value: _isDeleteConfirmChecked,
                    onChanged: (bool? value) {
                      setState(() {
                        _isDeleteConfirmChecked = value ?? false;
                      });
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isDeleteConfirmChecked = false;
                        _isConfirmingDelete = false;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Cancel"),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isDeleteConfirmChecked ? widget.onDeletePressed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error, // Background color of the button
                      foregroundColor: Colors.white, // Text color
                    ),
                    icon: const Icon(Icons.delete),
                    label: const Text("Delete Tour Permanently"),
                  ),
                ],
              ),
            ),
            Visibility( //Report Options
              visible: _isReportingTour,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("Please select the reason why you are reporting this tour. Your feedback is important to us and will help us maintain a safe and respectful community.")),
                  ),
                  Divider(),
                  SizedBox(height: 16.0),
                  ReportOption(
                    title: 'Nudity or Sexual Content',
                    description: 'Contains nudity, sexual activity, or other sexually explicit material.',
                    groupValue: _selectedReportOption,
                    onChanged: _handleRadioValueChange,
                  ),
                  ReportOption(
                    title: 'Violence or Dangerous Behavior',
                    description: 'Promotes violence, self-harm, or dangerous behavior.',
                    groupValue: _selectedReportOption,
                    onChanged: _handleRadioValueChange,
                  ),
                  ReportOption(
                    title: 'Harassment or Hate Speech',
                    description: 'Includes harassment, hate speech, or abusive content.',
                    groupValue: _selectedReportOption,
                    onChanged: _handleRadioValueChange,
                  ),
                  ReportOption(
                    title: 'Spam or Misleading Information',
                    description: 'Contains spam, scams, or misleading information.',
                    groupValue: _selectedReportOption,
                    onChanged: _handleRadioValueChange,
                  ),
                  ReportOption(
                    title: 'Copyright Infringement',
                    description: 'Violates copyright laws or includes pirated content.',
                    groupValue: _selectedReportOption,
                    onChanged: _handleRadioValueChange,
                  ),
                  ReportOption(
                    title: 'Harmful or Abusive Content',
                    description: 'Contains harmful, abusive, or malicious content.',
                    groupValue: _selectedReportOption,
                    onChanged: _handleRadioValueChange,
                  ),
                  ReportOption(
                    title: 'Illegal Activities',
                    description: 'Promotes or involves illegal activities.',
                    groupValue: _selectedReportOption,
                    onChanged: _handleRadioValueChange,
                  ),
                  ReportOption(
                    title: 'Other',
                    description: 'Other reasons not listed above.',
                    groupValue: _selectedReportOption,
                    onChanged: _handleRadioValueChange,
                  ),
                  TextField(
                    controller: _reportDetailsController,
                    decoration: InputDecoration(labelText: 'Additional details (optional)'),
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                  ),
                ],
              ),
            ),
            Visibility( //Viewing Reports
              visible: _isViewingReports && !_isRequestingReview,
              child: Column(
                children: [
                  Column(
                    children:  widget.tour.reports.map((report) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Card(
                          child: ListTile(
                            title: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(report.title),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(report.additionalDetails),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 8.0),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isViewingReports = false;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Back"),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isRequestingReview = true;
                      });
                    },
                    icon: const Icon(Icons.account_balance),
                    label: const Text("Request a Review"),
                  ),
                ],
              ),
            ),
            Visibility( //Requesting Review
              visible: _isRequestingReview,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("Please only request a review of your tour once you have addressed the reported issues, or if you believe the reports are in error. Our team will review the reports and take appropriate action if necessary.")),
                  ),
                  CheckboxListTile(
                    title: const Text("Confirm Request"),
                    value: _isRequestReviewChecked,
                    onChanged: (bool? value) {
                      setState(() {
                        _isRequestReviewChecked = value ?? false;
                      });
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isRequestReviewChecked = false;
                        _isRequestingReview = false;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Cancel"),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isRequestReviewChecked ? _requestReview : null,
                    icon: const Icon(Icons.account_balance),
                    label: const Text("Request Review"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: !_isReportingTour ? null : [
        TextButton(
          child: Text('Cancel'),
          onPressed: () {
            setState(() {
              _isReportingTour = false;
            });
          },
        ),
        TextButton(
          child: Text('Submit Report'),
          onPressed: _submitReport,
        ),
      ],
    );
  }
}

class ReportOption extends StatelessWidget {
  final String title;
  final String description;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  ReportOption({required this.title, required this.description, required this.groupValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioListTile(
          title: Text(title),
          subtitle: Text(description),
          value: title,
          groupValue: groupValue,
          onChanged: onChanged,
        ),
        Divider(),
      ],
    );
  }
}