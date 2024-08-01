import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/model/tourguide_report.dart';
import 'package:tourguide_app/model/tourguide_user.dart';
import 'package:tourguide_app/utilities/services/tour_service.dart';

//TODO: optimize
class TourProvider with ChangeNotifier {
  List<Tour> _popularTours = List.generate(4, (index) => Tour.empty());
  List<Tour> _localTours = List.generate(4, (index) => Tour.empty());
  List<Tour> _globalTours = List.generate(4, (index) => Tour.empty());
  List<Tour> _userCreatedTours = List.generate(1, (index) => Tour.isAddTourTile());
  List<Tour> _userSavedTours = List.empty();
  /// Not in any particular order, as it is assembled from the individual fetches which each have their own sorting
  Map<String, Tour> _allCachedTours = {};
  Tour? _selectedTour;
  bool _isLoadingTours = false;

  List<Tour> get popularTours => _popularTours;
  List<Tour> get localTours => _localTours;
  List<Tour> get globalTours => _globalTours;
  List<Tour> get userCreatedTours => _userCreatedTours;
  List<Tour> get userSavedTours => _userSavedTours;
  Tour? get selectedTour => _selectedTour;
  bool get isLoadingTours => _isLoadingTours;

  TourProvider() {
    _init();
  }

  // Initialization method
  Future<void> _init() async {
    logger.t("TourProvider._init()");
  }



  Future<void> fetchAndSetTours(double userLatitude, double userLongitude, String userId, List<String> userSavedTours) async {
    try {
      logger.t("fetchAndSetTours ${getFormattedTime()}");
      _isLoadingTours = true;

      // Step 1: Get tours from Hive
      _popularTours = _processToursAndUpdateCachedTours(await TourService.getToursFromHive(TourService.popularToursBoxName), userId);
      _localTours = _processToursAndUpdateCachedTours(await TourService.getToursFromHive(TourService.localToursBoxName), userId);
      _globalTours = _processToursAndUpdateCachedTours(await TourService.getToursFromHive(TourService.globalToursBoxName), userId);
      _userCreatedTours = _processToursAndUpdateCachedTours(await TourService.getToursFromHive(TourService.userCreatedToursBoxName), userId);
      _userSavedTours = _processToursAndUpdateCachedTours(await TourService.getToursFromHive(TourService.userSavedToursBoxName), userId);
      logger.t("fetchAndSetTours - finished getting tours from Hive ${getFormattedTime()}");
      notifyListeners();

      // Step 2: Fetch updated tours from Firestore
      _popularTours = _processToursAndUpdateCachedTours(await TourService.fetchPopularToursNearYou(userLatitude, userLongitude), userId);
      _localTours = _processToursAndUpdateCachedTours(await TourService.fetchLocalTours(userLatitude, userLongitude), userId);
      _globalTours = _processToursAndUpdateCachedTours(await TourService.fetchPopularToursAroundTheWorld(), userId);
      _userCreatedTours = _processToursAndUpdateCachedTours(await TourService.fetchUserCreatedTours(userId), userId);
      _userSavedTours = _processToursAndUpdateCachedTours(await TourService.fetchUserSavedTours(userSavedTours), userId);
      notifyListeners();

      // Step 3: Update Hive with new data  //TODO: optimize
      await TourService.overwriteToursInHive(TourService.popularToursBoxName, _popularTours);
      await TourService.overwriteToursInHive(TourService.localToursBoxName, _localTours);
      await TourService.overwriteToursInHive(TourService.globalToursBoxName, _globalTours);
      await TourService.overwriteToursInHive(TourService.userCreatedToursBoxName, _userCreatedTours);
      await TourService.overwriteToursInHive(TourService.userSavedToursBoxName, _userSavedTours);
      _formatListsAndGetTourRatings(userId);

      // Step 4: Download images in parallel
      logger.t("fetchAndSetTours - starting image downloads ${getFormattedTime()}");
      await Future.wait(_allCachedTours.values.map((tour) => _setTourImage(tour)).toList());
      logger.t("fetchAndSetTours - image downloads complete ${getFormattedTime()}");
      notifyListeners();
    } catch (error) {
      logger.e('Error fetching tours: $error');
    }
  }

