import 'package:flutter/material.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tour.dart';

//TODO: optimize
class TourProvider with ChangeNotifier {
  List<Tour> _popularTours = List.generate(4, (index) => Tour.empty());
  List<Tour> _localTours = List.generate(4, (index) => Tour.empty());
  List<Tour> _globalTours = List.generate(4, (index) => Tour.empty());
  List<Tour> _userCreatedTours = List.generate(1, (index) => Tour.isAddTourTile());
  List<Tour> _allTours = List.generate(4, (index) => Tour.empty());
  Tour? _selectedTour;

  List<Tour> get popularTours => _popularTours;
  List<Tour> get localTours => _localTours;
  List<Tour> get globalTours => _globalTours;
  List<Tour> get userCreatedTours => _userCreatedTours;
  Tour? get selectedTour => _selectedTour;

  TourProvider() {
    _init();
  }

  // Initialization method
  Future<void> _init() async {
    logger.t("TourProvider._init()");
  }



  Future<void> fetchAndSetTours(double userLatitude, double userLongitude, String userId) async {
    try {
      logger.t("fetchAndSetTours");
      _allTours = await TourService.fetchAndSortToursByDateTime();
      _popularTours = TourService.popularToursNearYou(_allTours, userLatitude, userLongitude);
      _localTours = TourService.localTours(_allTours, userLatitude, userLongitude);
      _globalTours = TourService.popularToursAroundTheWorld(_allTours);
      _userCreatedTours = TourService.userCreatedTours(_allTours, userId);

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
      _getTourRatings(userId);
    } catch (error) {
      logger.e('Error fetching tours: $error');
    }
  }

  Future<void> _getTourRatings(String userId) async {
    logger.t('getTourRatings');
    _popularTours = await TourService.checkUserRatings(popularTours, userId);
    _localTours = await TourService.checkUserRatings(localTours, userId);
    _globalTours = await TourService.checkUserRatings(globalTours, userId);
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
}
