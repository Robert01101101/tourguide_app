import 'package:flutter_test/flutter_test.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/model/tourguide_place.dart';

void main() {
  group('Tour Model Tests', () {
    test('Tour fields are set and mapped correctly', () {
      DateTime now = DateTime.now();

      // Create a Tour instance
      final tour = Tour(
        id: 'testid',
        name: 'test name',
        description: 'test description',
        city: 'test city',
        visibility: 'public',
        imageUrl: 'testurl',
        createdDateTime: now,
        lastChangedDateTime: now,
        latitude: 49,
        longitude: -123,
        placeId: 'testplaceid',
        authorName: 'test author name',
        authorId: 'testauthorid',
        requestReviewStatus: '',
        tourguidePlaces: [
          TourguidePlace(
            latitude: 48,
            longitude: -122,
            googleMapPlaceId: 'testplaceid1',
            title: 'testplacetitle1',
            description: 'testplacedescription1',
            photoUrl: 'testplacephotourl1',
          ),
          TourguidePlace(
            latitude: 50,
            longitude: -124,
            googleMapPlaceId: 'testplaceid2',
            title: 'testplacetitle2',
            description: 'testplacedescription2',
            photoUrl: 'testplacephotourl2',
          ),
        ],
        reports: [],
        upvotes: 3,
        downvotes: 2,
        tags: {'testtag': 'testtagvalue'},
        isAddTourTile: false,
        isOfflineCreatedTour: false,
        imageFile: null,
        imageFileToUploadWeb: null,
      );

      // Verify that the properties are set correctly
      expect(tour.id, 'testid');
      expect(tour.name, 'test name');
      expect(tour.description, 'test description');
      expect(tour.city, 'test city');
      expect(tour.tourguidePlaces.length, 2);
      expect(tour.tourguidePlaces[0].title, 'testplacetitle1');
      expect(tour.tourguidePlaces[1].title, 'testplacetitle2');
      expect(tour.tags, {'testtag': 'testtagvalue'});
      expect(tour.upvotes, 3);
      expect(tour.downvotes, 2);
      expect(tour.visibility, 'public');
      expect(tour.imageUrl, 'testurl');
      expect(tour.createdDateTime, now);
      expect(tour.lastChangedDateTime, now);
      expect(tour.latitude, 49);
      expect(tour.longitude, -123);
      expect(tour.placeId, 'testplaceid');
      expect(tour.authorName, 'test author name');
      expect(tour.authorId, 'testauthorid');
      expect(tour.requestReviewStatus, '');
      expect(tour.isAddTourTile, false);
      expect(tour.isOfflineCreatedTour, false);
      expect(tour.imageFile, null);
      expect(tour.imageFileToUploadWeb, null);

      final tourMap = tour.toMap();

      expect(tourMap['id'], 'testid');
      expect(tourMap['name'], 'test name');
      expect(tourMap['description'], 'test description');
      expect(tourMap['city'], 'test city');
      expect(tourMap['visibility'], 'public');
      expect(tourMap['imageUrl'], 'testurl');
      expect(tourMap['createdDateTime'], now);
      expect(tourMap['lastChangedDateTime'], now);
      expect(tourMap['latitude'], 49);
      expect(tourMap['longitude'], -123);
      expect(tourMap['placeId'], 'testplaceid');
      expect(tourMap['authorName'], 'test author name');
      expect(tourMap['authorId'], 'testauthorid');
      expect(tourMap['requestReviewStatus'], '');
      expect(tourMap['upvotes'], 3);
      expect(tourMap['downvotes'], 2);
      expect(tourMap['tags'], {'testtag': 'testtagvalue'});
      expect(tourMap['tourguidePlaces'], [
        {
          'latitude': 48,
          'longitude': -122,
          'googleMapPlaceId': 'testplaceid1',
          'title': 'testplacetitle1',
          'description': 'testplacedescription1',
          'photoUrl': 'testplacephotourl1'
        },
        {
          'latitude': 50,
          'longitude': -124,
          'googleMapPlaceId': 'testplaceid2',
          'title': 'testplacetitle2',
          'description': 'testplacedescription2',
          'photoUrl': 'testplacephotourl2'
        },
      ]);
      expect(tourMap['reports'], []);
    });
  });
}
