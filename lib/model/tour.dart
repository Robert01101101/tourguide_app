import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Tour {
  final String id;
  final String name;
  final String description;
  final String city;
  final String uid;
  final String visibility;
  final String imageUrl;
  final DateTime createdDateTime;

  Tour({
    required this.id,
    required this.name,
    required this.description,
    required this.city,
    required this.uid,
    required this.visibility,
    required this.imageUrl,
    required this.createdDateTime,
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
      createdDateTime = DateTime.now(); // Default value or handle as needed
    }

    return Tour(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      city: data['city'] ?? '',
      uid: data['uid'] ?? '',
      visibility: data['visibility'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      createdDateTime: createdDateTime ?? DateTime.now(), // Ensure createdDateTime is not null
    );
  }

  Tour copyWith({String? imageUrl}) {
    return Tour(
      id: this.id,
      name: this.name,
      description: this.description,
      city: this.city,
      uid: this.uid,
      visibility: this.visibility,
      imageUrl: imageUrl ?? this.imageUrl,
      createdDateTime: this.createdDateTime,
    );
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
              String imageUrl = await storage.ref(tour.imageUrl).getDownloadURL();
              tour = tour.copyWith(imageUrl: imageUrl); // Update Tour object with image URL
            } catch (e) {
              print('Error fetching image: $e');
            }
          }

          tours.add(tour);
        }
      }
    } catch (e) {
      print('Error fetching tours: $e');
    }

    return tours;
  }
}