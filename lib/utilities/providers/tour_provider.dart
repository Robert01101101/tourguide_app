import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  Tour? get selectedTour => _selectedTour;
  bool get isLoadingTours => _isLoadingTours;

  TourProvider() {
    _init();
  }

  // Initialization method
  Future<void> _init() async {
    logger.t("TourProvider._init()");
  }



  Future<void> fetchAndSetTours(double userLatitude, double userLongitude, String userId) async {
    try {
      logger.t("fetchAndSetTours ${getFormattedTime()}");
      _isLoadingTours = true;
      //_allTours = await TourService.fetchAndSortToursByDateTime();
      _popularTours = _processToursAndUpdateCachedTours(await TourService.fetchPopularToursNearYou(userLatitude, userLongitude), userId);
      notifyListeners();
      _localTours = _processToursAndUpdateCachedTours(await TourService.fetchLocalTours(userLatitude, userLongitude), userId);
      notifyListeners();
      _globalTours = _processToursAndUpdateCachedTours(await TourService.fetchPopularToursAroundTheWorld(), userId);
      notifyListeners();
      _userCreatedTours = _processToursAndUpdateCachedTours(await TourService.fetchUserCreatedTours(userId), userId);
      notifyListeners();
      _userSavedTours = _processToursAndUpdateCachedTours(await TourService.fetchUserSavedTours(userId), userId);
      notifyListeners();

      _formatListsAndGetTourRatings(userId);
    } catch (error) {
      logger.e('Error fetching tours: $error');
    }
  }

  List<Tour> _processToursAndUpdateCachedTours(List<Tour> tours, String userId) {
    List<Tour> updatedTours = [];
    for (Tour tour in tours) {
      logger.t('Processing tour: ${tour.id}');
      if (tour.reports.length > 0 && tour.authorId != userId) {
        logger.w('Tour has reports, removing: ${tour.id}');
        continue; // Skip tours with reports
      }
      if (_allCachedTours.containsKey(tour.id)) {
        // Use the existing tour instance from the cache
        updatedTours.add(_allCachedTours[tour.id]!);
      } else {
        // Add the new tour to the cache and the updated list
        _allCachedTours[tour.id] = tour;
        updatedTours.add(tour);
      }
    }
    return updatedTours;
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

  Future<void> reportTour(Tour tour, TourguideReport report, TourguideUser reportedTourAuthor) async{
    List<TourguideReport> newReports =  [...tour.reports, report];
    Tour reportedTour = tour.copyWith(reports: newReports);

    logger.i('Tour reported: ${tour.id}');
    _notifyAdminOfReportOrReviewRequest(tour.id, reportTitle: report.title, reportDetails: report.additionalDetails);
    _notifyUserOfReport(tour, report, reportedTourAuthor);

    await updateTour(reportedTour);
    removeTourFromCachedTours(reportedTour);
  }

  Future<Tour> requestReviewOfTour(Tour tour) async{
    Tour tourToReview = tour.copyWith(requestReviewStatus: "requested");

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
          'tourId': tourId,
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
    };

    await FirebaseFirestore.instance.collection('emails').add(emailData);
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
}
