import 'package:flutter/material.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tour.dart';

//TODO: optimize
class TourProvider with ChangeNotifier {
  List<Tour> _popularTours = List.generate(4, (index) => Tour.empty());
  List<Tour> _localTours = List.generate(4, (index) => Tour.empty());
  List<Tour> _globalTours = List.generate(4, (index) => Tour.empty());
  List<Tour> _userCreatedTours = List.generate(1, (index) => Tour.isAddTourTile());
  List<Tour> _userSavedTours = List.empty();
  List<Tour> _allTours = List.generate(4, (index) => Tour.empty());
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
      _allTours = await TourService.fetchAndSortToursByDateTime();
      _popularTours = TourService.popularToursNearYou(_allTours, userLatitude, userLongitude);
      _localTours = TourService.localTours(_allTours, userLatitude, userLongitude);
      _globalTours = TourService.popularToursAroundTheWorld(_allTours);
      _userCreatedTours = TourService.userCreatedTours(_allTours, userId);
      _userSavedTours = TourService.userSavedTours(_allTours, userId);

      notifyListeners();
      _getTourRatings(userId);
    } catch (error) {
      logger.e('Error fetching tours: $error');
    }
  }

  // TODO: make more efficient, only call once per tour
  Future<void> _getTourRatings(String userId) async {
    logger.t('getTourRatings ${getFormattedTime()}');
    bool getPopularTourRatings = _popularTours.isNotEmpty;
    bool getLocalTourRatings = _localTours.isNotEmpty;
    bool getGlobalTourRatings = _globalTours.isNotEmpty;
    bool getUserCreatedTourRatings = _userCreatedTours.isNotEmpty;
    //add empty tour if no tours
    if (!getPopularTourRatings) _popularTours = List.generate(1, (index) => Tour.isAddTourTile());
    if (!getLocalTourRatings) _localTours = List.generate(1, (index) => Tour.isAddTourTile());
    if (!getGlobalTourRatings) _globalTours = List.generate(1, (index) => Tour.isAddTourTile());
    if (!getUserCreatedTourRatings) {
      _userCreatedTours = List.generate(1, (index) => Tour.isAddTourTile());
    } else {
      _userCreatedTours.insert(0,Tour.isAddTourTile());
    }
    notifyListeners();

    if (getPopularTourRatings) _popularTours = await TourService.checkUserRatings(popularTours, userId);
    if (getLocalTourRatings) _localTours = await TourService.checkUserRatings(localTours, userId);
    if (getGlobalTourRatings) _globalTours = await TourService.checkUserRatings(globalTours, userId);
    if (getUserCreatedTourRatings) _userCreatedTours = await TourService.checkUserRatings(globalTours, userId);
    _isLoadingTours = false;
    notifyListeners();
  }

  void selectTour(Tour tour) {
    _selectedTour = tour;
    notifyListeners();
  }

  void clearSelectedTour() {
    _selectedTour = null;
    notifyListeners();
  }

  void selectTourById(String id) {
    try {
      _selectedTour = _allTours.firstWhere((tour) => tour.id == id);
      logger.i(_selectedTour.toString());
      notifyListeners();
    } catch (e) {
      logger.e('Tour not found: $e');
    }
  }

  void addTourToAllTours(Tour tour) {
    _allTours.add(tour);
    notifyListeners();
  }

  void removeTourFromAllTours(Tour tour) {
    _allTours.remove(tour);
    notifyListeners();
  }
}
