import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
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
      await loadUser();
      if (_user == null) {
        // New user, create an entry in Firestore
        await _createUser();
      }
    } else {
      _user = null;
      notifyListeners();
    }
  }

  Future<void> _createUser () async {
    logger.i("UserProvider._createUser()");
    final auth.User? firebaseUser = _firebaseAuth.currentUser;
    _user = TourguideUser(
      firebaseAuthId: firebaseUser!.uid,
      googleSignInId: _authProvider!.googleSignInUser!.id,
      username: firebaseUser.displayName ?? 'Anonymous',
      displayName: _authProvider!.googleSignInUser!.displayName!,
      savedTourIds: [],
    );
    notifyListeners();
    await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set(_user!.toMap());
  }

  Future<void> loadUser() async {
    logger.t("UserProvider.loadUser()");
    final auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists) {
        _user = TourguideUser.fromMap(doc.data() as Map<String, dynamic>);
        notifyListeners();
      }
    }
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

  void clearUser() {
    logger.t("UserProvider.clearUser()");
    _user = null;
    notifyListeners();
  }
}
