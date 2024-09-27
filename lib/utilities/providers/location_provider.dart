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
import '../../ui/google_places_img.dart'
    if (dart.library.html) '../../ui/google_places_img_web.dart' as gpi;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

enum PermissionStatus {
  granted,
  locationServicesDisabled,
  permissionDenied,
  permissionDeniedForever,
}

/// Handles Location Tracking, Permissions, manually set Location, and Geocoding.
class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  String _currentCity = '';
  String _currentState = '';
  String _currentCountry = '';
  String _placeId = '';
  late FlutterGooglePlacesSdk _places;
  TourguidePlaceImg? _currentPlaceImg;
  PermissionStatus _permissionStatus =
      PermissionStatus.locationServicesDisabled;

  Position? get currentPosition => _currentPosition;
  String get currentCity => _currentCity;
  String get currentState => _currentState;
  String get currentCountry => _currentCountry;
  String get placeId => _placeId;
  TourguidePlaceImg? get currentPlaceImg => _currentPlaceImg;
  PermissionStatus get permissionStatus => _permissionStatus;

  Map<String, TourguidePlaceImg> _imageCache = {};

  LocationProvider() {
    _init();
  }

  Future<void> _init() async {
    logger.t("LocationProvider._init()");
    _places = FlutterGooglePlacesSdk(remoteConfig.getString('google_api_key')!);
    _loadSavedLocation();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    logger.t("LocationProvider.getCurrentLocation()");

    PermissionStatus status = await _checkForPermissionSettings();
    if (status != PermissionStatus.granted) {
      logger.e("Location permission not granted: $status");
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position; // = testPos;
      notifyListeners();

      kIsWeb
          ? await _getLocationDetailsFromCoordinatesWeb(position)
          : await _getLocationDetailsFromCoordinates(position);
      await _saveLocation();
      notifyListeners();
    } catch (e) {
      logger.e(e);
    }
  }

  Future<PermissionStatus> _checkForPermissionSettings() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _permissionStatus = PermissionStatus.locationServicesDisabled;
      return PermissionStatus.locationServicesDisabled;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _permissionStatus = PermissionStatus.permissionDenied;
        return PermissionStatus.permissionDenied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _permissionStatus = PermissionStatus.permissionDeniedForever;
      return PermissionStatus.permissionDeniedForever;
    }

    _permissionStatus = PermissionStatus.granted;
    notifyListeners();
    return PermissionStatus.granted;
  }

  Future<void> refreshCurrentLocation() async {
    logger.t("LocationProvider.refreshCurrentLocation()");
    await getCurrentLocation();
    await fetchPlacePhoto();
    notifyListeners();
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
        logger.t(
            "LocationProvider._getLocationDetailsFromCoordinates() - _currentCity=$_currentCity!");
        _currentState = placemarks.first.administrativeArea ?? '';
        _currentCountry = placemarks.first.country ?? '';
        notifyListeners();
      }

      var resultSorted = await getAutocompleteSuggestions(
          "$_currentCity, $_currentState, $_currentCountry");

      if (resultSorted != null && resultSorted.isNotEmpty) {
        _placeId = resultSorted.first.placeId ?? '';
        notifyListeners();
      }
    } catch (e, stack) {
      logger.e(e, stackTrace: stack);
    }
  }

  Future<void> _getLocationDetailsFromCoordinatesWeb(Position position) async {
    try {
      double lat = position.latitude;
      double lng = position.longitude;
      logger.t("_getLocationDetailsFromCoordinatesWeb");

      String host = 'https://maps.google.com/maps/api/geocode/json';
      final url =
          '$host?key=${remoteConfig.getString('google_api_key')!}&language=en&latlng=$lat,$lng';

      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        //logger.i("_getLocationDetailsFromCoordinatesWeb - data=$data");

        if (data["results"].isNotEmpty) {
          var firstResult = data["results"][0];
          var addressComponents = firstResult["address_components"];

          _currentCity = _getComponent(addressComponents, 'locality') ?? '';
          _currentState =
              _getComponent(addressComponents, 'administrative_area_level_1') ??
                  '';
          _currentCountry = _getComponent(addressComponents, 'country') ?? '';

          var resultSorted = await getAutocompleteSuggestions(
              "$_currentCity, $_currentState, $_currentCountry");

          if (resultSorted != null && resultSorted.isNotEmpty) {
            _placeId = resultSorted.first.placeId ?? '';
            notifyListeners();
          }

          logger.t(
              "_getLocationDetailsFromCoordinatesWeb() - _currentCity=$_currentCity, _currentState=$_currentState, _currentCountry=$_currentCountry, _placeId=$_placeId");
          notifyListeners();
        } else {
          logger.e("No city results found for the provided coordinates.");
        }
      } else {
        logger.e(
            "Failed to fetch location details. HTTP status: ${response.statusCode}");
      }
    } catch (e, stack) {
      logger.e(e, stackTrace: stack);
    }
  }

  String? _getComponent(List<dynamic> components, String type) {
    for (final component in components) {
      if (component['types'].contains(type)) {
        return component['long_name'];
      }
    }
    return null;
  }

  Future<Place?> getLocationDetailsFromPlaceId(String placeId,
      {bool setAsCurrentPlace = false}) async {
    try {
      final placeDetails = await _places.fetchPlace(
        placeId,
        fields: [
          //Option to add more! Or remove if not needed to save cost
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

      if (setAsCurrentPlace) {
        _currentCity = placeDetails.place!.addressComponents!
            .firstWhere((element) => element.types!.contains("locality"))
            .name!;
        _currentState = placeDetails.place!.addressComponents!
            .firstWhere((element) =>
                element.types!.contains("administrative_area_level_1"))
            .name!;
        _currentCountry = placeDetails.place!.addressComponents!
            .firstWhere((element) => element.types!.contains("country"))
            .name!;
        _placeId = placeId;
        fetchPlacePhoto();
        notifyListeners();
        logger.t(
            "LocationProvider.getLocationDetailsFromPlaceId() - setAsCurrentPlace - _currentCity=${_currentCity}");
      }

      return placeDetails.place;
    } catch (e) {
      logger.e("Error fetching place details: $e");
      return null;
    }
  }

  void setCurrentPlace(Place place) async {
    try {
      _currentCity = place.addressComponents!
          .firstWhere((element) => element.types!.contains("locality"))
          .name!;
      _currentState = place.addressComponents!
          .firstWhere((element) =>
              element.types!.contains("administrative_area_level_1"))
          .name!;
      _currentCountry = place.addressComponents!
          .firstWhere((element) => element.types!.contains("country"))
          .name!;
      _currentPosition = Position(
          latitude: place.latLng!.lat,
          longitude: place.latLng!.lng,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          headingAccuracy: 0,
          altitudeAccuracy: 0);
      _placeId = place.id!;
      await fetchPlacePhoto(setAsCurrentImage: true);
      _saveLocation();
      notifyListeners();
      logger.t(
          "LocationProvider.setCurrentPlace() - _currentCity=${_currentCity}");
    } catch (e) {
      logger.e(e);
    }
  }

  Future<List<AutocompletePrediction>?> getAutocompleteSuggestions(String query,
      {bool restrictToCities = true,
      bool restrictToSurroundingArea = false,
      double? searchLocationLat,
      double? searchLocationLng}) async {
    if (query == null || query.isEmpty) {
      logger.w("Query is null or empty: $query");
      return null;
    }
    logger.t(
        "LocationProvider.getAutocompleteSuggestions($query, restrictToCities=$restrictToCities, restrictToSurroundingArea=$restrictToSurroundingArea, searchLocationLat=$searchLocationLat, searchLocationLng=$searchLocationLng)");
    try {
      LatLng? location;
      LatLng? searchLocation;
      if (searchLocationLat != null && searchLocationLng != null) {
        searchLocation = LatLng(lat: searchLocationLat, lng: searchLocationLng);
      }
      LatLngBounds? locationBias;

      // If the app is running on the web, restrictToSurroundingArea is not supported
      // https://issuetracker.google.com/issues/36219203?pli=1
      if (kIsWeb) restrictToSurroundingArea = false;

      if (_currentPosition == null) {
        logger.w(
            "_currentPosition is null, autocomplete suggestions may not be accurate.");
      } else {
        location = searchLocation ??
            LatLng(
                lat: _currentPosition!.latitude,
                lng: _currentPosition!.longitude);
        locationBias =
            _createBounds(location, restrictToSurroundingArea ? 200 : 50);
      }

      // Get the Place ID using FlutterGooglePlacesSdk
      final result = await _places.findAutocompletePredictions(
        query,
        placeTypesFilter: restrictToCities ? [PlaceTypeFilter.CITIES] : [],
        locationBias: restrictToSurroundingArea ? null : locationBias,
        origin: location,
        locationRestriction: restrictToSurroundingArea ? locationBias : null,
      );

      List<AutocompletePrediction> resultSorted = List.from(result.predictions);

      //resultSorted.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
      logger.t(
          "resultSorted.toString()=${resultSorted.toString()},   result.predictions.first.placeId=${resultSorted.first.placeId}");

      return resultSorted;
    } catch (e) {
      logger.e(e);
      return null;
    }
  }

  LatLngBounds _createBounds(LatLng center, double distanceInKm) {
    // Earth's radius in kilometers
    const double earthRadius = 6378.137;

    // Calculate the offset in latitude and longitude
    double latOffset = distanceInKm / earthRadius;
    double lngOffset =
        distanceInKm / (earthRadius * math.cos(math.pi * center.lat / 180));

    // Convert offsets from radians to degrees
    latOffset = latOffset * 180 / math.pi;
    lngOffset = lngOffset * 180 / math.pi;

    // Create the southwest and northeast corners of the LatLngBounds
    LatLng southwest =
        LatLng(lat: center.lat - latOffset, lng: center.lng - lngOffset);
    LatLng northeast =
        LatLng(lat: center.lat + latOffset, lng: center.lng + lngOffset);

    // Return the LatLngBounds
    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  Future<void> _saveLocation() async {
    logger.t("LocationProvider._saveLocation()");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_currentPosition != null) {
      prefs.setDouble('latitude', _currentPosition!.latitude);
      prefs.setDouble('longitude', _currentPosition!.longitude);
      prefs.setString('city', _currentCity);
      prefs.setString('state', _currentState);
      prefs.setString('country', _currentCountry);
      prefs.setString('placeId', _placeId);
    }
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
          altitudeAccuracy: 0);
    }
    _currentCity = prefs.getString('city') ?? '';
    _currentState = prefs.getString('state') ?? '';
    _currentCountry = prefs.getString('country') ?? '';
    _placeId = prefs.getString('placeId') ?? '';
    notifyListeners();
  }

  //from https://pub.dev/packages/flutter_google_places_sdk/example, with modifications for simplification & integration to location_provider
  Future<TourguidePlaceImg?> fetchPlacePhoto(
      {String? placeId, bool setAsCurrentImage = true}) async {
    try {
      logger.t(
          "locationProvider._fetchPlacePhoto($placeId, setAsCurrentImage=$setAsCurrentImage)");
      if (placeId == null) {
        //Ensure id is loaded
        //TODO: Fix bad code for waiting for placeId, improve approach to caching
        int attempts = 0;
        while (_placeId == null || _placeId == "") {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
          if (attempts > 100) {
            throw Exception("Timed out waiting for _placeId to load");
          }
        }
        placeId = _placeId;
      }

      // Check if the image is already cached in memory
      if (_imageCache.containsKey(placeId!)) {
        logger.t(
            "locationProvider._fetchPlacePhoto() - found photo in cache for $placeId");
        if (setAsCurrentImage) {
          _currentPlaceImg = _imageCache[placeId!];
          notifyListeners();
        }
        return _currentPlaceImg;
      }

      File? file, metadataFile;
      if (!kIsWeb) {
        // Get the directory to store the image and metadata
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$placeId.jpg';
        final metadataPath = '${directory.path}/$placeId.json';

        // Check if the file exists in local storage
        file = File(filePath);
        metadataFile = File(metadataPath);
        if (await file.exists() && await metadataFile.exists()) {
          logger.t(
              "locationProvider._fetchPlacePhoto() - found photo and metadata through placeid in local storage, loading");
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
          final googlePlacesImg = gpi.GooglePlacesImg(
            photoMetadata: metadata,
            placePhotoResponse:
                FetchPlacePhotoResponse.image(Image.memory(bytes)),
          );

          final tourguidePlaceImg = TourguidePlaceImg(
              googlePlacesImg: googlePlacesImg, file: file, imageUrl: null);

          // Cache the image in memory
          _imageCache[placeId!] = tourguidePlaceImg;

          if (setAsCurrentImage) {
            _currentPlaceImg = tourguidePlaceImg;
            notifyListeners();
          }
          return tourguidePlaceImg;
        }
      }

      logger.t("locationProvider._fetchPlacePhoto() - placeId=$placeId");

      _places.isInitialized();
      bool? isInitialized = await _places.isInitialized();
      final result = await _places.fetchPlace(
        placeId,
        fields: [PlaceField.PhotoMetadatas],
      );
      final place = result.place;

      if (place?.photoMetadatas == null) {
        throw Exception("place or place.photoMetadatas is null");
      }
      final metadata = place?.photoMetadatas![0];
      final response = await _places.fetchPlacePhoto(metadata!);

      if (!kIsWeb) {
        final imageBytes = await response.when(
          image: (image) {
            return _imageToBytes(image);
          },
          imageUrl: (imageUrl) {
            return _fetchImageBytesFromUrl(imageUrl);
          },
        );

        if (imageBytes != null) {
          // Save the image to local storage
          await file!.writeAsBytes(imageBytes);
          logger.t(
              "locationProvider._fetchPlacePhoto() - saving photo and metadata through placeid in local storage");

          // Save metadata to local storage
          final metadataMap = {
            'photoReference': metadata!.photoReference,
            'width': metadata.width,
            'height': metadata.height,
            'attributions': metadata.attributions,
          };
          await metadataFile!.writeAsString(json.encode(metadataMap));

          // Cache the image
          final googlePlacesImg = gpi.GooglePlacesImg(
            photoMetadata: metadata,
            placePhotoResponse:
                FetchPlacePhotoResponse.image(Image.memory(imageBytes)),
          );
          final tourguidePlaceImg = TourguidePlaceImg(
              googlePlacesImg: googlePlacesImg, file: file, imageUrl: null);
          _imageCache[placeId!] = tourguidePlaceImg;

          if (setAsCurrentImage) {
            _currentPlaceImg = tourguidePlaceImg;
            notifyListeners();
          }
          return tourguidePlaceImg;
        } else {
          return null;
        }
      } else {
        //on web,
        response.when(
          image: (image) {
            logger.t('image:' + image.toString());
            return _imageToBytes(image);
          },
          imageUrl: (imageUrl) {
            logger.t('imageUrl:' + imageUrl);
            // Cache the image
            final googlePlacesImg = gpi.GooglePlacesImg(
              photoMetadata: metadata,
              placePhotoResponse: FetchPlacePhotoResponse.imageUrl(imageUrl),
            );
            final tourguidePlaceImg = TourguidePlaceImg(
                googlePlacesImg: googlePlacesImg,
                file: file,
                imageUrl: imageUrl);
            if (setAsCurrentImage) {
              _currentPlaceImg = tourguidePlaceImg;
              notifyListeners();
            }

            _imageCache[placeId!] = tourguidePlaceImg;

            return tourguidePlaceImg;
          },
        );
      }
    } catch (err, stack) {
      logger.e(
          "locationProvider._fetchPlacePhoto() - Exception occured: $err, placeId=$placeId, setAsCurrentImage=$setAsCurrentImage \n$stack");
      return null;
    }
  }

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
        final byteData =
            await imageInfo.image.toByteData(format: ui.ImageByteFormat.png);
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
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Implementation of distance calculation method
    // Example using Haversine formula:
    return haversine(lat1, lon1, lat2, lon2);
  }

  static double haversine(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of the Earth in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    double distance = R * c; // Distance in kilometers
    return distance;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }
}

class TourguidePlaceImg {
  final gpi.GooglePlacesImg? googlePlacesImg;
  final File? file;

  /// mobile only
  final String? imageUrl;

  /// web only

  TourguidePlaceImg(
      {required this.googlePlacesImg,
      required this.file,
      required this.imageUrl});
}
