import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tourguide_app/utilities/crossplatform_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;

class MapUtils {
  MapUtils._();

  static Future<void> openMap(double latitude, double longitude) async {
    String googleUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunchUrl(Uri.parse(googleUrl))) {
      await launchUrl(Uri.parse(googleUrl));
    } else {
      throw 'Could not open the map.';
    }
  }

  static Future<void> openMapWithQuery(String query) async {
    String queryUri = Uri.encodeComponent(query);
    String googleUrl =
        "https://www.google.com/maps/search/?api=1&query=$queryUri";
    if (await canLaunchUrl(Uri.parse(googleUrl))) {
      await launchUrl(Uri.parse(googleUrl));
    } else {
      throw 'Could not open the map.';
    }
  }

  static double calculateDistance(LatLng point1, LatLng point2) {
    // You can use Haversine formula or simple Euclidean distance for close points
    double dx = point1.latitude - point2.latitude;
    double dy = point1.longitude - point2.longitude;
    return dx * dx + dy * dy;
  }

  static LatLngBounds createLatLngBounds(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (LatLng point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }
}
