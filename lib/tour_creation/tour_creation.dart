import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

import 'package:tourguide_app/main.dart';

//_________________________________________________________________________ CREATE FORM
class CreateTour extends StatefulWidget {
  const CreateTour({super.key});

  @override
  State<CreateTour> createState() => _CreateTourState();
}

class _CreateTourState extends State<CreateTour> {
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
                GooglePlacesAutoCompleteTextFormField(  //TODO: Add location bias, restrict to cities only
                    decoration: const InputDecoration(
                      labelText: 'City',
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a city';
                      }
                      return null;
                    },
                    enabled: !_isFormSubmitted,
                    textEditingController: _cityController,
                    googleAPIKey: MyGlobals.googleApiKey,
                    //proxyURL: "https://your-proxy.com/", // only needed if you build for the web
                    debounceTime: 400, // defaults to 600 ms
                    //countries: ["de"], // optional, by default the list is empty (no restrictions)
                    //isLatLngRequired: true, // if you require the coordinates from the place details
                    /*getPlaceDetailWithLatLng: (prediction) {
                      // this method will return latlng with place detail
                      print("Coordinates: (${prediction.lat},${prediction.lng})");
                    },*/ // this callback is called when isLatLngRequired is true
                    itmClick: (prediction) {
                      _cityController.text = prediction.description!;
                      _cityController.selection = TextSelection.fromPosition(TextPosition(offset: prediction.description!.length));
                    }
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                  maxLength: _descriptionMaxChars,
                  decoration: InputDecoration(
                    labelText: 'Description',
                  ),
                  validator: (String? value) {
                    if (value != null && value.length > _descriptionMaxChars-1) {
                      return 'Please enter a maximum of 100 characters';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {}); // Trigger a rebuild to update the character counter
                  },
                  enabled: !_isFormSubmitted,
                ),
                SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Make Public'), // Text label for the switch
                  value: _tourIsPublic, // The boolean value
                  onChanged: !_isFormSubmitted
                      ? (newValue) {
                    setState(() {
                      _tourIsPublic = newValue; // Update the boolean value
                    });
                  }
                      : null, // Disable switch if form is submitted
                  secondary: const Icon(Icons.public),
                  inactiveThumbColor: _isFormSubmitted ? Colors.grey : null,
                  inactiveTrackColor: _isFormSubmitted ? Colors.grey[300] : null,
                ),
                SizedBox(height: 32),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton(onPressed: () {
                    // Validate will return true if the form is valid, or false if
                    // the form is invalid.
                    if (_formKey.currentState!.validate()) {
                      // If the form is valid, display a snackbar. In the real world,
                      // you'd often call a server or save the information in a database.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Uploading')),
                      );
                      setState(() {
                        _isFormSubmitted = true;
                      });
                      _firestoreCreateTour();
                    }
                  }, child: const Text("Save and create tour")),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}