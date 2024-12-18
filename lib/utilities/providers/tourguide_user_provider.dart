import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/model/tourguide_report.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart'
    as my_auth;
import 'package:purchases_flutter/purchases_flutter.dart'; // Import the Purchases SDK

import '../../main.dart';
import '../../model/tourguide_user.dart';

class TourguideUserProvider with ChangeNotifier {
  TourguideUser? _user;
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;

  TourguideUser? get user => _user;
  my_auth.AuthProvider? _authProvider; // Hold a reference to AuthProvider

  TourguideUserProvider() {
    logger.t("UserProvider()");
    _firebaseAuth
        .authStateChanges()
        .listen((firebaseUser) => _onAuthStateChanged(firebaseUser));
  }

  void setAuthProvider(my_auth.AuthProvider authProvider) {
    _authProvider = authProvider;
    // Perform any initialization or logic based on AuthProvider here
    // For example:
    // _authProvider.signIn();
    notifyListeners();
  }

  Future<void> _onAuthStateChanged(auth.User? firebaseUser) async {
    logger.t("UserProvider() - _onAuthStateChanged()");
    if (firebaseUser != null) {
      await _waitForRequiredData();
      await _loadUser();
      _configurePurchases();

      logger.t(
          "UserProvider() - _onAuthStateChanged() - User is loaded: ${_user.toString()}");
      if (_user == null &&
          _authProvider != null &&
          !_authProvider!.isAnonymous &&
          !_authProvider!.isSilentWebSignInProcessing) {
        // New user, create an entry in Firestore
        await _createUser();
        _sendWelcomeEmail();
      }
    } else {
      logger.t("UserProvider() - _onAuthStateChanged() - User is null");
      _user = null;
      notifyListeners();
    }
  }

  Future<void> _waitForRequiredData() async {
    const maxWaitTime = Duration(seconds: 180);
    const checkInterval = Duration(milliseconds: 200);
    final startTime = DateTime.now();

    // Loop to check for availability of firebaseUser and googleSignInUser
    auth.User? firebaseUser;
    while (DateTime.now().difference(startTime) < maxWaitTime) {
      firebaseUser = auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null &&
              _authProvider != null &&
              _authProvider!.googleSignInUser != null ||
          _authProvider != null && _authProvider!.isAnonymous) break;
      await Future.delayed(checkInterval);
    }

