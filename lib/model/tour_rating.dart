/// Stored as a document in the Ratings subcollection of each tour
class Rating {
  final String userId;
  final int value; // 1 for thumb up, -1 for thumb down

  Rating({
    required this.userId,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'value': value,
    };
  }

  factory Rating.fromMap(Map<String, dynamic> data) {
    return Rating(
      userId: data['userId'],
      value: data['value'],
    );
  }
}
