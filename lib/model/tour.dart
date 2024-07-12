import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tourguide_place.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';

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
  int upvotes;  //mutable
  int downvotes;  //mutable
  bool isAddTourTile;  //mutable, indicates add tour button (dirty)
  bool isOfflineCreatedTour;  //mutable, indicates this is an offline tour about to be uploaded
  int? thisUsersRating; // Track user's rating
  File? imageToUpload;   // New field

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
          photoUrls: List<String>.from(place['photoUrls'] ?? []),
        );
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
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      isAddTourTile: isAddTourTile ?? this.isAddTourTile,
      isOfflineCreatedTour: isOfflineCreatedTour ?? this.isOfflineCreatedTour,
      thisUsersRating: thisUsersRating ?? this.thisUsersRating,
      imageToUpload: imageToUpload ?? this.imageToUpload,
    );
  }

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
    };
  }

  @override
  String toString() {
    return 'Tour{id: $id, name: $name, description: $description, city: $city, visibility: $visibility, imageUrl: $imageUrl, createdDateTime: $createdDateTime, latitude: $latitude, longitude: $longitude, placeId: $placeId, authorName: $authorName, authorId: $authorId, tourguidePlaces: ${tourguidePlaces.toString()}, upvotes: ${upvotes}, downvotes: $downvotes}, isAddTourTile: $isAddTourTile, isOfflineCreatedTour: $isOfflineCreatedTour, imageToUpload: $imageToUpload}}';
  }
}




class TourService {
  static Future<List<Tour>> fetchAllTours() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    FirebaseStorage storage = FirebaseStorage.instance;
    FirebaseAuth auth = FirebaseAuth.instance;

    List<Tour> tours = [];

