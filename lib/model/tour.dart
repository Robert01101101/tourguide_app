import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourguide_app/model/tourguide_place.dart';
import 'package:tourguide_app/model/tourguide_report.dart';

/// Mutable properties: upvotes, downvotes, isAddTourTile, isOfflineCreatedTour, thisUsersRating, imageToUpload
class Tour {
  final String id;
  final String name;
  final String description;
  final String city;
  final String visibility;
  final String imageUrl;
  final DateTime? createdDateTime;
  final double latitude;
  final double longitude;
  final String placeId;
  final String authorName;
  final String authorId;
  final List<TourguidePlace> tourguidePlaces;
  final List<TourguideReport> reports;
  /// mutable AND stored in Firestore
  int upvotes;
  /// mutable AND stored in Firestore
  int downvotes;
  /// mutable, NOT stored in Firestore, indicates add tour button (dirty)
  bool isAddTourTile;
  /// mutable, NOT stored in Firestore, indicates this is an offline tour about to be uploaded
  bool isOfflineCreatedTour;
  /// mutable, NOT stored in Firestore, Track this user's rating
  int? thisUsersRating;
  /// mutable, NOT stored in Firestore, Track this user's rating
  File? imageToUpload;

  Tour({
    required this.id,
    required this.name,
    required this.description,
    required this.city,
    required this.visibility,
    required this.imageUrl,
    required this.createdDateTime,
    required this.latitude,
    required this.longitude,
    required this.placeId,
    required this.authorName,
    required this.authorId,
    required this.tourguidePlaces,
    required this.reports,
    required this.upvotes,
    required this.downvotes,
    required this.isAddTourTile,
    required this.isOfflineCreatedTour,
    this.thisUsersRating,
    this.imageToUpload,
  });

  factory Tour.empty() {
    return Tour(
      id: '',
      name: '',
      description: '',
      city: '',
      visibility: '',
      imageUrl: '',
      createdDateTime: null,
      latitude: 0.0,
      longitude: 0.0,
      placeId: '',
      authorName: '',
      authorId: '',
      tourguidePlaces: [],
      reports: [],
      upvotes: 0,
      downvotes: 0,
      isAddTourTile: false,
      isOfflineCreatedTour: false,
      imageToUpload: null,
    );
  }

  factory Tour.isAddTourTile() {
    Tour addTourTile = Tour.empty();
    addTourTile.isAddTourTile = true;
    return addTourTile;
  }

  factory Tour.isOfflineCreatedTour() {
    Tour addTourTile = Tour.empty();
    addTourTile.isOfflineCreatedTour = true;
    return addTourTile;
  }

  factory Tour.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Document data was null');
    }

    DateTime? createdDateTime;
    if (data['createdDateTime'] != null) {
      Timestamp timestamp = data['createdDateTime'] as Timestamp;
      createdDateTime = timestamp.toDate();
    } else {
      createdDateTime = null;
    }

    List<TourguidePlace> tourguidePlaces = [];
    if (data['tourguidePlaces'] != null) {
      List<dynamic> places = data['tourguidePlaces'];
      tourguidePlaces = places.map((place) {
        return TourguidePlace(
          latitude: place['latitude']?.toDouble() ?? 0.0,
          longitude: place['longitude']?.toDouble() ?? 0.0,
          googleMapPlaceId: place['googleMapPlaceId'] ?? '',
          title: place['title'] ?? '',
          description: place['description'] ?? '',
          photoUrl: place['photoUrl'] ?? '',
        );
      }).toList();
    }
    List<TourguideReport> reports = [];
    if (data['reports'] != null) {
      List<dynamic> reportsData = data['reports'];
      reports = reportsData.map((reportData) {
        return TourguideReport.fromMap(reportData as Map<String, dynamic>);
      }).toList();
    }

    return Tour(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      city: data['city'] ?? '',
      visibility: data['visibility'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      createdDateTime: createdDateTime,
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      placeId: data['placeId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorId: data['authorId'] ?? '',
      tourguidePlaces: tourguidePlaces,
      reports: reports,
      upvotes: data['upvotes'] ?? 0,
      downvotes: data['downvotes'] ?? 0,
      isAddTourTile: false,
      isOfflineCreatedTour: false,
      imageToUpload: null,
    );
  }

  Tour copyWith({
    String? id,
    String? name,
    String? description,
    String? city,
    String? uid,
    String? visibility,
    String? imageUrl,
    DateTime? createdDateTime,
    double? latitude,
    double? longitude,
    String? placeId,
    String? authorName,
    String? authorId,
    List<TourguidePlace>? tourguidePlaces,
    List<TourguideReport>? reports,
    int? upvotes,
    int? downvotes,
    bool? isAddTourTile,
    bool? isOfflineCreatedTour,
    int? thisUsersRating,
    File? imageToUpload,
  }) {
    return Tour(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      city: city ?? this.city,
      visibility: visibility ?? this.visibility,
      imageUrl: imageUrl ?? this.imageUrl,
      createdDateTime: createdDateTime ?? this.createdDateTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      authorName: authorName ?? this.authorName,
      authorId: authorId ?? this.authorId,
      tourguidePlaces: tourguidePlaces ?? this.tourguidePlaces,
      reports: reports ?? this.reports,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      isAddTourTile: isAddTourTile ?? this.isAddTourTile,
      isOfflineCreatedTour: isOfflineCreatedTour ?? this.isOfflineCreatedTour,
      thisUsersRating: thisUsersRating ?? this.thisUsersRating,
      imageToUpload: imageToUpload ?? this.imageToUpload,
    );
  }

  @override
  bool operator ==(Object other) {  //compare tours by id (more performant)
    if (identical(this, other)) return true;
    if (runtimeType != other.runtimeType) return false;
    return other is Tour && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'city': city,
      'visibility': visibility,
      'imageUrl': imageUrl,
      'createdDateTime': createdDateTime,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'authorName': authorName,
      'authorId': authorId,
      'tourguidePlaces': tourguidePlaces.map((place) => place.toMap()).toList(),
      'reports': reports.map((report) => report.toMap()).toList(),
      'upvotes': upvotes,
      'downvotes': downvotes,
    };
  }

  @override
  String toString() {
    return 'Tour{id: $id, name: $name, description: $description, city: $city, visibility: $visibility, imageUrl: $imageUrl, createdDateTime: $createdDateTime, latitude: $latitude, longitude: $longitude, placeId: $placeId, authorName: $authorName, authorId: $authorId, reports:${reports.toString()}, upvotes: $upvotes, downvotes: $downvotes, isAddTourTile: $isAddTourTile, isOfflineCreatedTour: $isOfflineCreatedTour, imageToUpload: $imageToUpload, \ntourguidePlaces: ${tourguidePlaces.toString()}';
  }
}






