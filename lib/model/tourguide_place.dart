import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'tourguide_place.g.dart';

//TODO: change name to tour place? More accurate since the description etc is specific to this place's tour
@HiveType(typeId: 1)
class TourguidePlace {
  @HiveField(0) final double latitude;
  @HiveField(1) final double longitude;
  @HiveField(2) final String googleMapPlaceId;
  @HiveField(3) final String title;
  @HiveField(4) final String description;
  @HiveField(5) final String photoUrl;
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
    String? photoUrl,
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
      photoUrl: photoUrl ?? this.photoUrl,
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
