import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';

import '../../model/tour_comment.dart';
import '../../model/tour_rating.dart';

class TourService {
  // ---------------------------- Hive ----------------------------
  static String popularToursBoxName = 'popularToursBox';
  static String localToursBoxName = 'localToursBox';
  static String globalToursBoxName = 'globalToursBox';
  static String userCreatedToursBoxName = 'userCreatedToursBox';
  static String userSavedToursBoxName = 'userSavedToursBox';

  // Retrieve tours from a specific box
  static Future<List<Tour>> getToursFromHive(String boxName) async {
    logger.t('Getting tours from Hive box: $boxName');
    final box = await Hive.openBox<Tour>(boxName);
    return box.values.toList();
  }

  //TODO
  // Delete a specific tour from the box
  static Future<void> deleteTourFromHive(String boxName, String tourId) async {
    logger.t('Deleting tour from Hive box: $boxName');
    final box = await Hive.openBox<Tour>(boxName);
    await box.delete(tourId); // Delete the tour by its id
  }

  // Update all tours in the box
  static Future<void> overwriteToursInHive(
      String boxName, List<Tour> newTours) async {
    logger.t('Overwriting tours in Hive box: $boxName');
    final box = await Hive.openBox<Tour>(boxName);
    await box.clear(); // Clear existing data
    for (Tour tour in newTours) {
      await box.put(tour.id, tour); // Add the new tour
    }
  }

  // ---------------------------- Fetch ----------------------------

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

      logger.t(
          'fetchAllTours() all requirements ready, fetching ${getFormattedTime()}');
      QuerySnapshot querySnapshot = await db
          .collection('tours')
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
              String path = uri.path
                  .replaceFirst('/v0/b/tourguide-firebase.appspot.com/o/', '')
                  .replaceAll('%2F', '/');

