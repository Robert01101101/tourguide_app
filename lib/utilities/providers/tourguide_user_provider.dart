import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/model/tourguide_report.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as my_auth;

import '../../main.dart';
import '../../model/tourguide_user.dart';

class TourguideUserProvider with ChangeNotifier {
  TourguideUser? _user;
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;

  TourguideUser? get user => _user;
  my_auth.AuthProvider? _authProvider; // Hold a reference to AuthProvider


  TourguideUserProvider() {
    logger.t("UserProvider()");
    _firebaseAuth.authStateChanges().listen((firebaseUser) => _onAuthStateChanged(firebaseUser));
  }


  void setAuthProvider(my_auth.AuthProvider authProvider) {
    _authProvider = authProvider;
    // Perform any initialization or logic based on AuthProvider here
    // For example:
    // _authProvider.signIn();
    notifyListeners();
  }

  Future<void> _onAuthStateChanged(auth.User? firebaseUser) async {
    if (firebaseUser != null) {
      await _waitForRequiredData();
      await _loadUser();
      logger.t("UserProvider() - _onAuthStateChanged() - User is loaded");
      _sendWelcomeEmail();
      if (_user == null) {
        // New user, create an entry in Firestore
        await _createUser();

      }
    } else {
      logger.t("UserProvider() - _onAuthStateChanged() - User is null");
      _user = null;
      notifyListeners();
    }
  }

  Future<void> _waitForRequiredData() async {
    const maxWaitTime = Duration(seconds: 20);
    const checkInterval = Duration(milliseconds: 100);
    final startTime = DateTime.now();

    // Loop to check for availability of firebaseUser and googleSignInUser
    auth.User? firebaseUser;
    while (DateTime.now().difference(startTime) < maxWaitTime) {
      firebaseUser = auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && _authProvider != null && _authProvider!.googleSignInUser != null) break;
      await Future.delayed(checkInterval);
    }

    if (firebaseUser == null || _authProvider == null || _authProvider!.googleSignInUser == null) {
      logger.e('Tourguide User Provider() might run into issues because firebaseUser or googleSignInUser is null');
    }
  }

  Future<void> _createUser () async {
    logger.i("UserProvider._createUser()");
    final auth.User? firebaseUser = _firebaseAuth.currentUser;
    _user = TourguideUser(
      firebaseAuthId: firebaseUser!.uid,
      googleSignInId: _authProvider!.googleSignInUser!.id,
      username: '',
      displayName: _authProvider!.googleSignInUser!.displayName!,
      email: _authProvider!.googleSignInUser!.email!,
      emailSubscribed: true,
      savedTourIds: [],
      reports: [],
    );
    notifyListeners();
    await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set(_user!.toMap());
  }

  Future<void> _sendWelcomeEmail () async {
    logger.i("UserProvider._sendWelcomeEmail()");
    if (_user!.emailSubscribed == false) {
      logger.t("UserProvider._sendWelcomeEmail() - User is not subscribed to emails, skipping");
      return;
    }
    Map<String, dynamic> emailData = {
      'to': _authProvider!.googleSignInUser!.email,
      'template': {
        'name': 'welcome',
        'data': {
          'firstName': _authProvider!.googleSignInUser!.displayName!.split(' ').first,
          'authId': _user!.firebaseAuthId,
        }
      },
    };

    await FirebaseFirestore.instance.collection('emails').add(emailData);
  }

  Future<void> _loadUser() async {
    logger.t("UserProvider.loadUser()");
    final auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['googleSignInId'] == null
            || data['username'] == null
            || data['displayName'] == null
            || data['email'] == null
            || data['emailSubscribed'] == null
            || data['reports'] == null) {
          logger.w("UserProvider.loadUser() - User data is incomplete, patching user");
          _user = await _patchUser(data);
        } else {
          _user = TourguideUser.fromMap(doc.data() as Map<String, dynamic>);
        }
        notifyListeners();
      }
    }
  }

  Future<TourguideUser?> getUserInfo(String userId) async {
    TourguideUser? user;
    logger.t("UserProvider._getUserInfo($userId)");
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists) {
      user = TourguideUser.fromMap(doc.data() as Map<String, dynamic>);
    }
    return user;
  }

  Future<TourguideUser> _patchUser(Map<String, dynamic> data)async {
  logger.t("UserProvider._patchUser()");
    final auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
    TourguideUser patchedUser = TourguideUser(
      firebaseAuthId: firebaseUser!.uid,
      googleSignInId: data['googleSignInId'] ?? _authProvider!.googleSignInUser!.id,
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? _authProvider!.googleSignInUser!.displayName!,
      email: data['email'] ?? _authProvider!.googleSignInUser!.email!,
      emailSubscribed: data['emailSubscribed'] ?? true,
      savedTourIds: List<String>.from(data['savedTourIds'] ?? []),
      reports: List<TourguideReport>.from(data['reports'] ?? []),
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

      logger.t("UserProvider.checkUsernameAvailability() - username available: ${querySnapshot.docs.isEmpty}");
      return querySnapshot.docs.isEmpty; // true if username is available, false if taken
    } catch (e) {
      logger.e('Error checking username availability: $e');
      return false; // Assume username is not available on error
    }
  }

  Future<void> updateUser(TourguideUser updatedUser) async {
    logger.t("UserProvider.updateUser()");
    _user = updatedUser;
    notifyListeners();
    await FirebaseFirestore.instance.collection('users').doc(_user!.firebaseAuthId).set(_user!.toMap());
  }
}