    if ((firebaseUser == null ||
            _authProvider == null ||
            _authProvider!.googleSignInUser == null) &&
        (_authProvider != null && !_authProvider!.isAnonymous)) {
      logger.e(
          'Tourguide User Provider() might run into issues because firebaseUser or googleSignInUser is null');
    }
  }

  Future<void> _createUser() async {
    logger.i("UserProvider._createUser()");
    final auth.User? firebaseUser = _firebaseAuth.currentUser;
    _user = TourguideUser(
      firebaseAuthId: firebaseUser!.uid,
      googleSignInId: _authProvider!.googleSignInUser!.id,
      username: '',
      displayName: _authProvider!.googleSignInUser!.displayName!,
      email: _authProvider!.googleSignInUser!.email!,
      emailSubscriptionsDisabled: [],
      savedTourIds: [],
      reports: [],
      useUsername: false,
      createdDateTime: DateTime.now(),
      lastSignInDateTime: DateTime.now(),
    );
    notifyListeners();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .set(_user!.toMap());
    await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'google');
    _configurePurchases();
  }

  Future<void> _sendWelcomeEmail() async {
    logger.i("UserProvider._sendWelcomeEmail()");
    if (_user!.emailSubscriptionsDisabled.contains('general')) {
      logger.t(
          "UserProvider._sendWelcomeEmail() - User is not subscribed to General emails, skipping");
      return;
    }
    Map<String, dynamic> emailData = {
      'to': _authProvider!.googleSignInUser!.email,
      'template': {
        'name': 'welcome',
        'data': {
          'firstName':
              _authProvider!.googleSignInUser!.displayName!.split(' ').first,
          'authId': _user!.firebaseAuthId,
        }
      },
      'userId': _user!.firebaseAuthId,
    };

    await FirebaseFirestore.instance.collection('emails').add(emailData);
  }

  Future<void> _loadUser() async {
    logger.t("UserProvider.loadUser()");
    final auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['googleSignInId'] == null ||
            data['username'] == null ||
            data['displayName'] == null ||
            data['email'] == null ||
            data['emailSubscriptionsDisabled'] == null ||
            data['reports'] == null ||
            data['savedTourIds'] == null ||
            data['useUsername'] == null ||
            data['createdDateTime'] == null ||
            data['lastSignInDateTime'] == null) {
          logger.w(
              "UserProvider.loadUser() - User data is incomplete, patching user");
          _user = await _patchUser(data);
        } else {
          data['lastSignInDateTime'] = DateTime.now();
          _user = TourguideUser.fromMap(data);
          _patchUser(data);
        }
        _configurePurchases();
        notifyListeners();
      }
    } else {
      logger.w("UserProvider.loadUser() - User is null");
    }
  }

  Future<TourguideUser?> getUserInfo(String userId) async {
    TourguideUser? user;
    logger.t("UserProvider._getUserInfo($userId)");
    DocumentSnapshot doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists) {
      user = TourguideUser.fromMap(doc.data() as Map<String, dynamic>);
    }
    return user;
  }

  Future<TourguideUser> _patchUser(Map<String, dynamic> data) async {
    logger.t("UserProvider._patchUser()");
    final auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
    DateTime? createdDateTime;
    if (data['createdDateTime'] != null) {
      if (data['createdDateTime'] is Timestamp) {
        createdDateTime = (data['createdDateTime'] as Timestamp).toDate();
      } else if (data['createdDateTime'] is DateTime) {
        createdDateTime = data['createdDateTime'] as DateTime;
      }
    } else {
      createdDateTime = null;
    }
    DateTime? lastSignInDateTime;
    if (data['lastSignInDateTime'] != null) {
      if (data['lastSignInDateTime'] is Timestamp) {
        lastSignInDateTime = (data['lastSignInDateTime'] as Timestamp).toDate();
      } else if (data['lastSignInDateTime'] is DateTime) {
        lastSignInDateTime = data['lastSignInDateTime'] as DateTime;
      }
    } else {
      lastSignInDateTime = null;
    }
    TourguideUser patchedUser = TourguideUser(
      firebaseAuthId: firebaseUser!.uid,
      googleSignInId:
          data['googleSignInId'] ?? _authProvider!.googleSignInUser!.id,
      username: data['username'] ?? '',
      displayName:
          data['displayName'] ?? _authProvider!.googleSignInUser!.displayName!,
      email: data['email'] ?? _authProvider!.googleSignInUser!.email!,
      emailSubscriptionsDisabled:
          List<String>.from(data['emailSubscriptionsDisabled'] ?? []),
      savedTourIds: List<String>.from(data['savedTourIds'] ?? []),
      reports: List<TourguideReport>.from(data['reports'] ?? []),
      useUsername: data['useUsername'] ?? false,
      createdDateTime: createdDateTime ?? DateTime.now(),
      lastSignInDateTime: lastSignInDateTime ?? DateTime.now(),
    );
    //update in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .set(patchedUser.toMap(), SetOptions(merge: true));
    return patchedUser;
  }

  Future<bool> checkUsernameAvailability(String newUsername) async {
    logger.t("UserProvider.checkUsernameAvailability()");
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: newUsername)
          .get();

      logger.t(
          "UserProvider.checkUsernameAvailability() - username available: ${querySnapshot.docs.isEmpty}");
      return querySnapshot
          .docs.isEmpty; // true if username is available, false if taken
    } catch (e) {
      logger.e('Error checking username availability: $e');
      return false; // Assume username is not available on error
    }
  }

  Future<void> updateUser(TourguideUser updatedUser) async {
    logger.t("UserProvider.updateUser()");
    _user = updatedUser;
    _configurePurchases();
    notifyListeners();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.firebaseAuthId)
        .set(_user!.toMap());
  }

  void resetUserProvider() {
    _user = null;
  }

  // ____________________________ Reports ____________________________
  Future<void> reportUser(TourguideReport report, String reportedUserId) async {
    try {
      //TODO: improve (very messy atm, not based on my original system design)
      /*DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(reportedUserId).get();
      TourguideUser reportedUser = TourguideUser.fromMap(doc.data() as Map<String, dynamic>);
      List<TourguideReport> newReports =  [...reportedUser.reports, report];
      TourguideUser reportedUserCopy = reportedUser.copyWith(reports: newReports);
      logger.i('User reported: ${reportedUserCopy.firebaseAuthId}');*/ //not possible atm with my permissions setup

      _notifyAdminOfReportOrReviewRequest(reportedUserId,
          reportTitle: report.title, reportDetails: report.additionalDetails);
      //await FirebaseFirestore.instance.collection('users').doc(reportedUserCopy.firebaseAuthId).set(reportedUserCopy.toMap()); //not possible atm with my permissions setup
      Map<String, dynamic> reportData = report.toMap();
      //add key 'reportingUserId' to the reportData (very hacky, not according to data model)
      reportData['reportedUser'] = reportedUserId;
      await FirebaseFirestore.instance
          .collection('user_reports')
          .add(reportData);
    } catch (e, stack) {
      logger.e('Error submitting report: $e\n$stack');
    }
  }

  Future<void> _notifyAdminOfReportOrReviewRequest(String userId,
      {String? reportTitle, String? reportDetails}) async {
    Map<String, dynamic> emailData = {
      'to': 'contact@tourguide.rmichels.com',
      'template': {
        'name': reportTitle != null ? 'report' : 'reportReviewRequest',
        'data': {
          'reportItem': 'User',
          'itemId': userId,
          if (reportTitle != null) 'reportTitle': reportTitle,
          if (reportDetails != null) 'reportDetails': reportDetails,
        }
      },
    };

    await FirebaseFirestore.instance.collection('emails').add(emailData);
  }

  /// RevenueCat - once we get firebaseAuthId, we can configure Purchases ID (same ID)
  Future<void> _configurePurchases() async {
    if (_user == null) {
      return;
    }
    await Purchases.configure(
      PurchasesConfiguration(revenueCatApiKey)
        ..appUserID = _user!.firebaseAuthId, // Use the user's Firebase Auth ID
    );
    //_getCurrentUserClaims();
    logger.i('User is premium: ${await _checkUserPremiumStatus()}');
  }

  /// RevenueCat - test whether custom claims have been set correctly (for debugging only for now, but this could be used for firestore security rules)
  Future<Map<dynamic, dynamic>> _getCurrentUserClaims() async {
    final user = auth.FirebaseAuth.instance.currentUser;

    if (user == null) {
      logger.e('User is null, cannot get current user claims');
      return {};
    }

    final idTokenResult = await user.getIdTokenResult(true);

    logger.i('Current user claims: ${idTokenResult.claims}');

    return idTokenResult.claims!;
  }

  Future<bool> _checkUserPremiumStatus() async {
    Map<dynamic, dynamic> claims = await _getCurrentUserClaims();
    if (claims['revenueCatEntitlements'] == null) {
      return false;
    }
    bool isPremium = claims['revenueCatEntitlements']!.contains('Premium');
    if (_user != null && _user!.premium != isPremium) {
      _user!.premium = isPremium;
      notifyListeners();
    }
    return isPremium;
  }
}
