import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tourguide_app/model/tourguide_place.dart';
import 'package:tourguide_app/tour/rounded_tile.dart';
import 'package:tourguide_app/ui/add_image_tile.dart';
import 'package:tourguide_app/ui/place_autocomplete.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;

import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:profanity_filter/profanity_filter.dart';

import '../model/tour.dart';
import '../utilities/providers/tour_provider.dart';

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
  final GlobalKey<FormState> _formKeyPlaces = GlobalKey<FormState>();
  final GlobalKey<FormState> _formKeyDetails = GlobalKey<FormState>();
  AutovalidateMode _formValidateMode = AutovalidateMode.disabled;
  AutovalidateMode _formPlacesValidateMode = AutovalidateMode.disabled;
  AutovalidateMode _formDetailsValidateMode = AutovalidateMode.disabled;
  final List<TextEditingController> _placeControllers = [];

  Tour _tour = Tour.isOfflineCreatedTour();
  bool _tourIsPublic = true; // Initial boolean value
  bool _isFormSubmitted = false;
  final int _descriptionMaxChars = 150;
  final int _validationStepIndex = 3;
  File? _image;
  List<TourguidePlace> _places = []; // List to hold TourguidePlace instances
  Place? _city;

  int _currentStep = 0;

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
    logger.t('Removing place at index $index');
    setState(() {
      _places.removeAt(index);
      _placeControllers[index].dispose();
      _placeControllers.removeAt(index);
    });
  }

  Future<void> _firestoreCreateTour() async {
    try {
      if (_formKey.currentState!.validate() && _formKeyPlaces.currentState!.validate() && _formKeyDetails.currentState!.validate()){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading tour...')),
        );
        // Validation passed, proceed with tour creation
        FirebaseFirestore db = FirebaseFirestore.instance;
        FirebaseAuth auth = FirebaseAuth.instance;
        final myAuth.AuthProvider authProvider = Provider.of(context, listen: false);
        final User user = auth.currentUser!;
        final uid = authProvider.user!.uid;

        // Upload image
        String imageUrl = await _uploadImage(_image!);

        //Final update to tour data
        _tour = _tour.copyWith(
          visibility: _tourIsPublic ? "public" : "private", //always true for now
          createdDateTime: DateTime.now(),
          authorId: uid,
          authorName: user.displayName,
          imageUrl: imageUrl,
        );

        try {
          await db.collection("tours").add(_tour.toMap());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully created tour. Thanks for contributing!')),
          );
          Navigator.pop(context); // Navigate back after successful creation
        } catch (e) {
          logger.t('Error creating tour: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create tour. Please try again.')),
          );
        }
      }
    } catch (e) {
      logger.e('Error creating tour: $e');
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

  /// Try to go to the step, but first validate and update the tour if data is valid
  void _tryToGoToStep(int step){
    final tourProvider = Provider.of<TourProvider>(context, listen: false);

    if (step == _validationStepIndex+1) {
      // Final step (Review), create the tour
      setState(() {
        _isFormSubmitted = true;
        tourProvider.addTourToAllTours(_tour);
      });
      _firestoreCreateTour();
      return;
    }

    final filter = ProfanityFilter();
    bool isValid = false;


    if (step < _currentStep) {
      isValid = true;
    } else {
      // Determine which form key to validate based on the step
      switch (_currentStep) {
        case 0: // Basic Info
          isValid = _formKey.currentState!.validate();
          if (isValid){
            setState(() {
                _tour = _tour.copyWith(
                  name: filter.censor(_nameController.text),
                  description: filter.censor(_descriptionController.text),
                  city: _cityController.text,
                  latitude: _city!.latLng!.lat,
                  longitude: _city!.latLng!.lng,
                  placeId: _city!.id);
            });
          }
          break;
        case 1: // Places
          isValid = _formKeyPlaces.currentState!.validate();
          if (isValid){
            setState(() {
              _tour = _tour.copyWith(
                  latitude: _places.first.latitude,
                  longitude: _places.first.longitude,
                  tourguidePlaces: _places);
            });
          }
          break;
        case 2: // Details
          isValid = _formKeyDetails.currentState!.validate();
          //_image is set directly so nothing to do here for now
          setState(() {
            _tour = _tour.copyWith(
              imageToUpload: _image,
            );
          });
          logger.i("Reviewing tour: ${_tour.toString()}");
          break;
        default:
          break;
      }
    }
    if (step == _validationStepIndex){
      tourProvider.addTourToAllTours(_tour);
    } else {
      tourProvider.removeTourFromAllTours(_tour);
    }

    logger.t("_currentStep: $_currentStep, step: $step, isValid: $isValid");

    _setAutoValidate(isValid);

    if (isValid) {
      setState(() {
        _currentStep = step; // Move to the next step
      });
    }
  }

  void _setAutoValidate(bool isValid){
    switch (_currentStep) {
      case 0:
        setState(() {
          _formValidateMode = isValid ? AutovalidateMode.disabled : AutovalidateMode.onUserInteraction;
        });
        break;
      case 1:
        setState(() {
          _formPlacesValidateMode = isValid ? AutovalidateMode.disabled : AutovalidateMode.onUserInteraction;
        });
        break;
      case 2:
        setState(() {
          _formDetailsValidateMode = isValid ? AutovalidateMode.disabled : AutovalidateMode.onUserInteraction;
        });
        break;
      default:
        break;
    }
  }



  Future <void> _updateTourguidePlaceDetails(int index, AutocompletePrediction placePrediction) async{
    LocationProvider locationProvider = Provider.of(context, listen: false);
    Place? googlePlaceWithDetails = await locationProvider.getLocationDetailsFromPlaceId(placePrediction.placeId);
    TourguidePlace newTourguidePlace = TourguidePlace(
      latitude: googlePlaceWithDetails!.latLng!.lat,
      longitude: googlePlaceWithDetails!.latLng!.lng,
      googleMapPlaceId: googlePlaceWithDetails!.id!,
      title: placePrediction.primaryText,
      description: '',
      photoUrls: [],
    );
    setState(() {
      _places[index] = newTourguidePlace;
    });
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a new tour'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () => _tryToGoToStep(_currentStep + 1),
        onStepCancel:() => _tryToGoToStep(_currentStep - 1),
        onStepTapped: (int step) => _tryToGoToStep(step),
        controlsBuilder: (BuildContext context, ControlsDetails controlsDetails) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                if (_currentStep > 0)
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: controlsDetails.onStepCancel,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.grey[700],
                      //primary: Colors.blue, // Custom color for "Continue" button
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3.0), // Custom radius
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                const SizedBox(width: 24), // Add spacing between buttons if needed
                TextButton(
                  onPressed: _isFormSubmitted ? null : controlsDetails.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    //primary: Colors.grey, // Custom color for "Back" button
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.0), // Custom radius
                    ),
                  ),
                  child: _currentStep < 3 ? const Text('Next') : const Text('Create Tour'),
                ),
                Spacer(),
                if (_currentStep == 1)
                  IconButton(
                      padding: EdgeInsets.all(10),
                      onPressed: (){},
                      icon: Icon(Icons.map))
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Basic Info'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Form(
              autovalidateMode: _formValidateMode,
              key: _formKey,
              child: Column(
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
                  PlaceAutocomplete(
                    textEditingController: _cityController,
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
                  /*
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
                  ),*/
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Places'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Form(
              autovalidateMode: _formPlacesValidateMode,
              key: _formKeyPlaces,
              child: FormField(
                validator: (value) {
                  if (_places.length < 2) {
                    return 'Please add at least two places.';
                  }
                  return null;
                },
                builder: (FormFieldState<dynamic> state) {
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(bottom: 8.0),
                                // small body text
                                child: Text('Add your waypoints by searching for places', style: Theme.of(context).textTheme.bodyMedium),
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
                                        customLabel: true,
                                        onItemSelected: (AutocompletePrediction prediction) {
                                            _updateTourguidePlaceDetails(index, prediction);
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                              SizedBox(height: 16,),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _addPlace,
                                  icon: Icon(Icons.add),
                                  label: const Text('Add Place'),
                                ),
                              ),
                              SizedBox(height: 16,),
                            ],
                          ),
                        ],
                      ),
                      if (state.hasError)
                        Text(
                          state.errorText ?? '',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          Step(
            title: const Text('Details'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: Form(
              autovalidateMode: _formDetailsValidateMode,
              key: _formKeyDetails,
              child: Column(
                children: [
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
                        setState(() {
                          _image = value;
                        });
                      },
                      enabled: !_isFormSubmitted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Review'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            content: Container(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    // small body text
                    child: Text('Here\'s what your tour will look like', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  Shimmer(
                      linearGradient: MyGlobals.shimmerGradient,
                      child: RoundedTile(tour: _tour)
                  ),
                  SizedBox(height: 32,),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
