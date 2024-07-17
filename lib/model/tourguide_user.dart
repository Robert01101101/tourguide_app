class TourguideUser {
  String firebaseAuthId;
  String? googleSignInId;
  String username;
  String? displayName;
  List<String> savedTourIds;

  TourguideUser({
    required this.firebaseAuthId,
    this.googleSignInId,
    required this.username,
    this.displayName,
    required this.savedTourIds,
  });

  // Convert a User object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'firebaseAuthId': firebaseAuthId,
      'googleSignInId': googleSignInId,
      'username': username,
      'displayName': displayName,
      'savedTourIds': savedTourIds,
    };
  }

  // Create a User object from a map
  factory TourguideUser.fromMap(Map<String, dynamic> map) {
    return TourguideUser(
      firebaseAuthId: map['firebaseAuthId'],
      googleSignInId: map['googleSignInId'],
      username: map['username'],
      displayName: map['displayName'],
      savedTourIds: List<String>.from(map['savedTourIds']),
    );
  }

  TourguideUser copyWith({
    String? firebaseAuthId,
    String? googleSignInId,
    String? username,
    String? displayName,
    List<String>? savedTourIds,
  }) {
    return TourguideUser(
      firebaseAuthId: firebaseAuthId ?? this.firebaseAuthId,
      googleSignInId: googleSignInId ?? this.googleSignInId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      savedTourIds: savedTourIds ?? this.savedTourIds,
    );
  }
}
