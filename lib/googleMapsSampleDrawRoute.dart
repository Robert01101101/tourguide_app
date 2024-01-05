import 'package:geolocator/geolocator.dart';
import 'package:google_map_polyline_new/google_map_polyline_new.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

import 'package:tourguide_app/utilities/custom_import.dart';


// FROM FLUTTER SAMPLE
// MARK: Google Maps code snippet starts here

class MapSampleDrawRoute extends StatefulWidget {
  const MapSampleDrawRoute({super.key});

  @override
  State<MapSampleDrawRoute> createState() => MapSampleDrawRouteState();
}

class MapSampleDrawRouteState extends State<MapSampleDrawRoute> {
  final Completer<GoogleMapController> _controller =
  Completer<GoogleMapController>();

  static const CameraPosition _defaultPosition = CameraPosition(
      target: LatLng(49.28437653274791, -123.13028239792644),
      zoom: 14);

  Position ? _currentPosition;

  //do on page load
  @override
  void initState() {
    super.initState();

    //do nothing on init
  }



  //___________________ FROM: https://medium.com/@stefanodecillis/flutter-using-google-maps-and-drawing-routes-100829419faf

  //TODO - Fix potential security risk of API key exposed in code?
  GoogleMapPolyline googleMapPolyline = new GoogleMapPolyline(apiKey: "AIzaSyBa7mCp1FUiWMhfTHPWNJ2Cy-A84w4i2I4");
  final List<Polyline> polyline = [];
  final List<Marker> markersList = [];
  LatLng _originLocation = LatLng(49.273207950711786, -123.13215299686432);
  LatLng _destinationLocation = LatLng(49.29463670737591, -123.13658739855755);


  void _drawRouteOnMap() async {
    List<LatLng>? routeCoords =
    await googleMapPolyline.getCoordinatesWithLocation(
        origin: _originLocation,
        destination: _destinationLocation,
        mode: RouteMode.driving);

    Marker originMarker = Marker(
        markerId: const MarkerId('originMarker'),
        draggable: false,
        infoWindow: const InfoWindow(
          title: "This is where you will originate from",
        ),
        onTap: () {
          //print('this is where you will arrive');
        },
        position: _originLocation
    );

    Marker arrivalMarker = Marker(
        markerId: const MarkerId('arrivalMarker'),
        draggable: false,
        infoWindow: const InfoWindow(
          title: "This is where you will arrive",
        ),
        onTap: () {
          //print('this is where you will arrive');
        },
        position: _destinationLocation
    );

    markersList.add(originMarker);
    markersList.add(arrivalMarker);

    setState(() {
      polyline.add(Polyline(
          polylineId: PolylineId('testRouteId'),
          visible: true,
          points: routeCoords!,
          width: 4,
          color: Colors.blue,
          startCap: Cap.roundCap,
          endCap: Cap.buttCap
      ));
    });
  }



  //________________________________________________________________________________________ MapSample StatefulWidget - BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Routing'),
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: GoogleMap(
                mapType: MapType.hybrid,
                initialCameraPosition: _defaultPosition,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
                markers: Set.from(markersList),
                polylines: Set.from(polyline),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton(onPressed: _drawRouteOnMap, child: const Text("Draw Route")),
            const SizedBox(
              height: 20,
            ),
          ],
        )
      ),
    );
  }
}