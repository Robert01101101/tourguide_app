import 'package:flutter/material.dart';

class TourguidePlace {
  final double latitude;
  final double longitude;
  final String googleMapPlaceId;
  final String title;
  final String description;
  final List<String> photoUrls;
  TextEditingController? descriptionEditingController;  //mutable

  TourguidePlace({
    required this.latitude,
    required this.longitude,
    required this.googleMapPlaceId,
    required this.title,
    required this.description,
    required this.photoUrls,
    this.descriptionEditingController,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'googleMapPlaceId': googleMapPlaceId,
      'title': title,
      'description': description,
      'photoUrls': photoUrls,
    };
  }

  TourguidePlace copyWith({
    double? latitude,
    double? longitude,
    String? googleMapPlaceId,
    String? title,
    String? description,
    List<String>? photoUrls,
    TextEditingController? descriptionEditingController,
  }) {
    return TourguidePlace(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      googleMapPlaceId: googleMapPlaceId ?? this.googleMapPlaceId,
      title: title ?? this.title,
      description: description ?? this.description,
      photoUrls: photoUrls ?? this.photoUrls,
      descriptionEditingController: descriptionEditingController ?? this.descriptionEditingController,
    );
  }

  @override
  String toString() {
    return 'TourguidePlace{latitude: $latitude, longitude: $longitude, googleMapPlaceId: $googleMapPlaceId, title: $title, description: $description, photoUrls: $photoUrls}';
  }
}
