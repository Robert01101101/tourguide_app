import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourguide_app/model/tourguide_report.dart';

class TourguideUser {
  String firebaseAuthId;
  String googleSignInId;
  String username;
  String displayName;
  String email;
  List<String> emailSubscriptionsDisabled;
  List<String> savedTourIds;
  List<TourguideReport> reports;
  bool useUsername;
  DateTime createdDateTime;
  DateTime lastSignInDateTime;

  /// mutable, NOT stored in Firestore, true if user is premium,
  /// based on RevenueCat entitlements set in Firebase Auth as custom claims
  bool? premium;

  TourguideUser({
    required this.firebaseAuthId,
    required this.googleSignInId,
    required this.username,
    required this.displayName,
    required this.email,
    required this.emailSubscriptionsDisabled,
    required this.savedTourIds,
    required this.reports,
    required this.useUsername,
    required this.createdDateTime,
    required this.lastSignInDateTime,
    this.premium,
  });

  // Convert a User object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'firebaseAuthId': firebaseAuthId,
      'googleSignInId': googleSignInId,
      'username': username,
      'displayName': displayName,
      'email': email,
      'emailSubscriptionsDisabled': emailSubscriptionsDisabled ?? [],
      'savedTourIds': savedTourIds ?? [],
      'reports': reports.map((report) => report.toMap()).toList() ?? [],
      'useUsername': useUsername,
      'createdDateTime': createdDateTime,
      'lastSignInDateTime': lastSignInDateTime,
    };
  }

  // Create a User object from a map
  factory TourguideUser.fromMap(Map<String, dynamic> map) {
    List<TourguideReport> reports = [];
    if (map['reports'] != null) {
      List<dynamic> reportsData = map['reports'];
      reports = reportsData.map((reportData) {
        return TourguideReport.fromMap(reportData as Map<String, dynamic>);
      }).toList();
    }
    DateTime? createdDateTime;
    if (map['createdDateTime'] != null) {
      if (map['createdDateTime'] is Timestamp) {
        createdDateTime = (map['createdDateTime'] as Timestamp).toDate();
      } else if (map['createdDateTime'] is DateTime) {
        createdDateTime = map['createdDateTime'] as DateTime;
      }
    } else {
      createdDateTime = null;
    }
    DateTime? lastSignInDateTime;
    if (map['lastSignInDateTime'] != null) {
      if (map['lastSignInDateTime'] is Timestamp) {
        lastSignInDateTime = (map['lastSignInDateTime'] as Timestamp).toDate();
      } else if (map['lastSignInDateTime'] is DateTime) {
        lastSignInDateTime = map['lastSignInDateTime'] as DateTime;
      }
    } else {
      lastSignInDateTime = null;
    }

    return TourguideUser(
      firebaseAuthId: map['firebaseAuthId'],
      googleSignInId: map['googleSignInId'],
      username: map['username'],
      displayName: map['displayName'],
      email: map['email'],
      emailSubscriptionsDisabled: map['emailSubscriptionsDisabled'] != null
          ? List<String>.from(map['emailSubscriptionsDisabled'])
          : [],
      savedTourIds: List<String>.from(map['savedTourIds']),
      reports: reports,
      useUsername: map['useUsername'],
      createdDateTime: createdDateTime ?? DateTime.now(),
      lastSignInDateTime: lastSignInDateTime ?? DateTime.now(),
    );
  }

  TourguideUser copyWith({
    String? firebaseAuthId,
    String? googleSignInId,
    String? username,
    String? displayName,
    String? email,
    List<String>? emailSubscriptionsDisabled,
    List<String>? savedTourIds,
    List<TourguideReport>? reports,
    bool? useUsername,
    DateTime? createdDateTime,
    DateTime? lastSignInDateTime,
    bool? premium,
  }) {
    return TourguideUser(
      firebaseAuthId: firebaseAuthId ?? this.firebaseAuthId,
      googleSignInId: googleSignInId ?? this.googleSignInId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      emailSubscriptionsDisabled:
          emailSubscriptionsDisabled ?? this.emailSubscriptionsDisabled,
      savedTourIds: savedTourIds ?? this.savedTourIds,
      reports: reports ?? this.reports,
      useUsername: useUsername ?? this.useUsername,
      createdDateTime: createdDateTime ?? this.createdDateTime,
      lastSignInDateTime: lastSignInDateTime ?? this.lastSignInDateTime,
      premium: premium ?? this.premium,
    );
  }

  void setEmailSubscriptionEnabled(String type, bool enabled) {
    if (enabled) {
      if (!emailSubscriptionsDisabled.contains(type)) {
        emailSubscriptionsDisabled.add(type);
      }
    } else {
      emailSubscriptionsDisabled.remove(type);
    }
  }

  @override
  String toString() {
    return 'TourguideUser{firebaseAuthId: $firebaseAuthId, googleSignInId: $googleSignInId, username: $username, displayName: $displayName, email: $email, emailSubscriptionsDisabled: $emailSubscriptionsDisabled, savedTourIds: $savedTourIds, reports: $reports, useUsername: $useUsername, createdDateTime: $createdDateTime, lastSignInDateTime: $lastSignInDateTime, premium: $premium}';
  }
}
