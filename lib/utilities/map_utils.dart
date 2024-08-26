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
    String googleUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunchUrl(Uri.parse(googleUrl))) {
      await launchUrl(Uri.parse(googleUrl));
    } else {
      throw 'Could not open the map.';
    }
  }

  static Future<void> openMapWithQuery(String query) async {
    String queryUri = Uri.encodeComponent(query);
    String googleUrl = "https://www.google.com/maps/search/?api=1&query=$queryUri";
    if (await canLaunchUrl(Uri.parse(googleUrl))) {
      await launchUrl(Uri.parse(googleUrl));
    } else {
      throw 'Could not open the map.';
    }
  }

  static Future<BitmapDescriptor> createNumberedMarkerBitmap(int number, {Color color = Colors.lightBlue}) async {
    final double baseSize = CrossplatformUtils.isMobile() ? 24 : 40.0; // Smaller size for the marker
    final double circleSize = baseSize * 2; // Circle diameter
    final double textSize = baseSize * 1; // Text size proportional to the marker

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Draw a shadow (a blurred circle behind the main circle)
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3) // Shadow color with some transparency
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.0); // Adjust blur radius

    canvas.drawCircle(
      Offset(circleSize / 2, circleSize / 2),
      circleSize / 2 - 2, // Make the shadow slightly larger
      shadowPaint,
    );

    // Draw the main circle
    final Paint paint = Paint()..color = color;
    canvas.drawCircle(
      Offset(circleSize / 2, circleSize / 2),
      circleSize / 2 - 6,
      paint,
    );

    // Draw the number with appropriate size
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: number.toString(),
      style: TextStyle(
        fontSize: textSize,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (circleSize - textPainter.width) / 2,
        (circleSize - textPainter.height) / 2,
      ),
    );

    // Convert the canvas to an image at the original size
    final ui.Image img = await pictureRecorder.endRecording().toImage(circleSize.toInt(), circleSize.toInt());

    // Convert to ByteData directly from the original image
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to convert image to ByteData');
    }

    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
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

  static double calculateDistance(LatLng point1, LatLng point2) {
    // You can use Haversine formula or simple Euclidean distance for close points
    double dx = point1.latitude - point2.latitude;
    double dy = point1.longitude - point2.longitude;
    return dx * dx + dy * dy;
  }
}