  //TODO: fix that this won't update if image changes
  Future<void> _setTourImage(Tour tour) async {
    final File? localImage = await TourService.getLocalImageFile(tour.id);
    if (localImage != null && !tour.requestMediaRedownload) {
      tour.imageFile = localImage;
    } else {
      if (tour.requestMediaRedownload) logger.t('Requesting image redownload: ${tour.id}');
      await TourService.downloadAndSaveImage(tour.imageUrl, tour.id);
      final File? downloadedImage = await TourService.getLocalImageFile(tour.id);
      if (downloadedImage != null) {
        tour.imageFile = downloadedImage;
      }
    }
  }

  List<Tour> _processToursAndUpdateCachedTours(List<Tour> tours, String userId) {
    try {
      List<Tour> updatedTours = [];
      for (Tour tour in tours) {
        logger.t('Processing tour: ${tour.id}');
        if (tour.reports.length > 0 && tour.authorId != userId) {
          logger.w('Tour has reports, removing: ${tour.id}');
          continue; // Skip tours with reports
        }
        if (_allCachedTours.containsKey(tour.id)) {
          // Use the existing tour instance from the cache, unless media redownload requested
          bool requestMediaRedownload = tour.lastChangedDateTime == null ||
              _allCachedTours[tour.id]!.lastChangedDateTime == null ||
              tour.lastChangedDateTime!.isAfter(_allCachedTours[tour.id]!.lastChangedDateTime!);
          if (requestMediaRedownload) {
            logger.t('${tour.id} needs media redownload, last changed: ${tour.lastChangedDateTime} vs cached ${_allCachedTours[tour.id]!.lastChangedDateTime}');
            tour.requestMediaRedownload = true;
            _allCachedTours[tour.id] = tour;
          } else {
            // Use the existing tour instance from the cache
            updatedTours.add(_allCachedTours[tour.id]!);
          }
        } else {
          // Add the new tour to the cache and the updated list
          _allCachedTours[tour.id] = tour;
          updatedTours.add(tour);
        }
      }
      return updatedTours;
    } catch (e, stack) {
      logger.e('Error processing tours: $e, $stack');
      return List.empty();
    }
  }

  Future<void> _formatListsAndGetTourRatings(String userId) async {
    logger.t('_formatListsAndGetTourRatings ${getFormattedTime()} ');
    //add empty tour if no tours
    if (_popularTours.isEmpty) _popularTours = List.generate(1, (index) => Tour.isAddTourTile());
    if (_localTours.isEmpty) _localTours = List.generate(1, (index) => Tour.isAddTourTile());
    if (_globalTours.isEmpty) _globalTours = List.generate(1, (index) => Tour.isAddTourTile());
    if (_userCreatedTours.isEmpty) {
      _userCreatedTours = List.generate(1, (index) => Tour.isAddTourTile());
    } else {
      _userCreatedTours.insert(0,Tour.isAddTourTile());
    }
    notifyListeners();

    logger.t('_formatListsAndGetTourRatings - get ratings (count: ${_allCachedTours.length})');
    await TourService.getUserRatingsForTours(_allCachedTours, userId);
    _isLoadingTours = false;
    notifyListeners();
  }

  Future<void> deleteTour(Tour tour) async{
    await TourService.deleteTour(tour);
    removeTourFromCachedTours(tour);
    notifyListeners();
  }

  void removeTourFromCachedTours(Tour tour) async{
    _allCachedTours.remove(tour.id);
    _popularTours.remove(tour);
    _globalTours.remove(tour);
    _localTours.remove(tour);
    _userCreatedTours.remove(tour);
    notifyListeners();
  }

  void clearSelectedTour() {
    _selectedTour = null;
    notifyListeners();
  }

  //TODO: get rid? What could I use this for? Select a tour that user has started? was used for details but no longer used for that
  void selectTourById(String id) {
    try {
      _selectedTour = _allCachedTours[id];
      logger.i(_selectedTour.toString());
      notifyListeners();
    } catch (e) {
      logger.e('Tour not found: $e');
    }
  }

