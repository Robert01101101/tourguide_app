import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/main.dart';

import '../uiElements/google_places_image.dart';

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
    print("LocationProvider.getCurrentLocation()");
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;
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
        _currentCity,
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












  //GOOGLE MAPS COVER PHOTO
  /*
  Future<FetchPlacePhotoResponse?> fetchCoverPhotoUrl(String placeId) async {
    print('PlaceService.fetchCoverPhotoUrl($placeId)');
    try {
      final result  = await _places.fetchPlace(placeId, fields: [PlaceField.PhotoMetadatas]);
      final place = result.place;

      await _fetchPlacePhoto(place!);
      return _placePhoto;
    } catch (e) {
      print('Exception fetching place details: $e');
      return null;
    }
  }

  bool _fetchingPlacePhoto = false;
  FetchPlacePhotoResponse? _placePhoto;
  PhotoMetadata? _placePhotoMetadata;
  dynamic _fetchingPlacePhotoErr;
  //from https://pub.dev/packages/flutter_google_places_sdk/example
  _fetchPlacePhoto(Place place) async {
    print('PlaceService._fetchPlacePhoto()');
    if (_fetchingPlacePhoto || place == null) {
      return;
    }

    print('PlaceService._fetchPlacePhoto() - starting');
    if ((place.photoMetadatas?.length ?? 0) == 0) {
      //setState(() {
      _fetchingPlacePhoto = false;
      _fetchingPlacePhotoErr = "No photos for place";
      print(_fetchingPlacePhotoErr);
      //});
      return;
    }

    print('PlaceService._fetchPlacePhoto() - photos found');

    //setState(() {
    _fetchingPlacePhoto = true;
    _fetchingPlacePhotoErr = null;
    //});

    try {
      final metadata = place.photoMetadatas![0];

      print('PlaceService._fetchPlacePhoto() - fetching photo');
      final result = await _places.fetchPlacePhoto(metadata);

      //setState(() {
      _placePhoto = result;
      _placePhotoMetadata = metadata;
      _fetchingPlacePhoto = false;
      //});
      return;
    } catch (err) {
      //setState(() {
      _fetchingPlacePhotoErr = err;
      _fetchingPlacePhoto = false;
      //});
      print(_fetchingPlacePhotoErr);
      return;
    }
  }*/




  //NEW from chatgpt based on locationProvider as starting point
  /*
  Future<void> _getCoverPhotoUrl(String placeId) async {
    try {
      print("LocationProvider._getCoverPhotoUrl()");
      final details = await _places.fetchPlace(
        placeId,
        fields: [PlaceField.PhotoMetadatas],
      );

      if (details.place.photos != null && details.place.photos!.isNotEmpty) {
        final photoReference = details.place.photos!.first.photoReference;
        _coverPhotoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=${MyGlobals.googleApiKey}';
        notifyListeners();
      }
    } catch (e) {
      print(e);
    }
  }
  */





  //from https://pub.dev/packages/flutter_google_places_sdk/example, with modifications for simplification & integration to location_provider
  Future<GooglePlacesImg?> fetchPlacePhoto() async {
    //Ensure id is loaded
    int attempts = 0;
    while (_placeId == null || _placeId == "") {
      await Future.delayed(Duration(milliseconds: 100));
      attempts++;
      if (attempts > 30) return null;
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