    try {
      User? user = auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      logger.t('fetchAllTours() all requirements ready, fetching ${getFormattedTime()}');
      QuerySnapshot querySnapshot = await db.collection('tours')
          .where('visibility', isEqualTo: 'public')
          .get();

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (data['visibility'] == 'public' || data['uid'] == user.uid) {
          Tour tour = Tour.fromFirestore(doc);

          if (tour.imageUrl.isNotEmpty) {
            try {
              String fullUrl = tour.imageUrl;
              Uri uri = Uri.parse(fullUrl);
              String path = uri.path.replaceFirst('/v0/b/tourguide-firebase.appspot.com/o/', '').replaceAll('%2F', '/');

              String imageUrl = await storage.ref(path).getDownloadURL();
              tour = tour.copyWith(imageUrl: imageUrl);
            } catch (e) {
              logger.e('Error fetching image: $e');
            }
          }

          tours.add(tour);
        }
      }
      logger.t('fetchAllTours() finished getting all tours ${getFormattedTime()}');
    } catch (e) {
      logger.e('Error fetching tours: $e');
    }

    return tours;
  }

  static Future<List<Tour>> checkUserRatings(List<Tour> tours, String userId) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    for (Tour tour in tours) {
      CollectionReference ratings = db.collection('tours').doc(tour.id).collection('ratings');
      QuerySnapshot querySnapshot = await ratings.where('userId', isEqualTo: userId).get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot ratingDoc = querySnapshot.docs.first;
        Rating rating = Rating.fromMap(ratingDoc.data() as Map<String, dynamic>);
        tour.thisUsersRating = rating.value;
      } else {
        tour.thisUsersRating = 0; // User hasn't rated
      }
    }
    return tours;
  }

  static Future<List<Tour>> fetchAndSortToursByDateTime() async {
    List<Tour> tours = await fetchAllTours();

    tours.sort((a, b) {
      if (a.createdDateTime == null && b.createdDateTime == null) {
        return 0;
      } else if (a.createdDateTime == null) {
        return 1;
      } else if (b.createdDateTime == null) {
        return -1;
      } else {
        return b.createdDateTime!.compareTo(a.createdDateTime!);
      }
    });

    return tours;
  }

  ////////// Filters
  static List<Tour> popularToursNearYou(List<Tour> tours, double userLatitude, double userLongitude) {
    return tours.where((tour) {
      double distance = LocationProvider.calculateDistance(userLatitude, userLongitude, tour.latitude, tour.longitude);
      double upvoteRatio = tour.downvotes == 0 ? tour.upvotes.toDouble()*2 : tour.upvotes / tour.downvotes;
      return distance <= 30 &&
          tour.upvotes > 0 &&
          upvoteRatio >= 2.0;
    }).toList();
  }

  static List<Tour> localTours(List<Tour> tours, double userLatitude, double userLongitude) {
    List<Tour> nearbyTours = tours.where((tour) {
      double distance = LocationProvider.calculateDistance(userLatitude, userLongitude, tour.latitude, tour.longitude);
      return distance <= 15;
    }).toList();

    // Sort nearby tours by distance
    nearbyTours.sort((a, b) {
      double distanceA = LocationProvider.calculateDistance(userLatitude, userLongitude, a.latitude, a.longitude);
      double distanceB = LocationProvider.calculateDistance(userLatitude, userLongitude, b.latitude, b.longitude);
      return distanceA.compareTo(distanceB);
    });

    return nearbyTours;
  }

  static List<Tour> userCreatedTours(List<Tour> tours, String userId) {
    List<Tour> userCreatedTours = tours.where((tour) => tour.authorId == userId).toList();
    // Sort tours by createdDateTime in descending order (most recent first)
    userCreatedTours.sort((a, b) => b.createdDateTime!.compareTo(a.createdDateTime!));
    //log length
    logger.t('userCreatedTours length: ${userCreatedTours.length}, userId=$userId');
    return userCreatedTours;
  }

  static List<Tour> userSavedTours(List<Tour> tours, String userId) {
    return List.generate(4, (index) => Tour.empty());
  }


  static List<Tour> popularToursAroundTheWorld(List<Tour> tours) {
    tours.sort((a, b) => (b.upvotes - b.downvotes).compareTo(a.upvotes - a.downvotes));
    return tours.take(10).toList();
  }

  static Future<void> addComment(String tourId, Comment comment) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    CollectionReference comments = db.collection('tours').doc(tourId).collection('comments');

    await comments.add({
      'text': comment.text,
      'userId': comment.userId,
      'userName': comment.userName,
      'timestamp': comment.timestamp,
    });
  }

  //TODO
  static Future<List<Comment>> fetchComments(String tourId) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    CollectionReference comments = db.collection('tours').doc(tourId).collection('comments');

    QuerySnapshot querySnapshot = await comments.orderBy('timestamp', descending: true).get();

    return querySnapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
  }

  static Future<void> addOrUpdateRating(String tourId, int value, String userId) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    CollectionReference ratings = db.collection('tours').doc(tourId).collection('ratings');
    DocumentReference tourRef = db.collection('tours').doc(tourId);

    try {
      // Create or update the rating
      QuerySnapshot querySnapshot = await ratings.where('userId', isEqualTo: userId).get();
      if (querySnapshot.docs.isEmpty) {
        // User has not rated yet, add a new rating
        await ratings.add(Rating(userId: userId, value: value).toMap());
      } else {
        // User has already rated, update the existing rating
        DocumentReference docRef = querySnapshot.docs.first.reference;
        await docRef.update({'value': value});
      }

      // Update tour's upvotes and downvotes
      Map<String, int> ratingsCount = await getRatings(tourId);
      await tourRef.update({
        'upvotes': ratingsCount['upvotes'],
        'downvotes': ratingsCount['downvotes'],
      });
    } catch (e) {
      logger.e('Error adding or updating rating: $e');
      throw Exception('Failed to add or update rating');
    }
  }

  static Future<Map<String, int>> getRatings(String tourId) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    CollectionReference ratings = db.collection('tours').doc(tourId).collection('ratings');

    QuerySnapshot querySnapshot = await ratings.get();
    int upvotes = 0;
    int downvotes = 0;

    for (QueryDocumentSnapshot doc in querySnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      Rating rating = Rating.fromMap(data);
      if (rating.value == 1) {
        upvotes++;
      } else if (rating.value == -1) {
        downvotes++;
      }
    }

    return {'upvotes': upvotes, 'downvotes': downvotes};
  }
}



//TODO: Implement Comments
class Comment {
  final String id;
  final String text;
  final String userId;
  final String userName;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.text,
    required this.userId,
    required this.userName,
    required this.timestamp,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Document data was null');
    }

    Timestamp timestamp = data['timestamp'] as Timestamp;

    return Comment(
      id: doc.id,
      text: data['text'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      timestamp: timestamp.toDate(),
    );
  }
}



class Rating {
  final String userId;
  final int value; // 1 for thumb up, -1 for thumb down

  Rating({
    required this.userId,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'value': value,
    };
  }

  factory Rating.fromMap(Map<String, dynamic> data) {
    return Rating(
      userId: data['userId'],
      value: data['value'],
    );
  }
}