              String imageUrl = await storage.ref(path).getDownloadURL();
              tour = tour.copyWith(imageUrl: imageUrl);
            } catch (e) {
              logger.e('Error fetching image: $e');
            }
          }

          tours.add(tour);
        }
      }
      logger.t(
          'fetchAllTours() finished getting all tours ${getFormattedTime()}, total tours: ${tours.length}');
    } catch (e) {
      logger.e('Error fetching tours: $e');
    }

    return tours;
  }

  /// Attempts to delete a Tour and returns true if successful
  static Future<bool> deleteTour(Tour tour) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      // Reference to the tour document
      DocumentReference tourRef = db.collection('tours').doc(tour.id);

      deleteTourImage(tourRef);

      // Get ratings sub-collection
      QuerySnapshot ratingsSnapshot = await tourRef.collection('ratings').get();

      // Delete all documents in the ratings sub-collection
      for (QueryDocumentSnapshot doc in ratingsSnapshot.docs) {
        await doc.reference.delete();
      }

      // After deleting sub-collections, delete the tour document
      await tourRef.delete();

      logger.t(
          'Tour with ID ${tour.id} and its sub-collections successfully deleted');
      return true;
    } catch (e) {
      logger.e('Error deleting tour with ID ${tour.id}: $e');
      return false;
    }
  }

  static Future<void> deleteTourImage(DocumentReference tourDocReference) async {
    String imageUrl = '';
    try {
      // Get the image URL from the tour document
      DocumentSnapshot tourDoc = await tourDocReference.get();
      imageUrl = tourDoc['imageUrl'];

      // Step 1: Delete the image from Firebase Storage
      if (imageUrl.isNotEmpty) {
        Reference storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
        // Delete the image
        await storageRef.delete();
        logger.i('Image at $imageUrl successfully deleted from Firebase Storage');
      }
    } catch (e, stack) {
      logger.e('Error deleting image from Firebase Storage with url $imageUrl:\n$e, stack: $stack');
    }
  }

  /// Gets the rating of this tour by this user
  static Future<Tour> checkUserRating(Tour tour, String userId) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    CollectionReference ratings =
        db.collection('tours').doc(tour.id).collection('ratings');
    QuerySnapshot querySnapshot =
        await ratings.where('userId', isEqualTo: userId).get();

    if (querySnapshot.docs.isNotEmpty) {
      DocumentSnapshot ratingDoc = querySnapshot.docs.first;
      Rating rating = Rating.fromMap(ratingDoc.data() as Map<String, dynamic>);
      tour.thisUsersRating = rating.value;
    } else {
      tour.thisUsersRating = 0; // User hasn't rated
    }
    return tour;
  }

  static Future<void> getUserRatingsForTours(
      Map<String, Tour> allCachedTours, List<String> realTourIds, String userId) async {
    logger.t('Fetching user ratings for all tours. Tour count: ${allCachedTours.length}');
    try {
      // Step 1: Create a map to hold all ratings for these tours
      Map<String, int> ratingsMap = {};

      // Fetch ratings in batches to avoid too many simultaneous requests
      int batchSize = 10;
      for (int i = 0; i < realTourIds.length; i += batchSize) {
        List<String> batchTourIds = realTourIds.skip(i).take(batchSize).toList();

        // Fetch ratings for the current batch
        await Future.wait(batchTourIds.map((tourId) async {
          //logger.t('Fetching user ratings for tour: $tourId');
          CollectionReference ratingsCollection = FirebaseFirestore.instance
              .collection('tours')
              .doc(tourId)
              .collection('ratings');
          QuerySnapshot querySnapshot =
              await ratingsCollection.where('userId', isEqualTo: userId).get();

          if (querySnapshot.docs.isNotEmpty) {
            DocumentSnapshot ratingDoc = querySnapshot.docs.first;
            Rating rating =
                Rating.fromMap(ratingDoc.data() as Map<String, dynamic>);
            ratingsMap[tourId] = rating.value;
          } else {
            ratingsMap[tourId] = 0; // User hasn't rated this tour
          }
        }));

        // Optional: Introduce a delay between batches to avoid rate limits
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Step 2: Update the tours with their ratings
      for (var entry in ratingsMap.entries) {
        String tourId = entry.key;
        int userRating = entry.value;

        if (allCachedTours.containsKey(tourId)) {
          allCachedTours[tourId]!.thisUsersRating = userRating;
        }
      }
    } catch (error, stack) {
      logger.e('Error fetching user ratings.\nAll tour ids: ${allCachedTours.keys.join(', ')}\nError: $error, Stack: $stack');
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

  static Future<void> downloadAndSaveImage(
      String imageUrl, String tourId) async {
    logger.t('downloadAndSaveImage for tourId: $tourId, imageUrl: $imageUrl');
    if (imageUrl.isEmpty || tourId.isEmpty) {
      logger.t('Image URL or id is empty, cannot download image');
      return;
    }
    try {
      // Step 1: Download the image
      final http.Response response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        // Step 2: Get the content type
        final String? contentType = response.headers['content-type'];

        // Determine the file extension based on content type
        String fileExtension = '';
        switch (contentType) {
          case 'image/jpeg':
          case 'image/jpg':
            fileExtension = 'jpg';
            break;
          case 'image/png':
            fileExtension = 'png';
            break;
          case 'image/webp':
            fileExtension = 'webp';
            break;
          case 'image/gif':
            fileExtension = 'gif';
            break;
          case 'image/bmp':
            fileExtension = 'bmp';
            break;
          case 'image/tiff':
            fileExtension = 'tiff';
            break;
          default:
            logger.w('Unsupported content type: $contentType');
            return;
        }

        // Step 3: Get the local file path
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        final Directory tourImgsDir = Directory('${appDocDir.path}/tourImgs');
        if (!await tourImgsDir.exists()) {
          await tourImgsDir.create(recursive: true);
        }
        final String localPath =
            '${appDocDir.path}/tourImgs/$tourId.$fileExtension';
        final File file = File(localPath);

        // Step 4: Write the file to the local storage
        await file.writeAsBytes(response.bodyBytes);
        logger.i('Image downloaded and saved to $localPath');
      } else {
        logger.e('Error downloading image: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error: $e');
    }
  }

  static Future<File?> getLocalImageFile(String tourId) async {
    if (kIsWeb) return null;
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final List<String> extensions = [
      'jpg',
      'png',
      'webp',
      'gif',
      'bmp',
      'tiff'
    ];
    for (String extension in extensions) {
      final String localPath = '${appDocDir.path}/tourImgs/$tourId.$extension';
      final File file = File(localPath);
      if (await file.exists()) {
        logger.i('Local image found for tourId: $tourId');
        return file;
      }
    }
    return null;
  }

  ////////// Fetch with Filters (New) //////////
  static Future<List<Tour>> fetchPopularToursNearYou(
      double userLatitude, double userLongitude) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      QuerySnapshot querySnapshot = await db
          .collection('tours')
          .where('visibility', isEqualTo: 'public')
          .where('latitude',
              isGreaterThanOrEqualTo: userLatitude - 0.9) // approximately 50km
          .where('latitude', isLessThanOrEqualTo: userLatitude + 0.9)
          .where('longitude', isGreaterThanOrEqualTo: userLongitude - 0.9)
          .where('longitude', isLessThanOrEqualTo: userLongitude + 0.9)
          .where('upvotes', isGreaterThanOrEqualTo: 1)
          .orderBy('upvotes', descending: true) //sort by upvotes
          .get();

      List<Tour> tours =
          querySnapshot.docs.map((doc) => Tour.fromFirestore(doc)).toList();

      return tours.where((tour) {
        //double distance = LocationProvider.calculateDistance(userLatitude, userLongitude, tour.latitude, tour.longitude);
        double upvoteRatio = tour.downvotes == 0
            ? tour.upvotes.toDouble() * 2
            : tour.upvotes / tour.downvotes;
        logger.t(
            'finished fetching and processing popular tours near you, total tours: ${tours.length}, current time: ${getFormattedTime()}');
        return tour.upvotes > 0 && upvoteRatio >= 2.0; //&& distance <= 30;
      }).toList();
    } catch (e) {
      logger.e('Error fetching popular tours near you: $e');
      return [];
    }
  }

  static Future<List<Tour>> fetchLocalTours(
      double userLatitude, double userLongitude) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      QuerySnapshot querySnapshot = await db
          .collection('tours')
          .where('visibility', isEqualTo: 'public')
          .where('latitude',
              isGreaterThanOrEqualTo:
                  userLatitude - 0.225) // approximately 25km
          .where('latitude', isLessThanOrEqualTo: userLatitude + 0.225)
          .where('longitude', isGreaterThanOrEqualTo: userLongitude - 0.225)
          .where('longitude', isLessThanOrEqualTo: userLongitude + 0.225)
          .get();

      List<Tour> tours =
          querySnapshot.docs.map((doc) => Tour.fromFirestore(doc)).toList();
      logger.t('finished fetching local tours, total tours: ${tours.length}');

      //sort by distance
      tours.sort((a, b) {
        double distanceA = LocationProvider.calculateDistance(
            userLatitude, userLongitude, a.latitude, a.longitude);
        double distanceB = LocationProvider.calculateDistance(
            userLatitude, userLongitude, b.latitude, b.longitude);
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
      QuerySnapshot querySnapshot = await db
          .collection('tours')
          .where('authorId', isEqualTo: userId)
          .orderBy('createdDateTime',
              descending: true) //sort by created date time
          .get();

      List<Tour> tours =
          querySnapshot.docs.map((doc) => Tour.fromFirestore(doc)).toList();

      logger.t(
          'finished fetching user created tours, total tours: ${tours.length}');

      return tours;
    } catch (e, stack) {
      logger.e(
          'Error fetching user created tours: $e \nuserId=$userId \nstack: $stack');
      return [];
    }
  }

  static Future<List<Tour>> fetchUserSavedTours(
      List<String> userSavedTours) async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      // Check if userSavedTours is not empty to avoid unnecessary queries
      if (userSavedTours.isEmpty) {
        logger.t('No saved tours for the user.');
        return [];
      }

      // Fetch tours where the document ID is in the user's saved tours
      QuerySnapshot querySnapshot = await db
          .collection('tours')
          .where(FieldPath.documentId,
              whereIn: userSavedTours) // Query based on document IDs
          .orderBy('createdDateTime',
              descending: true) // Sort by created date time
          .get();

      List<Tour> tours =
          querySnapshot.docs.map((doc) => Tour.fromFirestore(doc)).toList();

      logger.t(
          'Finished fetching user saved tours, total tours: ${tours.length}');

      return tours;
    } catch (e, stack) {
      logger.e(
          'Error fetching user saved tours: $e \nuserSavedTours=$userSavedTours \nstack: $stack');
      return [];
    }
  }

  static Future<List<Tour>> fetchPopularToursAroundTheWorld() async {
    FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      QuerySnapshot querySnapshot = await db
          .collection('tours')
          .where('visibility', isEqualTo: 'public')
          .orderBy('upvotes', descending: true)
          .limit(10)
          .get();

      List<Tour> tours =
          querySnapshot.docs.map((doc) => Tour.fromFirestore(doc)).toList();
      logger.t(
          'finished fetching popular tours around the world, total tours: ${tours.length}');

      return tours;
    } catch (e) {
      logger.e('Error fetching popular tours around the world: $e');
      return [];
    }
  }

  ////////// Write //////////
  static Future<Tour> uploadTour(Tour tour) async {
    try {
      FirebaseFirestore db = FirebaseFirestore.instance;

      // Step 1: Add tour document to 'tours' collection
      DocumentReference tourDocRef =
          await db.collection("tours").add(tour.toMap());
      String tourId = tourDocRef.id; // Retrieve the auto-generated ID

      // Step 2: Upload image
      tour = tour.copyWith(id: tourId);
      String imageUrl = await uploadImage(tour);

      // Step 3: Update the Tour's ID and imageUrl fields
      await db.collection("tours").doc(tourId).update({
        'id': tour.id,
        'imageUrl': imageUrl,
      });

      // Step 4: add empty rating for user to generate ratings collection
      await addOrUpdateRating(tour.id, 0, tour.authorId);

      // Step 5: Retrieve the full tour document after updating
      DocumentSnapshot tourSnapshot = await tourDocRef.get();
      Tour uploadedTourFromFirestore = Tour.fromFirestore(tourSnapshot);

      logger.i('Successfully created tour: ${tour.toString()}');
      downloadAndSaveImage(imageUrl, tourId);
      return uploadedTourFromFirestore.copyWith(imageFile: tour.imageFile, imageFileToUploadWeb: tour.imageFileToUploadWeb);
    } catch (e, stack) {
      //log with stack
      logger.e('Error uploading tour: $e, stack: $stack');
      return tour;
    }
  }

  static Future<Tour> updateTour(Tour tour) async {
    try {
      if (tour.imageFile != null) {
        // Delete the old image
        DocumentReference tourRef = FirebaseFirestore.instance.collection('tours').doc(tour.id);
        deleteTourImage(tourRef);
        // Upload the new image
        String newImageUrl = await uploadImage(tour);
        tour = tour.copyWith(imageUrl: newImageUrl);
      }
      await FirebaseFirestore.instance
          .collection('tours')
          .doc(tour.id)
          .set(tour.toMap(), SetOptions(merge: true));

      //TODO: Image update
      /*
      if (tour.imageUrl.isNotEmpty) {
        String newImageUrl = await uploadImage(tour);
        await db.collection('tours').doc(tour.id).update({
          'imageUrl': newImageUrl,
        });
      }*/

      logger.i('Successfully updated tour: ${tour.toString()}');
      return tour;
    } catch (e, stack) {
      logger.e('Error updating tour: $e, stack: $stack');
      return tour; // or handle differently based on your needs
    }
  }

  static Future<String> uploadImage(Tour tour) async {
    try {
      // Create a reference to the location you want to upload to in Firebase Storage
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('tour_images')
          .child(tour.authorId)
          .child(
              tour.id); // Use the tourId to associate the image with the tour

      // Handle the upload based on platform
      if (kIsWeb) {
        // Web platform
        if (tour.imageFileToUploadWeb != null) {
          // Convert XFile to Uint8List
          final Uint8List imageData =
              await tour.imageFileToUploadWeb!.readAsBytes();

          // Get the MIME type (if necessary, infer based on file extension)
          final String mimeType = tour.imageFileToUploadWeb!.mimeType ?? 'image/png';

          // Create metadata with the correct content type
          SettableMetadata metadata = SettableMetadata(contentType: mimeType);

          // Upload the data with the specified content type
          UploadTask uploadTask = ref.putData(imageData, metadata);

          // Await the completion of the upload task
          TaskSnapshot taskSnapshot = await uploadTask;

          // Upon completion, get the download URL for the image
          String imageUrl = await taskSnapshot.ref.getDownloadURL();

          return imageUrl;
        } else {
          throw ArgumentError('No image file provided for upload.');
        }
      } else {
        // Mobile or other non-web platforms
        if (tour.imageFile != null) {
          UploadTask uploadTask = ref.putFile(File(tour.imageFile!.path));

          // Await the completion of the upload task
          TaskSnapshot taskSnapshot = await uploadTask;

          // Upon completion, get the download URL for the image
          String imageUrl = await taskSnapshot.ref.getDownloadURL();

          return imageUrl;
        } else {
          throw ArgumentError('No image file provided for upload.');
        }
      }
    } catch (e, stack) {
      // Handle errors, if any
      logger.e('Error uploading image: $e, stack: $stack');
      return '';
    }
  }

  static Future<void> updateAuthorNameForAllTheirTours(
      String authorId, String authorNewName) async {
    try {
      // Step 1: Query Firestore for all tours with the given authorId
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('tours')
          .where('authorId', isEqualTo: authorId)
          .get();

      // Step 2: Update each document's authorName field
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        batch.update(doc.reference, {'authorName': authorNewName});
      }

      // Step 3: Commit the batch write
      await batch.commit();
      logger.t('Author name updated successfully for all their tours.');
    } catch (e, stack) {
      logger.e('Failed to update author name: $e, $stack');
    }
  }

  static Future<void> addComment(String tourId, Comment comment) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    CollectionReference comments =
        db.collection('tours').doc(tourId).collection('comments');

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
    CollectionReference comments =
        db.collection('tours').doc(tourId).collection('comments');

    QuerySnapshot querySnapshot =
        await comments.orderBy('timestamp', descending: true).get();

    return querySnapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
  }

  static Future<void> addOrUpdateRating(
      String tourId, int value, String userId) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    CollectionReference ratings =
        db.collection('tours').doc(tourId).collection('ratings');
    DocumentReference tourRef = db.collection('tours').doc(tourId);

    try {
      // Create or update the rating
      QuerySnapshot querySnapshot =
          await ratings.where('userId', isEqualTo: userId).get();
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
    CollectionReference ratings =
        db.collection('tours').doc(tourId).collection('ratings');

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