  bool isUserCreatedTour(Tour tour) {
    if (tour.id.isEmpty) return false;
    return userCreatedTours.contains(tour);
  }

  Future<void> uploadTour(Tour tour) async{
    await TourService.uploadTour(tour);
    _allCachedTours[tour.id] = tour;
    _userCreatedTours.insert(1, tour);
    notifyListeners();
  }

  /// Updates the tour data in cache and firestore (for edits, reporting, etc)
  Future<Tour> updateTour(Tour tour) async{
    tour = await TourService.updateTour(tour);
    _allCachedTours[tour.id] = tour;
    notifyListeners();
    return _allCachedTours[tour.id]!;
  }

  /// for logout
  void resetTourProvider(){
    _selectedTour = null;
    _isLoadingTours = false;
    _allCachedTours = {};
    _popularTours = List.generate(4, (index) => Tour.empty());
    _localTours = List.generate(4, (index) => Tour.empty());
    _globalTours = List.generate(4, (index) => Tour.empty());
    _userCreatedTours = List.generate(1, (index) => Tour.isAddTourTile());
    _userSavedTours = List.empty();
    logger.t("TourProvider.resetTourProvider()");
  }

  //TODO: swap for approach where we use already cached list to avoid the first get call?
  Future<void> updateAuthorNameForAllTheirTours(String authorId, String newAuthorName) async {
    await TourService.updateAuthorNameForAllTheirTours(authorId, newAuthorName);
    notifyListeners();
  }

  // ____________________________ Reports ____________________________
  Future<void> reportTour(Tour tour, TourguideReport report, TourguideUser reportedTourAuthor) async{
    List<TourguideReport> newReports =  [...tour.reports, report];
    Tour reportedTour = tour.copyWith(reports: newReports, lastChangedDateTime: DateTime.now());

    logger.i('Tour reported: ${tour.id}');
    _notifyAdminOfReportOrReviewRequest(tour.id, reportTitle: report.title, reportDetails: report.additionalDetails);
    _notifyUserOfReport(tour, report, reportedTourAuthor);

    await updateTour(reportedTour);
    removeTourFromCachedTours(reportedTour);
  }

  Future<Tour> requestReviewOfTour(Tour tour) async{
    Tour tourToReview = tour.copyWith(requestReviewStatus: "requested", lastChangedDateTime: DateTime.now());

    logger.i('Tour Review requested: ${tour.id}');
    _notifyAdminOfReportOrReviewRequest(tour.id);

    return await updateTour(tourToReview);
  }

  //optional params String reportTitle, String reportDetails
  Future<void> _notifyAdminOfReportOrReviewRequest (String tourId, {String? reportTitle, String? reportDetails}) async {
    Map<String, dynamic> emailData = {
      'to': 'contact@tourguide.rmichels.com',
      'template': {
        'name': reportTitle != null ? 'report' : 'reportReviewRequest',
        'data': {
          'reportItem': 'Tour',
          'itemId': tourId,
          if (reportTitle != null) 'reportTitle': reportTitle,
          if (reportDetails != null) 'reportDetails': reportDetails,
        }
      },
    };

    await FirebaseFirestore.instance.collection('emails').add(emailData);
  }

  Future<void> _notifyUserOfReport (Tour tour, TourguideReport report, TourguideUser reportedTourAuthor) async {
    if (reportedTourAuthor.emailSubscriptionsDisabled.contains('reports')) {
      logger.t("UserProvider._notifyUserOfReport() - User is not subscribed to Report emails, skipping");
      return;
    }
    Map<String, dynamic> emailData = {
      'to': reportedTourAuthor.email,
      'template': {
        'name': 'userTourReported',
        'data': {
          'firstName': reportedTourAuthor.displayName.split(' ').first,
          'tourName': tour.name,
          'reportReason': report.title,
          'authId': reportedTourAuthor.firebaseAuthId,
        }
      },
      'userId': reportedTourAuthor!.firebaseAuthId,
    };

    await FirebaseFirestore.instance.collection('emails').add(emailData);
  }
}
