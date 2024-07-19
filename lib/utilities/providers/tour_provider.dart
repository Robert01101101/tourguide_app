import 'package:flutter/material.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/utilities/singletons/tour_service.dart';

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
      _popularTours = _updateCachedTours(await TourService.fetchPopularToursNearYou(userLatitude, userLongitude));
      notifyListeners();
      _localTours = _updateCachedTours(await TourService.fetchLocalTours(userLatitude, userLongitude));
      notifyListeners();
      _globalTours = _updateCachedTours(await TourService.fetchPopularToursAroundTheWorld());
      notifyListeners();
      _userCreatedTours = _updateCachedTours(await TourService.fetchUserCreatedTours(userId));
      notifyListeners();
      _userSavedTours = _updateCachedTours(await TourService.fetchUserSavedTours(userId));
      notifyListeners();

      _getTourRatings(userId);
    } catch (error) {
      logger.e('Error fetching tours: $error');
    }
  }

  List<Tour> _updateCachedTours(List<Tour> tours) {
    List<Tour> updatedTours = [];
    for (Tour tour in tours) {
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

  Future<void> _getTourRatings(String userId) async {
    logger.t('getTourRatings ${getFormattedTime()}');
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

    await TourService.getUserRatingsForTours(_allCachedTours, userId);
    _isLoadingTours = false;
    notifyListeners();
  }

  Future<void> deleteTour(Tour tour) async{
    await TourService.deleteTour(tour);
    _allCachedTours.remove(tour);
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
    return userCreatedTours.contains(tour);
  }

  Future<void> uploadTour(Tour tour) async{
    await TourService.uploadTour(tour);
    _allCachedTours[tour.id] = tour;
    _userCreatedTours.insert(1, tour);
    notifyListeners();
  }
}
