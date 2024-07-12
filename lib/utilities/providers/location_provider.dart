import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/main.dart';
import 'dart:convert';


import '../../ui/google_places_image.dart';

//TODO: Handle all types of errors as well as permission denied
/// Global Location Provider so I can access location anywhere in the app
class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  String _currentCity = '';
  String _currentState = '';
  String _currentCountry = '';
  String _placeId = '';
  late FlutterGooglePlacesSdk _places;
  GooglePlacesImg? _currentPlaceImg;

  Position? get currentPosition => _currentPosition;
  String get currentCity => _currentCity;
  String get currentState => _currentState;
  String get currentCountry => _currentCountry;
  String get placeId => _placeId;
  GooglePlacesImg? get currentPlaceImg => _currentPlaceImg;

  Map<String, GooglePlacesImg> _imageCache = {};

  LocationProvider() {
    _init();
  }

  // Initialization method
  Future<void> _init() async {
    logger.t("LocationProvider._init()");
    // Wait for remoteConfig to fetch and activate
    await remoteConfig.fetchAndActivate();

    //logger.t("LocationProvider()");
    _places = FlutterGooglePlacesSdk(remoteConfig.getString('google_api_key')!);
    _loadSavedLocation();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    logger.t("LocationProvider.getCurrentLocation()");
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
      notifyListeners();
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> _getLocationDetailsFromCoordinates(Position position) async {
    try {
      //logger.t("LocationProvider._getLocationDetailsFromCoordinates()");
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks != null && placemarks.isNotEmpty) {
        _currentCity = placemarks.first.locality ?? '';
        logger.t("LocationProvider._getLocationDetailsFromCoordinates() - _currentCity=$_currentCity!");
        _currentState = placemarks.first.administrativeArea ?? '';
        _currentCountry = placemarks.first.country ?? '';
        notifyListeners();
      }

      var resultSorted = await getAutocompleteSuggestions("$_currentCity, $_currentState, $_currentCountry");

      if (resultSorted != null && resultSorted.isNotEmpty) {
        _placeId = resultSorted.first.placeId ?? '';
        notifyListeners();
      }

    } catch (e) {
      logger.e(e);
    }
  }

  Future<Place?> getLocationDetailsFromPlaceId(String placeId, {bool setAsCurrentPlace = false}) async {
    try {
      final placeDetails = await _places.fetchPlace(
        placeId,
        fields: [ //Option to add more! Or remove if not needed to save cost
          PlaceField.Id,
          PlaceField.Address,
          PlaceField.AddressComponents,
          PlaceField.Location,
          PlaceField.PhoneNumber,
          PlaceField.Name,
          PlaceField.Rating,
          PlaceField.WebsiteUri,
          PlaceField.Location,
          PlaceField.OpeningHours,
        ],
      );

      logger.t("LocationProvider.getLocationDetailsFromPlaceId()");

      if (setAsCurrentPlace){
        _currentCity = placeDetails.place!.addressComponents!.firstWhere((element) => element.types!.contains("locality")).name!;
        _currentState = placeDetails.place!.addressComponents!.firstWhere((element) => element.types!.contains("administrative_area_level_1")).name!;
        _currentCountry = placeDetails.place!.addressComponents!.firstWhere((element) => element.types!.contains("country")).name!;
        _placeId = placeId;
        fetchPlacePhoto();
        notifyListeners();
        logger.t("LocationProvider.getLocationDetailsFromPlaceId() - setAsCurrentPlace - _currentCity=${_currentCity}");
      }

      return placeDetails.place;
    } catch (e) {
      logger.e("Error fetching place details: $e");
      return null;
    }
  }

  void setCurrentPlace(Place place) async {
    try {
      _currentCity = place.addressComponents!.firstWhere((element) => element.types!.contains("locality")).name!;
      _currentState = place.addressComponents!.firstWhere((element) => element.types!.contains("administrative_area_level_1")).name!;
      _currentCountry = place.addressComponents!.firstWhere((element) => element.types!.contains("country")).name!;
      _placeId = place.id!;
      _currentPlaceImg = await fetchPlacePhoto();
      notifyListeners();
      logger.t("LocationProvider.setCurrentPlace() - _currentCity=${_currentCity}");
    } catch (e) {
      logger.e(e);
    }
  }

  Future<List<AutocompletePrediction>?> getAutocompleteSuggestions(String query, {bool restrictToCities = true}) async {
    if (query == null || query.isEmpty) {
      logger.w("Query is null or empty: $query");
      return null;
    }
    try {
      if (_currentPosition == null) {
        logger.w("_currentPosition is null");
        return null;
      }

      // Get the Place ID using FlutterGooglePlacesSdk
      LatLng location = LatLng(lat: _currentPosition!.latitude, lng: _currentPosition!.longitude);
      LatLngBounds locationBias = _createBounds(location, 50);

      final result = await _places.findAutocompletePredictions(
        query,
        placeTypesFilter: restrictToCities ? [PlaceTypeFilter.CITIES] : [],
        locationBias: locationBias,
        origin: location,
      );

      List<AutocompletePrediction> resultSorted = List.from(result.predictions);

      resultSorted.sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
      logger.t("resultSorted.toString()=${resultSorted.toString()},   result.predictions.first.placeId=${resultSorted.first.placeId}");

      return resultSorted;
    } catch (e){
      logger.e(e);
      return null;
    }
  }

  LatLngBounds _createBounds(LatLng center, double distanceInKm) {
    // Earth's radius in kilometers
    const double earthRadius = 6378.137;

    // Calculate the offset in latitude and longitude
    double latOffset = distanceInKm / earthRadius;
    double lngOffset = distanceInKm / (earthRadius * math.cos(math.pi * center.lat / 180));

    // Convert offsets from radians to degrees
    latOffset = latOffset * 180 / math.pi;
    lngOffset = lngOffset * 180 / math.pi;

    // Create the southwest and northeast corners of the LatLngBounds
    LatLng southwest = LatLng(lat: center.lat - latOffset, lng: center.lng - lngOffset);
    LatLng northeast = LatLng(lat: center.lat + latOffset, lng: center.lng + lngOffset);

    // Return the LatLngBounds
    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  Future<void> _saveLocation() async {
    logger.t("LocationProvider._saveLocation()");
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
    logger.t("LocationProvider._loadSavedLocation()");
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
  Future<GooglePlacesImg?> fetchPlacePhoto({bool setAsCurrentImage = true}) async {
    //Ensure id is loaded
    //TODO: Fix bad code for waiting for placeId, improve approach to caching
    int attempts = 0;
    while (_placeId == null || _placeId == "") {
      await Future.delayed(Duration(milliseconds: 100));
      attempts++;
      if (attempts > 100) return null;
    }

    // Check if the image is already cached in memory
    if (_imageCache.containsKey(_placeId!)) {
      logger.t("locationProvider._fetchPlacePhoto() - found photo in cache for $_placeId");
      return _imageCache[_placeId!];
    }

    // Get the directory to store the image and metadata
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$_placeId.jpg';
    final metadataPath = '${directory.path}/$_placeId.json';

    // Check if the file exists in local storage
    final file = File(filePath);
    final metadataFile = File(metadataPath);
    if (await file.exists() && await metadataFile.exists()) {
      logger.t("locationProvider._fetchPlacePhoto() - found photo and metadata through placeid in local storage, loading");
      // Load the image and metadata from local storage
      final bytes = await file.readAsBytes();
      final metadataJson = await metadataFile.readAsString();
      final metadataMap = json.decode(metadataJson);
      final metadata = PhotoMetadata(
        photoReference: metadataMap['photoReference'],
        width: metadataMap['width'],
        height: metadataMap['height'],
        attributions: metadataMap['attributions'],
      );
      final googlePlacesImg = GooglePlacesImg(
        photoMetadata: metadata,
        placePhotoResponse: FetchPlacePhotoResponse.image(Image.memory(bytes)),
      );

      // Cache the image in memory
      _imageCache[_placeId!] = googlePlacesImg;

      if (setAsCurrentImage){
        _currentPlaceImg = googlePlacesImg;
        notifyListeners();
      }
      return googlePlacesImg;
    }

    logger.t("locationProvider._fetchPlacePhoto() - placeId=$_placeId");

    final result = await _places.fetchPlace(
      _placeId,
      fields: [PlaceField.PhotoMetadatas],
    );
    final place = result.place;

    if ((place?.photoMetadatas?.length ?? 0) == 0) {
      logger.t("locationProvider._fetchPlacePhoto() - place or place.photoMetadatas is null");
    }

    try {
      final metadata = place?.photoMetadatas![0];
      final response = await _places.fetchPlacePhoto(metadata!);

      final imageBytes = await response.when(
        image: (image) => _imageToBytes(image),
        imageUrl: (imageUrl) => _fetchImageBytesFromUrl(imageUrl),
      );

      if (imageBytes != null) {
        // Save the image to local storage
        await file.writeAsBytes(imageBytes);
        logger.t("locationProvider._fetchPlacePhoto() - saving photo and metadata through placeid in local storage");

        // Save metadata to local storage
        final metadataMap = {
          'photoReference': metadata!.photoReference,
          'width': metadata.width,
          'height': metadata.height,
          'attributions': metadata.attributions,
        };
        await metadataFile.writeAsString(json.encode(metadataMap));

        // Cache the image
        final googlePlacesImg = GooglePlacesImg(
          photoMetadata: metadata,
          placePhotoResponse: FetchPlacePhotoResponse.image(Image.memory(imageBytes)),
        );
        _imageCache[_placeId!] = googlePlacesImg;

        return googlePlacesImg;
      } else {
        return null;
      }
    } catch (err) {
      logger.e("locationProvider._fetchPlacePhoto() - Exception occured: $err");
      return null;
    }
  }

  //from chatgpt
  Future<Uint8List> _fetchImageBytesFromUrl(String imageUrl) async {
    // Fetch image bytes from imageUrl (e.g., using http package)
    // Replace this with your actual implementation to fetch image bytes from URL
    // Example:
    // final response = await http.get(Uri.parse(imageUrl));
    // if (response.statusCode == 200) {
    //   return response.bodyBytes;
    // } else {
    //   throw Exception('Failed to load image from $imageUrl');
    // }
    throw UnimplementedError('Fetching image from URL is not implemented.');
  }

  // Function to convert Image widget to Uint8List bytes
  Future<Uint8List> _imageToBytes(Image image) async {
    // Create a completer to handle async resolution
    Completer<Uint8List> completer = Completer<Uint8List>();
    // Resolve the image configuration and listen for updates
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo imageInfo, bool synchronousCall) async {
        // Convert the image to ByteData in PNG format
        final byteData = await imageInfo.image.toByteData(format: ui.ImageByteFormat.png);
        // Extract the bytes from ByteData
        final bytes = byteData!.buffer.asUint8List();
        // Complete the future with the bytes
        completer.complete(bytes);
      }),
    );
    // Return the future result
    return completer.future;
  }









  ///// Distance Calculation - static, not rly sure if it makes sense to leave here or put in a separate static utility class
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Implementation of distance calculation method
    // Example using Haversine formula:
    return haversine(lat1, lon1, lat2, lon2);
  }

  static double haversine(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of the Earth in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    double distance = R * c; // Distance in kilometers
    return distance;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }
}
