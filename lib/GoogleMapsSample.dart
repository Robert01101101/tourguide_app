import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:tourguide_app/secondScreenTest.dart';


// FROM FLUTTER SAMPLE
// MARK: Google Maps code snippet starts here

class MapSample extends StatefulWidget {
  const MapSample({super.key});

  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
  final Completer<GoogleMapController> _controller =
  Completer<GoogleMapController>();

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  static const CameraPosition _kLake = CameraPosition(
      bearing: 192.8334901395799,
      target: LatLng(37.43296265331129, -122.08832357078792),
      tilt: 59.440717697143555,
      zoom: 19.151926040649414);


  int _counter = 0;
  Position ? _currentPosition;

  //do on page load
  @override
  void initState() {
    super.initState();
    _determinePosition();
  }


  /// Determine the current position of the device.
  ///
  /// When the location services are not enabled or permissions
  /// are denied the `Future` will return an error.
  void _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    Position newPosition =  await Geolocator.getCurrentPosition();

    setState(() {
      _currentPosition = newPosition;
    });
  }

  Future<void> _goToTheLake() async {
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(_kLake));
  }

  Future<void> _goToGoogleHq() async {
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(_kGooglePlex));
  }

  Future<void> _goToMyLocation() async {
    final GoogleMapController controller = await _controller.future;
    CameraPosition kMyLocation = CameraPosition(
      target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      zoom: 14.4746,
    );
    await controller.animateCamera(CameraUpdate.newCameraPosition(kMyLocation));
  }

  //________________________________________________________________________________________ MapSample StatefulWidget - BUILD
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 600,
      child: Column(
        children: [
          Expanded(
            child: GoogleMap(
              mapType: MapType.hybrid,
              initialCameraPosition: _kLake,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          const Text(
            'Your current GPS Location is:',
          ),
          _currentPosition != null
              ? Text(
            'LAT: ${(_currentPosition!!).latitude}, \n LNG: ${(_currentPosition!!).longitude}',//cast to non nullable
            style: TextStyle(fontSize: 24),
          )
              : CircularProgressIndicator(),
          const SizedBox(
            height: 80,
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,children: [
            ElevatedButton(onPressed: _goToMyLocation, child: const Text("My Location")),
            ElevatedButton(onPressed: _goToGoogleHq, child: const Text("Google's HQ")),
            ElevatedButton(onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecondRoute()),
              );
            }, child: const Text("Route 2")),
          ],)
        ],
      ),
    );
  }
}

// MARK: Google Maps code snippet ends here










// FROM GOOGLE SAMPLE https://codelabs.developers.google.com/codelabs/google-maps-in-flutter#3