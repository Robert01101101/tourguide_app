import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

/// TAKEN FROM flutter_google_places_sdk EXAMPLE
/// Widget used to display google place image. Used in web platforms
class GooglePlacesImg extends StatelessWidget {
  /// The photo metadata
  final PhotoMetadata photoMetadata;

  /// The photo fetch response
  final FetchPlacePhotoResponse placePhotoResponse;

  /// Construct a google place img using metadata and response object
  const GooglePlacesImg(
      {super.key, required this.photoMetadata, required this.placePhotoResponse});

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        placePhotoResponse.whenOrNull(imageUrl: (imageUrl) => imageUrl);
    if (imageUrl == null) {
      return const Text('Invalid image url!');
    }

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(photoMetadata.photoReference,
        (int viewId) => html.Element.img()..setAttribute('src', imageUrl));

    final view = HtmlElementView(viewType: photoMetadata.photoReference);
    return SizedBox(
      width: photoMetadata.width.toDouble(),
      height: photoMetadata.height.toDouble(),
      child: view,
    );
  }
}
