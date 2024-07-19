import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';


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
      logger.t('fetchAllTours() finished getting all tours ${getFormattedTime()}, total tours: ${tours.length}');
    } catch (e) {
      logger.e('Error fetching tours: $e');
    }

    return tours;
  }

  static Future<void> deleteTour(Tour tour) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      // Delete the tour document
      await db.collection('tours').doc(tour.id).delete();
      logger.t('Tour with ID ${tour.id} successfully deleted');
    } catch (e) {
      logger.e('Error deleting tour with ID  ${tour.id}: $e');
    }
  }

  /// Gets the rating of this tour by this user
  static Future<Tour> checkUserRating(Tour tour, String userId) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    CollectionReference ratings = db.collection('tours').doc(tour.id).collection('ratings');
    QuerySnapshot querySnapshot = await ratings.where('userId', isEqualTo: userId).get();

    if (querySnapshot.docs.isNotEmpty) {
      DocumentSnapshot ratingDoc = querySnapshot.docs.first;
      Rating rating = Rating.fromMap(ratingDoc.data() as Map<String, dynamic>);
      tour.thisUsersRating = rating.value;
    } else {
      tour.thisUsersRating = 0; // User hasn't rated
    }
    return tour;
  }

  static Future<void> getUserRatingsForTours(Map<String, Tour> allCachedTours, String userId) async {
    try {
      // Step 1: Collect all tour IDs
      List<String> tourIds = allCachedTours.keys.toList();

      // Step 2: Create a map to hold all ratings for these tours
      Map<String, int> ratingsMap = {};

      // Fetch ratings in batches to avoid too many simultaneous requests
      int batchSize = 10;
      for (int i = 0; i < tourIds.length; i += batchSize) {
        List<String> batchTourIds = tourIds.skip(i).take(batchSize).toList();

        // Fetch ratings for the current batch
        await Future.wait(batchTourIds.map((tourId) async {
          CollectionReference ratingsCollection = FirebaseFirestore.instance
              .collection('tours')
              .doc(tourId)
              .collection('ratings');
          QuerySnapshot querySnapshot = await ratingsCollection
              .where('userId', isEqualTo: userId)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            DocumentSnapshot ratingDoc = querySnapshot.docs.first;
            Rating rating = Rating.fromMap(ratingDoc.data() as Map<String, dynamic>);
            ratingsMap[tourId] = rating.value;
          } else {
            ratingsMap[tourId] = 0; // User hasn't rated this tour
          }
        }));

        // Optional: Introduce a delay between batches to avoid rate limits
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Step 3: Update the tours with their ratings
      for (var entry in ratingsMap.entries) {
        String tourId = entry.key;
        int userRating = entry.value;

        if (allCachedTours.containsKey(tourId)) {
          allCachedTours[tourId]!.thisUsersRating = userRating;
        }
      }
    } catch (error) {
      print('Error fetching user ratings: $error');
    }
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

  ////////// Fetch with Filters (New) //////////
  static Future<List<Tour>> fetchPopularToursNearYou(double userLatitude, double userLongitude) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      QuerySnapshot querySnapshot = await db.collection('tours')
          .where('visibility', isEqualTo: 'public')
          .where('latitude', isGreaterThanOrEqualTo: userLatitude - 0.45 )  // approximately 50km
          .where('latitude', isLessThanOrEqualTo: userLatitude + 0.45)
          .where('longitude', isGreaterThanOrEqualTo: userLongitude - 0.45)
          .where('longitude', isLessThanOrEqualTo: userLongitude + 0.45)
          .where('upvotes', isGreaterThanOrEqualTo: 1)
          .orderBy('upvotes', descending: true) //sort by upvotes
          .get();

      List<Tour> tours = querySnapshot.docs.map((doc) => Tour.fromFirestore(doc)).toList();
      logger.t('finished fetching popular tours near you ($userLatitude, $userLongitude), total tours: ${tours.length}');

      return tours.where((tour) {
        //double distance = LocationProvider.calculateDistance(userLatitude, userLongitude, tour.latitude, tour.longitude);
        double upvoteRatio = tour.downvotes == 0 ? tour.upvotes.toDouble() * 2 : tour.upvotes / tour.downvotes;
        logger.t('finished fetching and processing popular tours near you, total tours: ${tours.length}, current time: ${getFormattedTime()}');
        return tour.upvotes > 0 && upvoteRatio >= 2.0; //&& distance <= 30;
      }).toList();
    } catch (e) {
      logger.e('Error fetching popular tours near you: $e');
      return [];
    }
  }

  static Future<List<Tour>> fetchLocalTours(double userLatitude, double userLongitude) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      QuerySnapshot querySnapshot = await db.collection('tours')
          .where('visibility', isEqualTo: 'public')
          .where('latitude', isGreaterThanOrEqualTo: userLatitude - 0.225)  // approximately 25km
          .where('latitude', isLessThanOrEqualTo: userLatitude + 0.225)
          .where('longitude', isGreaterThanOrEqualTo: userLongitude - 0.225)
          .where('longitude', isLessThanOrEqualTo: userLongitude + 0.225)
          .get();

      List<Tour> tours = querySnapshot.docs.map((doc) => Tour.fromFirestore(doc)).toList();
      logger.t('finished fetching local tours, total tours: ${tours.length}');

      //sort by distance
      tours.sort((a, b) {
        double distanceA = LocationProvider.calculateDistance(userLatitude, userLongitude, a.latitude, a.longitude);
        double distanceB = LocationProvider.calculateDistance(userLatitude, userLongitude, b.latitude, b.longitude);
        return distanceA.compareTo(distanceB);
      });

      return tours;
    } catch (e) {
      logger.e('Error fetching local tours: $e');
      return [];
    }
  }

  static Future<List<Tour>> fetchUserCreatedTours(String userId) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      QuerySnapshot querySnapshot = await db.collection('tours')
          .where('authorId', isEqualTo: userId)
          .orderBy('createdDateTime', descending: true) //sort by created date time
          .get();

      List<Tour> tours = querySnapshot.docs.map((doc) => Tour.fromFirestore(doc)).toList();

      logger.t('finished fetching user created tours, total tours: ${tours.length}');

      return tours;
    } catch (e, stack) {
      logger.e('Error fetching user created tours: $e \nuserId=$userId \nstack: $stack');
      return [];
    }
  }

  static Future<List<Tour>> fetchUserSavedTours(String userId) async {
    // Implement the logic to fetch saved tours for the user from Firestore if you have a saved tours collection
    return List.generate(4, (index) => Tour.empty());
  }

  static Future<List<Tour>> fetchPopularToursAroundTheWorld() async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      QuerySnapshot querySnapshot = await db.collection('tours')
          .where('visibility', isEqualTo: 'public')
          .orderBy('upvotes', descending: true)
          .limit(10)
          .get();

      List<Tour> tours = querySnapshot.docs.map((doc) => Tour.fromFirestore(doc)).toList();
      logger.t('finished fetching popular tours around the world, total tours: ${tours.length}');

      return tours;
    } catch (e) {
      logger.e('Error fetching popular tours around the world: $e');
      return [];
    }
  }

  static Future<Tour> uploadTour(Tour tour) async{
    try {
      FirebaseFirestore db = FirebaseFirestore.instance;

      // Step 1: Add tour document to 'tours' collection
      DocumentReference tourDocRef = await db.collection("tours").add(tour.toMap());
      String tourId = tourDocRef.id; // Retrieve the auto-generated ID

      // Step 2: Upload image
      String imageUrl = await uploadImage(tour);

      // Step 3: Update the Tour's ID and imageUrl fields
      tour = tour.copyWith(id: tourId);
      await db.collection("tours").doc(tourId).update({
        'id': tour.id,
        'imageUrl': imageUrl,
      });

      // Step 4: add empty rating for user
      await addOrUpdateRating(tour.id, 0, tour.authorId);

      tour.isOfflineCreatedTour = false;

      logger.i('Successfully created tour: ${tour.toString()}');
      return tour;
    } catch (e, stack) {
      //log with stack
      logger.e('Error uploading tour: $e, stack: $stack');
      return tour;
    }
  }

  static Future<String> uploadImage(Tour tour) async {
    try {
      // Create a reference to the location you want to upload to in Firebase Storage
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('tour_images')
          .child(tour.id);  // Use the tourId to associate the image with the tour

      // Upload the file to Firebase Storage
      UploadTask uploadTask = ref.putFile(tour.imageToUpload!);

      // Await the completion of the upload task
      TaskSnapshot taskSnapshot = await uploadTask;

      // Upon completion, get the download URL for the image
      String imageUrl = await taskSnapshot.ref.getDownloadURL();

      return imageUrl;
    } catch (e, stack) {
      // Handle errors, if any
      logger.e('Error uploading image: $e, stack: $stack');
      return '';
    }
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