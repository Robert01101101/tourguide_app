import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global Location Provider so I can access location anywhere in the app
class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  String _currentCity = '';
  String _currentState = '';
  String _currentCountry = '';

  Position? get currentPosition => _currentPosition;
  String get currentCity => _currentCity;
  String get currentState => _currentState;
  String get currentCountry => _currentCountry;

  LocationProvider() {
    print("LocationProvider()");
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
    notifyListeners();
  }

  /*Future<String> _getCity() async {
    await Future.delayed(Duration(seconds: 2)); // Simulate a network call
    return "Hello, Async World!";
  }*/
}