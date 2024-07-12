class TourguideUser {
  String firebaseAuthId;
  String? googleSignInId;
  String username;
  List<String> savedTourIds;

  TourguideUser({
    required this.firebaseAuthId,
    this.googleSignInId,
    required this.username,
    required this.savedTourIds,
  });

  // Convert a User object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'firebaseAuthId': firebaseAuthId,
      'googleSignInId': googleSignInId,
      'username': username,
      'savedTourIds': savedTourIds,
    };
  }

  // Create a User object from a map
  factory TourguideUser.fromMap(Map<String, dynamic> map) {
    return TourguideUser(
      firebaseAuthId: map['firebaseAuthId'],
      googleSignInId: map['googleSignInId'],
      username: map['username'],
      savedTourIds: List<String>.from(map['savedTourIds']),
    );
  }

  TourguideUser copyWith({
    String? firebaseAuthId,
    String? googleSignInId,
    String? username,
    List<String>? savedTourIds,
  }) {
    return TourguideUser(
      firebaseAuthId: firebaseAuthId ?? this.firebaseAuthId,
      googleSignInId: googleSignInId ?? this.googleSignInId,
      username: username ?? this.username,
      savedTourIds: savedTourIds ?? this.savedTourIds,
    );
  }
}
