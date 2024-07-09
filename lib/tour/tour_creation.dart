import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tourguide_app/model/tourguide_place.dart';
import 'package:tourguide_app/ui/add_image_tile.dart';
import 'package:tourguide_app/ui/place_autocomplete.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:profanity_filter/profanity_filter.dart';

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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _placeControllers = [];

  bool _tourIsPublic = false; // Initial boolean value
  bool _isFormSubmitted = false;
  final int _descriptionMaxChars = 150;
  File? _image;
  List<TourguidePlace> _places = []; // List to hold TourguidePlace instances
  Place? _city;


  void _addPlace() {
    setState(() {
      _places.add(TourguidePlace(
        latitude: 0.0,
        longitude: 0.0,
        googleMapPlaceId: '',
        title: '',
        description: '',
        photoUrls: [],
      ));
      _placeControllers.add(TextEditingController());
    });
  }

  void _removePlace(int index) {
    setState(() {
      _places.removeAt(index);
      _placeControllers[index].dispose();
      _placeControllers.removeAt(index);
    });
  }

  Future<void> _firestoreCreateTour() async {
    if (_formKey.currentState!.validate()) {
      // Validation passed, proceed with tour creation
      FirebaseFirestore db = FirebaseFirestore.instance;
      FirebaseAuth auth = FirebaseAuth.instance;
      LocationProvider locationProvider =
      Provider.of<LocationProvider>(context, listen: false);
      final User user = auth.currentUser!;
      final uid = user.uid;
      final filter = ProfanityFilter();


      final tourData = {
        "name": filter.censor(_nameController.text),
        "description": filter.censor(_descriptionController.text),
        "city": _cityController.text,
        "uid": uid,
        "visibility": _tourIsPublic ? "public" : "private",
        "imageUrl": "", // Placeholder for image URL
        "createdDateTime": DateTime.now(),
        "latitude": _city!.latLng!.lat,
        "longitude": _city!.latLng!.lng,
        "placeId": _city!.id,
        "authorName": user.displayName,
        "authorId": uid,
        "tourguidePlaces": _places.map((place) => {
          "latitude": place.latitude,
          "longitude": place.longitude,
          "googleMapPlaceId": place.googleMapPlaceId,
          "title": place.title,
          "description": place.description,
          "photoUrls": place.photoUrls,
        }).toList(),
      };

      // Upload image if available
      if (_image != null) {
        String imageUrl = await _uploadImage(_image!);
        tourData["imageUrl"] = imageUrl;
      }

      try {
        await db.collection("tours").add(tourData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully created tour!')),
        );
        Navigator.pop(context); // Navigate back after successful creation
      } catch (e) {
        logger.t('Error creating tour: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create tour. Please try again.')),
        );
      }
    }
  }


  // Function to upload image to Firebase Storage
  Future<String> _uploadImage(File imageFile) async {
    // Create a reference to the location you want to upload to in Firebase Storage
    Reference ref = FirebaseStorage.instance.ref().child('tour_images').child(DateTime.now().millisecondsSinceEpoch.toString());

    // Upload the file to Firebase Storage
    UploadTask uploadTask = ref.putFile(imageFile);

    // Await the completion of the upload task
    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);

    // Upon completion, get the download URL for the image
    String imageUrl = await taskSnapshot.ref.getDownloadURL();

    return imageUrl;
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
              PlaceAutocomplete(textEditingController: _cityController,
                isFormSubmitted: _isFormSubmitted,
                onItemSelected: (AutocompletePrediction prediction) {
                  logger.t("Selected city: ${prediction.primaryText}");
                },
                onPlaceInfoFetched: (Place? place) {
                  if (place != null) {
                    _city = place;
                  }
                },
              ),
              TextFormField(
                controller: _descriptionController,
                keyboardType: TextInputType.multiline,
                maxLines: 3,
                maxLength: _descriptionMaxChars,
                decoration: InputDecoration(
                  labelText: 'Description',
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description for your tour';
                  }
                  if (value != null && value.length > _descriptionMaxChars) {
                    return 'Please enter a maximum of $_descriptionMaxChars characters';
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
              //PLACES LIST----------------------------------------------
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Tourguide Places', style: TextStyle(fontSize: 16.0)),
                  ),
                  ..._places.asMap().entries.map((entry) {
                    int index = entry.key;
                    TourguidePlace place = entry.value;

                    // Initialize controller text if it hasn't been set
                    if (_placeControllers[index].text.isEmpty) {
                      _placeControllers[index].text = place.title;
                    }
                    return Row(
                      key: ValueKey(_placeControllers[index]), // Add a unique key
                      children: [
                        Expanded(
                          child: PlaceAutocomplete(
                            textEditingController: _placeControllers[index],
                            restrictToCities: false,
                            isFormSubmitted: _isFormSubmitted,
                            decoration: InputDecoration(
                              labelText: 'Place ${index + 1}',
                              border: const UnderlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  _removePlace(index);
                                },
                              ),
                            ),
                            onItemSelected: (AutocompletePrediction prediction) {
                              setState(() {
                                place = TourguidePlace(
                                  latitude: place.latitude,
                                  longitude: place.longitude,
                                  googleMapPlaceId: place.googleMapPlaceId,
                                  title: prediction.primaryText,
                                  description: place.description,
                                  photoUrls: place.photoUrls,
                                );
                                // You might need to fetch more details about the place here
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  ElevatedButton(
                    onPressed: _addPlace,
                    child: const Text('Add Place'),
                  ),
                ],
              ),
              Center(
                child: AddImageTile(
                  initialValue: _image,
                  validator: (value) {
                    if (value == null) {
                      return 'Please add an image';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _image = value;
                  },
                  onChanged: (value) {
                    setState(() {_image = value;});
                  },
                  enabled: !_isFormSubmitted,
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