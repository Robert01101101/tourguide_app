import 'package:flutter/material.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/model/tour.dart';

class TourProvider with ChangeNotifier {
  List<Tour> _tours = [];
  Tour? _selectedTour;

  List<Tour> get tours => _tours;
  Tour? get selectedTour => _selectedTour;

  Future<void> fetchAndSetTours() async {
    try {
      _tours = await TourService.fetchAndSortToursByDateTime();
      notifyListeners();
    } catch (error) {
      logger.e('Error fetching tours: $error');
    }
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
      _selectedTour = _tours.firstWhere((tour) => tour.id == id);
      logger.i(_selectedTour.toString());
      notifyListeners();
    } catch (e) {
      logger.e('Tour not found: $e');
    }
  }
}
