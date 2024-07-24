import 'dart:io';

import 'package:flutter/material.dart';

//TODO: change name to tour place? More accurate since the description etc is specific to this place's tour
class TourguidePlace {
  final double latitude;
  final double longitude;
  final String googleMapPlaceId;
  final String title;
  final String description;
  final String photoUrl;
  TextEditingController? descriptionEditingController;  //mutable
  Image? image; //mutable
  File? imageFile; //mutable

  TourguidePlace({
    required this.latitude,
    required this.longitude,
    required this.googleMapPlaceId,
    required this.title,
    required this.description,
    required this.photoUrl,
    this.descriptionEditingController,
    this.image,
    this.imageFile,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'googleMapPlaceId': googleMapPlaceId,
      'title': title,
      'description': description,
      'photoUrl': photoUrl,
    };
  }

  TourguidePlace copyWith({
    double? latitude,
    double? longitude,
    String? googleMapPlaceId,
    String? title,
    String? description,
    String? photoUrls,
    TextEditingController? descriptionEditingController,
    Image? image,
    File? imageFile,
  }) {
    return TourguidePlace(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      googleMapPlaceId: googleMapPlaceId ?? this.googleMapPlaceId,
      title: title ?? this.title,
      description: description ?? this.description,
      photoUrl: photoUrls ?? this.photoUrl,
      descriptionEditingController: descriptionEditingController ?? this.descriptionEditingController,
      image: image ?? this.image,
      imageFile: imageFile ?? this.imageFile,
    );
  }

  @override
  String toString() {
    return 'TourguidePlace{latitude: $latitude, longitude: $longitude, googleMapPlaceId: $googleMapPlaceId, title: $title, description: $description, photoUrl: $photoUrl, image: $image, descriptionEditingController: $descriptionEditingController}';
  }
}
