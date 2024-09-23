import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/model/tourguide_report.dart';
import 'package:tourguide_app/model/tourguide_user.dart';
import 'package:tourguide_app/utilities/services/tour_service.dart';

//TODO: optimize
class TourProvider with ChangeNotifier {
  List<String> _popularTours = List.empty();
  List<String> _localTours = List.empty();
  List<String> _globalTours = List.empty();
  List<String> _userCreatedTours = List.empty();
  List<String> _userSavedTours = List.empty();

  /// Not in any particular order, as it is assembled from the individual fetches which each have their own sorting
  Map<String, Tour> _allCachedTours = {};
  Tour? _selectedTour;
  bool _isLoadingTours = false;

  List<String> get popularTours => _popularTours;
  List<String> get localTours => _localTours;
  List<String> get globalTours => _globalTours;
  List<String> get userCreatedTours => _userCreatedTours;
  List<String> get userSavedTours => _userSavedTours;
  Tour? get selectedTour => _selectedTour;
  bool get isLoadingTours => _isLoadingTours;

  TourProvider() {
    _init();
  }

  // Initialization method
  Future<void> _init() async {
    logger.t("TourProvider._init()");
  }

  List<Tour> getToursByIds(List<String> tourIds) {
    return tourIds.map((id) => _allCachedTours[id]!).toList();
  }

  List<String> getAllCachedRealTourIds() {
    return _allCachedTours.keys
        .where((id) => id.isNotEmpty && id != Tour.addTourTileId)
        .toList();
  }

  Future<void> fetchAndSetTours(double userLatitude, double userLongitude,
      String userId, List<String> userSavedTours) async {
    try {
      logger.t("fetchAndSetTours ${getFormattedTime()}");
      _isLoadingTours = true;
      notifyListeners();

      // Step 1: Get tours from Hive
      if (!kIsWeb) {
        _popularTours = _processToursAndUpdateCachedTours(
            await TourService.getToursFromHive(TourService.popularToursBoxName),
            userId);
        _localTours = _processToursAndUpdateCachedTours(
            await TourService.getToursFromHive(TourService.localToursBoxName),
            userId);
        _globalTours = _processToursAndUpdateCachedTours(
            await TourService.getToursFromHive(TourService.globalToursBoxName),
            userId);
        _userCreatedTours = _processToursAndUpdateCachedTours(
            await TourService.getToursFromHive(
                TourService.userCreatedToursBoxName),
            userId);
        _userSavedTours = _processToursAndUpdateCachedTours(
            await TourService.getToursFromHive(
                TourService.userSavedToursBoxName),
            userId);
        logger.t(
            "fetchAndSetTours - finished getting tours from Hive ${getFormattedTime()}");
        notifyListeners();
      }

      // Step 2: Fetch updated tours from Firestore
      _popularTours = _processToursAndUpdateCachedTours(
          await TourService.fetchPopularToursNearYou(
              userLatitude, userLongitude),
          userId,
          replaceCached: true);
      _localTours = _processToursAndUpdateCachedTours(
          await TourService.fetchLocalTours(userLatitude, userLongitude),
          userId,
          replaceCached: true);
      _globalTours = _processToursAndUpdateCachedTours(
          await TourService.fetchPopularToursAroundTheWorld(), userId,
          replaceCached: true);
      _userCreatedTours = _processToursAndUpdateCachedTours(
          await TourService.fetchUserCreatedTours(userId), userId,
          replaceCached: true);
      _userSavedTours = _processToursAndUpdateCachedTours(
          await TourService.fetchUserSavedTours(userSavedTours), userId,
          replaceCached: true);
      notifyListeners();

      // Step 3: Update Hive with new data  //TODO: optimize
      if (!kIsWeb) {
        await TourService.overwriteToursInHive(
            TourService.popularToursBoxName, getToursByIds(_popularTours));
        await TourService.overwriteToursInHive(
            TourService.localToursBoxName, getToursByIds(_localTours));
        await TourService.overwriteToursInHive(
            TourService.globalToursBoxName, getToursByIds(_globalTours));
        await TourService.overwriteToursInHive(
            TourService.userCreatedToursBoxName, getToursByIds(_userCreatedTours));
        await TourService.overwriteToursInHive(
            TourService.userSavedToursBoxName, getToursByIds(_userSavedTours));
      }
      await _formatListsAndGetTourRatings(userId);

      // Step 4: Download images in parallel
      logger.t(
          "fetchAndSetTours - starting image downloads ${getFormattedTime()}");
      await Future.wait(
          _allCachedTours.values.map((tour) => _setTourImage(tour)));
      logger.t(
          "fetchAndSetTours - image downloads complete ${getFormattedTime()}");
      _isLoadingTours = false;
      notifyListeners();
    } catch (error, stack) {
      logger.e('Error fetching tours: $error, $stack');
    }
  }

