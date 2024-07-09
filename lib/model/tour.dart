import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tourguide_place.dart';

class Tour {
  final String id;
  final String name;
  final String description;
  final String city;
  final String uid;
  final String visibility;
  final String imageUrl;
  final DateTime? createdDateTime;
  final double latitude;
  final double longitude;
  final String placeId;
  final String authorName;
  final String authorId;
  final List<TourguidePlace> tourguidePlaces; // New field

  Tour({
    required this.id,
    required this.name,
    required this.description,
    required this.city,
    required this.uid,
    required this.visibility,
    required this.imageUrl,
    required this.createdDateTime,
    required this.latitude,
    required this.longitude,
    required this.placeId,
    required this.authorName,
    required this.authorId,
    required this.tourguidePlaces, // Initialize with an empty list or from constructor
  });

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
      createdDateTime = null; // Default value or handle as needed
    }

    // Extract tourguide places from data
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
      uid: data['uid'] ?? '',
      visibility: data['visibility'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      createdDateTime: createdDateTime,
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      placeId: data['placeId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorId: data['authorId'] ?? '',
      tourguidePlaces: tourguidePlaces,
    );
  }

  Tour copyWith({
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? placeId,
    String? authorName,
    String? authorId,
    List<TourguidePlace>? tourguidePlaces,
  }) {
    return Tour(
      id: this.id,
      name: this.name,
      description: this.description,
      city: this.city,
      uid: this.uid,
      visibility: this.visibility,
      imageUrl: imageUrl ?? this.imageUrl,
      createdDateTime: this.createdDateTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      authorName: authorName ?? this.authorName,
      authorId: authorId ?? this.authorId,
      tourguidePlaces: tourguidePlaces ?? this.tourguidePlaces,
    );
  }

  @override
  String toString() {
    return 'Tour{id: $id, name: $name, description: $description, city: $city, uid: $uid, visibility: $visibility, imageUrl: $imageUrl, createdDateTime: $createdDateTime, latitude: $latitude, longitude: $longitude, placeId: $placeId, authorName: $authorName, authorId: $authorId, tourguidePlaces: ${tourguidePlaces.toString()}}';
  }
}


class TourService {
  static Future<List<Tour>> fetchAllTours() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    FirebaseStorage storage = FirebaseStorage.instance;
    FirebaseAuth auth = FirebaseAuth.instance;

    List<Tour> tours = [];

    try {
      // Ensure user is signed in
      User? user = auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      // Query Firestore for public tours or user's own tours
      QuerySnapshot querySnapshot = await db.collection('tours')
          .where('visibility', isEqualTo: 'public')
          .get();

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Ensure the user can read this tour based on security rules
        if (data['visibility'] == 'public' || data['uid'] == user.uid) {
          Tour tour = Tour.fromFirestore(doc);

          // Fetch image URL from Firebase Storage if imageUrl is not empty
          if (tour.imageUrl.isNotEmpty) {
            try {
              // Extract the path from the full URL
              String fullUrl = tour.imageUrl;
              Uri uri = Uri.parse(fullUrl);
              String path = uri.path.replaceFirst('/v0/b/tourguide-firebase.appspot.com/o/', '').replaceAll('%2F', '/');
              //logger.t(path);

              String imageUrl = await storage.ref(path).getDownloadURL();
              tour = tour.copyWith(imageUrl: imageUrl); // Update Tour object with image URL
            } catch (e) {
              logger.e('Error fetching image: $e');
            }
          }

          tours.add(tour);
        }
      }
    } catch (e) {
      logger.e('Error fetching tours: $e');
    }

    return tours;
  }

  static Future<List<Tour>> fetchAndSortToursByDateTime() async {
    List<Tour> tours = await fetchAllTours();

    // Sort tours by createdDateTime in descending order (most recent first),
    // treating null values as older dates (moving them to the end)
    tours.sort((a, b) {
      if (a.createdDateTime == null && b.createdDateTime == null) {
        return 0;
      } else if (a.createdDateTime == null) {
        return 1; // Move null date to the end
      } else if (b.createdDateTime == null) {
        return -1; // Move null date to the end
      } else {
        return b.createdDateTime!.compareTo(a.createdDateTime!);
      }
    });

    return tours;
  }
}
