import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import '../utilities/custom_import.dart';
import 'rounded_tile.dart'; // Ensure this imports your TileData model

class FullscreenTourPage extends StatefulWidget {
  final TileData tile;

  const FullscreenTourPage({Key? key, required this.tile}) : super(key: key);

  @override
  State<FullscreenTourPage> createState() => _FullscreenTourPageState();
}

class _FullscreenTourPageState extends State<FullscreenTourPage> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  @override
  Widget build(BuildContext context) {
    final tourProvider = Provider.of<TourProvider>(context);
    final tour = tourProvider.selectedTour;

    if (tour == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.tile.title)),
        body: Center(child: Text('No tour selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tile.title),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.tile.imageUrl != null && widget.tile.imageUrl.isNotEmpty)
                Image.network(
                  widget.tile.imageUrl,
                  width: MediaQuery.of(context).size.width,
                  height: 300.0, // Adjust height as needed
                  fit: BoxFit.cover,
                ),
              const SizedBox(height: 16.0),
              Text(
                widget.tile.description,
                style: const TextStyle(fontSize: 18.0),
              ),
              const SizedBox(height: 16.0),
              // Google Map
              Container(
                height: 300.0, // Adjust height as needed
                child: GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(49.1836983, -122.843655), //_originLatitude = 6.5212402, _originLongitude = 3.3679965;
                    zoom: 13.0,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId(tour.id),
                      position: LatLng(tour.latitude, tour.longitude),
                      infoWindow: InfoWindow(
                        title: tour.name,
                        snippet: tour.description,
                      ),
                    ),
                  },
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                ),
                /*GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(tour.latitude, tour.longitude),
                    zoom: 14.0,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId(tour.id),
                      position: LatLng(tour.latitude, tour.longitude),
                      infoWindow: InfoWindow(
                        title: tour.name,
                        snippet: tour.description,
                      ),
                    ),
                  },
                ),*/
              ),
              const SizedBox(height: 16.0),
              // Add more content as needed
            ],
          ),
        ),
      ),
    );
  }
}
