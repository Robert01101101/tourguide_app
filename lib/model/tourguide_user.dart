class TourguideUser {
  String firebaseAuthId;
  String googleSignInId;
  String username;
  String displayName;
  String email;
  bool emailSubscribed = false;
  List<String> savedTourIds;

  TourguideUser({
    required this.firebaseAuthId,
    required this.googleSignInId,
    required this.username,
    required this.displayName,
    required this.email,
    required this.emailSubscribed,
    required this.savedTourIds,
  });

  // Convert a User object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'firebaseAuthId': firebaseAuthId,
      'googleSignInId': googleSignInId,
      'username': username,
      'displayName': displayName,
      'email': email,
      'emailSubscribed': emailSubscribed,
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
      email: map['email'],
      emailSubscribed: map['emailSubscribed'],
      savedTourIds: List<String>.from(map['savedTourIds']),
    );
  }

  TourguideUser copyWith({
    String? firebaseAuthId,
    String? googleSignInId,
    String? username,
    String? displayName,
    String? email,
    bool? emailSubscribed,
    List<String>? savedTourIds,
  }) {
    return TourguideUser(
      firebaseAuthId: firebaseAuthId ?? this.firebaseAuthId,
      googleSignInId: googleSignInId ?? this.googleSignInId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      emailSubscribed: emailSubscribed ?? this.emailSubscribed,
      savedTourIds: savedTourIds ?? this.savedTourIds,
    );
  }
}
