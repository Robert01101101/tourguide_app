import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tourguide_app/ui/add_image_tile.dart';
import 'package:tourguide_app/ui/city_autocomplete.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
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

  File? _image;

  Future<void> _pickImage(ImageSource source) async {
    // Check and request permissions if needed
    if (source == ImageSource.camera) {
      if (await Permission.camera.request().isDenied) {
        return; // Permission denied, do not proceed
      }
    } else if (source == ImageSource.gallery) {
      if (await Permission.photos.request().isDenied) {
        return; // Permission denied, do not proceed
      }
    }

    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }



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
        child: Form(
          key: _formKey,
          child: StandardLayout(
            children: [
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
              CityAutocomplete(textEditingController: _cityController,
                isFormSubmitted: _isFormSubmitted,
                onItemSelected: (AutocompletePrediction prediction) {
                  print("Selected city: ${prediction.primaryText}");
                },),
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
              Center(
                child: AddImageTile(
                  imageFile: _image,
                  pickImageFromCamera: () => _pickImage(ImageSource.camera),
                  pickImageFromGallery: () => _pickImage(ImageSource.gallery),
                ),
              ),
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
    );
  }
}