  /// Downloads the tour image, stores the local file, and sets it on the tour object. On web, Network.Image is used instead of the file.
  //TODO: fix that this won't update if image changes
  Future<void> _setTourImage(Tour tour) async {
    logger.t('Setting image for tour: ${tour.id}');
    final File? localImage = await TourService.getLocalImageFile(tour.id);
    if (localImage != null && !tour.requestMediaRedownload) {
      tour.imageFile = localImage;
    } else {
      if (tour.requestMediaRedownload)
        logger.t('Requesting image redownload: ${tour.id}');
      if (!kIsWeb) {
        await TourService.downloadAndSaveImage(tour.imageUrl, tour.id);
        final File? downloadedImage =
            await TourService.getLocalImageFile(tour.id);
        if (downloadedImage != null) {
          tour.imageFile = downloadedImage;
        }
      }
    }
  }

  List<String> _processToursAndUpdateCachedTours(
      List<Tour> tours, String userId,
      {bool replaceCached = false}) {
    try {
      List<String> updatedTours = [];
      for (Tour tour in tours) {
        //logger.t('Processing tour: ${tour.id}');
        if (tour.reports.length > 0 && tour.authorId != userId) {
          logger.w('Tour has reports, removing: ${tour.id}');
          continue; // Skip tours with reports
        }
        if (tour.id.isEmpty || tour.id == Tour.addTourTileId) {
          logger.w('Tour has invalid id:\"${tour.id}\", skipping');
          continue;
        }
        if (_allCachedTours.containsKey(tour.id) && !replaceCached) {
          // Use the existing tour instance from the cache, unless media redownload requested
          bool requestMediaRedownload = tour.lastChangedDateTime == null ||
              _allCachedTours[tour.id]!.lastChangedDateTime == null ||
              tour.lastChangedDateTime!
                  .isAfter(_allCachedTours[tour.id]!.lastChangedDateTime!);
          if (requestMediaRedownload) {
            logger.t(
                '${tour.id} needs media redownload, last changed: ${tour.lastChangedDateTime} vs cached ${_allCachedTours[tour.id]!.lastChangedDateTime}');
            tour.requestMediaRedownload = true;
            _allCachedTours[tour.id] = tour;
          } else {
            // Use the existing tour instance from the cache
            updatedTours.add(tour.id);
          }
        } else {
          // Add the new tour to the cache and the updated list
          _allCachedTours[tour.id] = tour;
          updatedTours.add(tour.id);
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
    Tour addTourTile = Tour.isAddTourTile();
    _allCachedTours[addTourTile.id] = addTourTile;
    if (_popularTours.isEmpty) _popularTours.add(addTourTile.id);
    if (_localTours.isEmpty) _localTours.add(addTourTile.id);
    if (_globalTours.isEmpty) _globalTours.add(addTourTile.id);
    if (_userCreatedTours.isEmpty) {
      _userCreatedTours.add(addTourTile.id);
    } else if (!_userCreatedTours.contains(Tour.addTourTileId)) {
      _userCreatedTours.insert(0, addTourTile.id);
    }
    notifyListeners();

    await TourService.getUserRatingsForTours(_allCachedTours, getAllCachedRealTourIds(), userId);
    _isLoadingTours = false;
    notifyListeners();
  }

  Future<void> deleteTour(Tour tour) async {
    bool deleteSuccess = await TourService.deleteTour(tour);
    if (!deleteSuccess) return;
    removeTourFromCachedTours(tour);
    notifyListeners();
  }

  void removeTourFromCachedTours(Tour tour) async {
    _allCachedTours.remove(tour.id);
    _popularTours.remove(tour.id);
    _globalTours.remove(tour.id);
    _localTours.remove(tour.id);
    _userCreatedTours.remove(tour.id);
    notifyListeners();
  }

  void clearSelectedTour() {
    _selectedTour = null;
    notifyListeners();
  }

  void userSavedTour(String tourId, bool tourIsSaved) {
    tourIsSaved ? _userSavedTours.add(tourId) : _userSavedTours.remove(tourId);
    notifyListeners();
  }

  //TODO: get rid? What could I use this for? Select a tour that user has started? was used for details but no longer used for that
  void selectTourById(String id) {
    try {
      _selectedTour = _allCachedTours[id];
      //logger.i(_selectedTour.toString());
      notifyListeners();
    } catch (e) {
      logger.e('Tour not found: $e');
    }
  }

  bool isUserCreatedTour(Tour tour) {
    if (tour.id.isEmpty) return false;
    return userCreatedTours.contains(tour.id);
  }

  Future<void> uploadTour(Tour tour) async {
    Tour newTour = await TourService.uploadTour(tour);
    _allCachedTours[tour.id] = newTour;
    _userCreatedTours.insert(1, tour.id);
    notifyListeners();
  }

  /// Updates the tour data in cache and firestore (for edits, reporting, etc)
  Future<Tour> updateTour(Tour tour, {bool localUpdateOnly = false}) async {
    if (!localUpdateOnly) tour = await TourService.updateTour(tour);
    _allCachedTours[tour.id] = tour;
    notifyListeners();
    return _allCachedTours[tour.id]!;
  }

  /// for logout
  void resetTourProvider() {
    _selectedTour = null;
    _isLoadingTours = false;
    _allCachedTours = {};
    _popularTours = List.empty();
    _localTours = List.empty();
    _globalTours = List.empty();
    _userCreatedTours = List.empty();
    _userSavedTours = List.empty();
    logger.t("TourProvider.resetTourProvider()");
  }


  //TODO: swap for approach where we use already cached list to avoid the first get call?
  Future<void> updateAuthorNameForAllTheirTours(
      String authorId, String newAuthorName) async {
    await TourService.updateAuthorNameForAllTheirTours(authorId, newAuthorName);
    notifyListeners();
  }

  // ____________________________ Reports ____________________________
  Future<void> reportTour(Tour tour, TourguideReport report,
      TourguideUser reportedTourAuthor) async {
    List<TourguideReport> newReports = [...tour.reports, report];
    Tour reportedTour =
        tour.copyWith(reports: newReports, lastChangedDateTime: DateTime.now());

    logger.i('Tour reported: ${tour.id}');
    _notifyAdminOfReportOrReviewRequest(tour.id,
        reportTitle: report.title, reportDetails: report.additionalDetails);
    _notifyUserOfReport(tour, report, reportedTourAuthor);

    await updateTour(reportedTour);
    removeTourFromCachedTours(reportedTour);
  }

  Future<Tour> requestReviewOfTour(Tour tour) async {
    Tour tourToReview = tour.copyWith(
        requestReviewStatus: "requested", lastChangedDateTime: DateTime.now());

    logger.i('Tour Review requested: ${tour.id}');
    _notifyAdminOfReportOrReviewRequest(tour.id);

    return await updateTour(tourToReview);
  }

  //optional params String reportTitle, String reportDetails
  Future<void> _notifyAdminOfReportOrReviewRequest(String tourId,
      {String? reportTitle, String? reportDetails}) async {
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

  Future<void> _notifyUserOfReport(Tour tour, TourguideReport report,
      TourguideUser reportedTourAuthor) async {
    if (reportedTourAuthor.emailSubscriptionsDisabled.contains('reports')) {
      logger.t(
          "UserProvider._notifyUserOfReport() - User is not subscribed to Report emails, skipping");
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
