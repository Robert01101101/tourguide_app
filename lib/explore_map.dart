import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/utilities/maps/map_utils.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';

import 'main.dart';
import 'model/tour.dart';

class ExploreMap extends StatefulWidget {
  final List<Tour> tours;

  const ExploreMap({Key? key, required this.tours}) : super(key: key);

  @override
  _ExploreMapState createState() => _ExploreMapState();
}

class _ExploreMapState extends State<ExploreMap> {
  final Completer<GoogleMapController> _mapControllerCompleter = Completer<GoogleMapController>();
  bool _isLoading = true;
  CameraPosition _currentCameraPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.0,
  );
  Set<Marker> _markers = Set<Marker>();


  @override
  void initState() {
    super.initState();
    _addMarkers();
  }


  Future<void> _addMarkers() async {
    TourProvider tourProvider = Provider.of<TourProvider>(context, listen: false);

    //add tour markers
    for (int i = 0; i < widget.tours.length; i++) {
      logger.t("Adding marker for tour ${widget.tours[i].name}");
      Tour tour = widget.tours[i];
      _markers.add(
        Marker(
          markerId: MarkerId(tour.placeId),
          position: LatLng(tour.latitude, tour.longitude),
          //icon: icon,
          infoWindow: InfoWindow(
            title: tour.name,
            snippet: tour.description,
          ),
        ),
      );
    }

    setState(() {
      _markers = _markers;
    });

    //set zoom
    LatLngBounds bounds = MapUtils.createLatLngBounds(widget.tours.map((tour) => LatLng(tour.latitude, tour.longitude)).toList());
    final GoogleMapController controller = await _mapControllerCompleter.future;
    controller.moveCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Explore Map'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _currentCameraPosition,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) async {
              if (!_mapControllerCompleter.isCompleted) {
                _mapControllerCompleter.complete(controller);
              } else {
                final GoogleMapController mapController = await _mapControllerCompleter.future;
                mapController.moveCamera(CameraUpdate.newCameraPosition(_currentCameraPosition));
              }
              await Future.delayed(const Duration(milliseconds: 300)); //avoid flicker
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
        ],
      ),
    );
  }
}