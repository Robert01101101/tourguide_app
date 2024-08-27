import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourguide_app/model/tourguide_place.dart';
import 'package:tourguide_app/model/tourguide_report.dart';
import 'package:hive/hive.dart';

part 'tour.g.dart';

/// Mutable properties: upvotes, downvotes, isAddTourTile, isOfflineCreatedTour, thisUsersRating, imageToUpload
@HiveType(typeId: 0)
class Tour {
  @HiveField(0) final String id;
  @HiveField(1) final String name;
  @HiveField(2) final String description;
  @HiveField(3) final String city;
  @HiveField(4) final String visibility;
  @HiveField(5) final String imageUrl;
  @HiveField(6) final DateTime? createdDateTime;
  @HiveField(7) final DateTime? lastChangedDateTime;
  @HiveField(8) final double latitude;
  @HiveField(9) final double longitude;
  @HiveField(10) final String placeId;
  @HiveField(11) final String authorName;
  @HiveField(12) final String authorId;
  @HiveField(13) final String requestReviewStatus;
  @HiveField(14) final List<TourguidePlace> tourguidePlaces;
  @HiveField(15) final List<TourguideReport> reports;
  /// mutable AND stored in Firestore
  @HiveField(16) int upvotes;
  /// mutable AND stored in Firestore
  @HiveField(17) int downvotes;
  /// mutable, NOT stored in Firestore, indicates add tour button (dirty)
  bool isAddTourTile;
  /// mutable, NOT stored in Firestore, indicates this is an offline tour about to be uploaded
  bool isOfflineCreatedTour;
  /// mutable, NOT stored in Firestore, Track this user's rating
  int? thisUsersRating;
  /// mutable, NOT stored in Firestore, Track this user's rating
  File? imageFile;
  /// mutable, NOT stored in Firestore, request media re-downloads for for this tour
  bool requestMediaRedownload = false;

  Tour({
    required this.id,
    required this.name,
    required this.description,
    required this.city,
    required this.visibility,
    required this.imageUrl,
    required this.createdDateTime,
    required this.lastChangedDateTime,
    required this.latitude,
    required this.longitude,
    required this.placeId,
    required this.authorName,
    required this.authorId,
    required this.requestReviewStatus,
    required this.tourguidePlaces,
    required this.reports,
    required this.upvotes,
    required this.downvotes,
    required this.isAddTourTile,
    required this.isOfflineCreatedTour,
    this.thisUsersRating,
    this.imageFile,
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
      lastChangedDateTime: null,
      latitude: 0.0,
      longitude: 0.0,
      placeId: '',
      authorName: '',
      authorId: '',
      requestReviewStatus: '',
      tourguidePlaces: [],
      reports: [],
      upvotes: 0,
      downvotes: 0,
      isAddTourTile: false,
      isOfflineCreatedTour: false,
      imageFile: null,
    );
  }

  factory Tour.isAddTourTile() {
    Tour addTourTile = Tour.empty().copyWith(
        id: 'addTourTile',
        name: 'Add Tour',
        isAddTourTile: true);
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
    DateTime? lastChangedDateTime;
    if (data['lastChangedDateTime'] != null) {
      Timestamp timestamp = data['lastChangedDateTime'] as Timestamp;
      lastChangedDateTime = timestamp.toDate();
    } else {
      lastChangedDateTime = null;
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
      lastChangedDateTime: lastChangedDateTime,
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      placeId: data['placeId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorId: data['authorId'] ?? '',
      requestReviewStatus: data['requestReviewStatus'] ?? '',
      tourguidePlaces: tourguidePlaces,
      reports: reports,
      upvotes: data['upvotes'] ?? 0,
      downvotes: data['downvotes'] ?? 0,
      isAddTourTile: false,
      isOfflineCreatedTour: false,
      imageFile: null,
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
    DateTime? lastChangedDateTime,
    double? latitude,
    double? longitude,
    String? placeId,
    String? authorName,
    String? authorId,
    String? requestReviewStatus,
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
      lastChangedDateTime: lastChangedDateTime ?? this.lastChangedDateTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      authorName: authorName ?? this.authorName,
      authorId: authorId ?? this.authorId,
      requestReviewStatus: requestReviewStatus ?? this.requestReviewStatus,
      tourguidePlaces: tourguidePlaces ?? this.tourguidePlaces,
      reports: reports ?? this.reports,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      isAddTourTile: isAddTourTile ?? this.isAddTourTile,
      isOfflineCreatedTour: isOfflineCreatedTour ?? this.isOfflineCreatedTour,
      thisUsersRating: thisUsersRating ?? this.thisUsersRating,
      imageFile: imageToUpload ?? this.imageFile,
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
      'lastChangedDateTime': lastChangedDateTime,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': placeId,
      'authorName': authorName,
      'authorId': authorId,
      'requestReviewStatus': requestReviewStatus,
      'tourguidePlaces': tourguidePlaces.map((place) => place.toMap()).toList(),
      'reports': reports.map((report) => report.toMap()).toList(),
      'upvotes': upvotes,
      'downvotes': downvotes,
    };
  }

  @override
  String toString() {
    return 'Tour{id: $id, name: $name, description: $description, city: $city, visibility: $visibility, imageUrl: $imageUrl, createdDateTime: $createdDateTime, lastChangedDateTime: $lastChangedDateTime, latitude: $latitude, longitude: $longitude, placeId: $placeId, authorName: $authorName, authorId: $authorId, reports:${reports.toString()}, requestReviewStatus: $requestReviewStatus, upvotes: $upvotes, downvotes: $downvotes, isAddTourTile: $isAddTourTile, isOfflineCreatedTour: $isOfflineCreatedTour, imageFile: $imageFile, \ntourguidePlaces: ${tourguidePlaces.toString()}';
  }
}






