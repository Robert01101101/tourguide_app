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
  bool _isFullScreen = false;

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

    // Check if latitude or longitude is null or zero
    bool showMap = tour.latitude != null && tour.latitude != 0 && tour.longitude != null && tour.longitude != 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tile.title),
      ),
      body: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.tile.imageUrl != null && widget.tile.imageUrl.isNotEmpty)
                        Container(
                          height: 250,
                          child: ClipRRect(
                            child: Image.network(
                              widget.tile.imageUrl,
                              width: MediaQuery.of(context).size.width,
                              height: 300.0, // Adjust height as needed
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16.0),
                      Text(
                        widget.tile.description,
                        style: const TextStyle(fontSize: 18.0),
                      ),
                      const SizedBox(height: 16.0),
                    ],
                  ),
                ),
                // Google Map
                if (showMap)
                Container(
                  height: 200.0, // Adjust height as needed
                  child: Stack(
                    children: [
                      GoogleMap(  //SHOULD ALIGN TO THE BOTTOM OF LAYOUT
                        mapType: MapType.normal,
                        initialCameraPosition: CameraPosition(
                          target: LatLng(tour.latitude, tour.longitude),
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
                      Positioned(
                        top: 10,
                        right: 10,
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: RawMaterialButton(
                            onPressed: () {
                              setState(() {
                                _isFullScreen = !_isFullScreen;
                              });
                            },
                            elevation: 2.0,
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
                // Add more content as needed
              ],
            ),
          ),
          // Fullscreen map overlay
          if (_isFullScreen)
            Positioned.fill(
              child: Stack(
                children: [
                  GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(tour.latitude, tour.longitude),
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
                    onMapCreated: (GoogleMapController controller) async {
                      if (!_controller.isCompleted) {
                        _controller.complete(controller);
                      } else {
                        final GoogleMapController mapController = await _controller.future;
                        controller = mapController;
                      }
                    },
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: RawMaterialButton(
                        onPressed: () {
                          setState(() {
                            _isFullScreen = !_isFullScreen;
                          });
                        },
                        elevation: 2.0,
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
    );
  }
}
