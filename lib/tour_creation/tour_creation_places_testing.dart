import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/ui/city_autocomplete_old.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

import 'package:tourguide_app/main.dart';

//_________________________________________________________________________ CREATE FORM
class CreateTourTesting extends StatefulWidget {
  const CreateTourTesting({super.key});

  @override
  State<CreateTourTesting> createState() => _CreateTourTestingState();
}

class _CreateTourTestingState extends State<CreateTourTesting> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  bool _tourIsPublic = false; // Initial boolean value
  bool _isFormSubmitted = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final int _descriptionMaxChars = 100;



  _firestoreCreateTour() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    FirebaseAuth auth = FirebaseAuth.instance;

    //get userid
    final User user = auth.currentUser!; //assuming we're logged in here
    final uid = user.uid;

    final tour = <String, dynamic>{
      "name": _nameController.text,
      "description": _descriptionController.text,
      "city": _cityController.text,
      "uid": uid,
      "visibility": _tourIsPublic ? "public" : "private",
    };

    // Add a new document with a generated ID
    db.collection("tours").add(tour).then((DocumentReference doc){
      print('DocumentSnapshot added with ID: ${doc.id}');
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully created tour!')),
      );

      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a new tour'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 32.0, // Vertical padding
            horizontal: 16.0, // Horizontal padding
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name for your tour';
                    }
                    return null;
                  },
                  enabled: !_isFormSubmitted,
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a city for your tour';
                    }
                    return null;
                  },
                  enabled: !_isFormSubmitted,
                ),
                CityAutocompleteOld()
              ],
            ),
          ),
        ),
      ),
    );
  }
}