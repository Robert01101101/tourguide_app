class TourguidePlace {
  final double latitude;
  final double longitude;
  final String googleMapPlaceId;
  final String title;
  final String description;
  final List<String> photoUrls;

  TourguidePlace({
    required this.latitude,
    required this.longitude,
    required this.googleMapPlaceId,
    required this.title,
    required this.description,
    required this.photoUrls,
  });

  @override
  String toString() {
    return 'TourguidePlace{latitude: $latitude, longitude: $longitude, googleMapPlaceId: $googleMapPlaceId, title: $title, description: $description, photoUrls: $photoUrls}';
  }
}
