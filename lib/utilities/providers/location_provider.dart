import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/main.dart';

import '../../ui/google_places_image.dart';

/// Global Location Provider so I can access location anywhere in the app
class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  String _currentCity = '';
  String _currentState = '';
  String _currentCountry = '';
  String _placeId = '';
  late FlutterGooglePlacesSdk _places;

  Position? get currentPosition => _currentPosition;
  String get currentCity => _currentCity;
  String get currentState => _currentState;
  String get currentCountry => _currentCountry;
  String get placeId => _placeId;

  Map<String, GooglePlacesImg> _imageCache = {};

  LocationProvider() {
    print("LocationProvider()");
    _places = FlutterGooglePlacesSdk(MyGlobals.googleApiKey);
    _loadSavedLocation();
  }

  Future<void> getCurrentLocation() async {
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



    print("LocationProvider.getCurrentLocation()");
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      Position testPos = Position(
          latitude: 52.51253974139681,
          longitude: 13.405139039805762,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          headingAccuracy: 0,
          altitudeAccuracy: 0);
      _currentPosition = position; // = testPos;
      notifyListeners();

      await _getLocationDetailsFromCoordinates(position);
      await _saveLocation();
    } catch (e) {
      print(e);
    }
  }

  Future<void> _getLocationDetailsFromCoordinates(Position position) async {
    try {
      print("LocationProvider._getLocationDetailsFromCoordinates()");
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks != null && placemarks.isNotEmpty) {
        _currentCity = placemarks.first.locality ?? '';
        print("LocationProvider._getLocationDetailsFromCoordinates() - _currentCity=$_currentCity!");
        _currentState = placemarks.first.administrativeArea ?? '';
        _currentCountry = placemarks.first.country ?? '';
        notifyListeners();
      }

      // Get the Place ID using FlutterGooglePlacesSdk
      final result = await _places.findAutocompletePredictions(
        "$_currentCity, $_currentState, $_currentCountry",
        origin: LatLng(lat: position.latitude, lng: position.longitude),
      );

      print("LocationProvider._getLocationDetailsFromCoordinates() - result.predictions.first.placeId=${result.predictions.first.placeId}");

      if (result.predictions.isNotEmpty) {
        _placeId = result.predictions.first.placeId ?? '';
        notifyListeners();
      }

    } catch (e) {
      print(e);
    }
  }

  Future<void> _saveLocation() async {
    print("LocationProvider._saveLocation()");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_currentPosition != null) {
      prefs.setDouble('latitude', _currentPosition!.latitude);
      prefs.setDouble('longitude', _currentPosition!.longitude);
    }
    prefs.setString('city', _currentCity);
    prefs.setString('state', _currentState);
    prefs.setString('country', _currentCountry);
    prefs.setString('placeId', _placeId);
  }

  Future<void> _loadSavedLocation() async {
    print("LocationProvider._loadSavedLocation()");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double? latitude = prefs.getDouble('latitude');
    double? longitude = prefs.getDouble('longitude');
    if (latitude != null && longitude != null) {
      _currentPosition = Position(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          headingAccuracy: 0,
          altitudeAccuracy: 0
      );
    }
    _currentCity = prefs.getString('city') ?? '';
    _currentState = prefs.getString('state') ?? '';
    _currentCountry = prefs.getString('country') ?? '';
    _placeId = prefs.getString('placeId') ?? '';
    notifyListeners();
  }



  //from https://pub.dev/packages/flutter_google_places_sdk/example, with modifications for simplification & integration to location_provider
  Future<GooglePlacesImg?> fetchPlacePhoto() async {
    //Ensure id is loaded
    int attempts = 0;
    while (_placeId == null || _placeId == "") {
      await Future.delayed(Duration(milliseconds: 100));
      attempts++;
      if (attempts > 100) return null;
    }
    // Check the cache first
    if (_imageCache.containsKey(_placeId)) {
      return _imageCache[_placeId];
    }

    print("locationProvider._fetchPlacePhoto() - placeId=$_placeId");

    final result = await _places.fetchPlace(
      _placeId,
      fields: [PlaceField.PhotoMetadatas],
    );
    final place = result.place;

    if ((place?.photoMetadatas?.length ?? 0) == 0) {
      print("locationProvider._fetchPlacePhoto() - place or place.photoMetadatas is null");
    }

    try {
      final metadata = place?.photoMetadatas![0];
      final result = await _places.fetchPlacePhoto(metadata!);

      // Cache the image
      final googlePlacesImg = GooglePlacesImg(
        photoMetadata: metadata,
        placePhotoResponse: result,
      );
      _imageCache[_placeId!] = googlePlacesImg;

      return GooglePlacesImg(
          photoMetadata: metadata!, placePhotoResponse: result);

    } catch (err) {
      print("locationProvider._fetchPlacePhoto() - Exception occured: $err");
      return null;
    }
  }
}
