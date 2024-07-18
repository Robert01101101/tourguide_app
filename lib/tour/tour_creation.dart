import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tourguide_app/model/tourguide_place.dart';
import 'package:tourguide_app/tour/tour_tile.dart';
import 'package:tourguide_app/ui/add_image_tile.dart';
import 'package:tourguide_app/ui/google_places_image.dart';
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
  final GlobalKey<FormState> _formKeyPlacesDetails = GlobalKey<FormState>();
  final GlobalKey<FormState> _formKeyDetails = GlobalKey<FormState>();
  AutovalidateMode _formValidateMode = AutovalidateMode.disabled;
  AutovalidateMode _formPlacesValidateMode = AutovalidateMode.disabled;
  AutovalidateMode _formPlacesDetailsValidateMode = AutovalidateMode.disabled;
  AutovalidateMode _formDetailsValidateMode = AutovalidateMode.disabled;
  final List<TextEditingController> _placeControllers = [];

  Tour _tour = Tour.isOfflineCreatedTour();
  bool _tourIsPublic = true; // Initial boolean value
  bool _isFormSubmitted = false;
  final int _descriptionMaxChars = 250;
  final int _reviewStepIndex = 4;
  File? _image;
  List<TourguidePlace> _places = []; // List to hold TourguidePlace instances
  Place? _city;
  int _selectedImgIndex = 0;
  int _currentStep = 0;

  void _addPlace() {
    setState(() {
      _places.add(TourguidePlace(
        latitude: 0.0,
        longitude: 0.0,
        googleMapPlaceId: '',
        title: '',
        description: '',
        photoUrl: '',
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

  // TODO: ensure city matches the city of the places
  // TODO: move to provider
  // TODO; don't use context in async!!
  Future<void> _firestoreCreateTour() async {
    try {
      if (!(_formKey.currentState!.validate() && _formKeyPlaces.currentState!.validate() && _formKeyPlacesDetails.currentState!.validate() && _formKeyDetails.currentState!.validate())){
        //log the form that failed
        if (!(_formKey.currentState!.validate())) logger.e('Error creating tour: Basic Info form validation failed');
        if (!(_formKeyPlaces.currentState!.validate())) logger.e('Error creating tour: Places form validation failed');
        if (!(_formKeyPlacesDetails.currentState!.validate())) logger.e('Error creating tour: Places Details form validation failed');
        if (!(_formKeyDetails.currentState!.validate())) logger.e('Error creating tour: Details form validation failed');
        return;
      }
      final tourProvider = Provider.of<TourProvider>(context, listen: false);
      setState(() {
        _isFormSubmitted = true;
        tourProvider.addTourToAllTours(_tour);
      });
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
      String imageUrl = await _uploadImage(_tour.imageToUpload!);

      //Final update to tour data
      _tour = _tour.copyWith(
        visibility: _tourIsPublic ? "public" : "private", //always true for now
        createdDateTime: DateTime.now(),
        authorId: uid,
        authorName: user.displayName,
        imageUrl: imageUrl,
      );

      // Step 1: Add tour document to 'tours' collection
      DocumentReference tourDocRef = await db.collection("tours").add(_tour.toMap());
      String tourId = tourDocRef.id; // Retrieve the auto-generated ID

      // Update the local Tour object's ID field
      _tour = _tour.copyWith(id: tourId);
      await db.collection("tours").doc(tourId).update({
        'id': _tour.id, // Update the 'id' field with the new tourId
      });

      logger.i('Successfully created tour: ${_tour.toString()}');

      //add empty rating for user
      TourService.addOrUpdateRating(_tour.id, 0, authProvider.user!.uid);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully created tour. Thanks for contributing!')),
      );
      Navigator.pop(context);
    } catch (e, stackTrace) {
      logger.e('Error creating tour: $e \n stackTrace: $stackTrace');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create tour. Please try again.')),
      );
      setState(() {
        _isFormSubmitted = false;
      });
    }
  }

  LatLng _calculateCenterPoint(List<LatLng> points) {
    if (points.isEmpty) {
      throw ArgumentError('The list of points cannot be empty');
    }

    double totalLatitude = 0;
    double totalLongitude = 0;

    for (var point in points) {
      totalLatitude += point.lat;
      totalLongitude += point.lng;
    }

    double centerLatitude = totalLatitude / points.length;
    double centerLongitude = totalLongitude / points.length;

    return LatLng(lat: centerLatitude, lng: centerLongitude);
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

    if (step == _reviewStepIndex+1) {
      // Final step (Review), create the tour
      logger.t("_currentStep: $_currentStep, step: $step -> Creating tour...");
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
              LatLng centerPoint = _calculateCenterPoint(_places.map((p) => LatLng(lat: p.latitude, lng: p.longitude)).toList());
              _tour = _tour.copyWith(
                  latitude: centerPoint.lat,
                  longitude: centerPoint.lng,
                  tourguidePlaces: _places);
            });
          }
          break;
        case 2: // Place Details
          isValid = _formKeyPlacesDetails.currentState!.validate();
          //Set the description of the places using the controller
          setState(() {
            for (int i = 0; i < _places.length; i++) {
              String description = _places[i].descriptionEditingController!.text;
              _places[i] = _places[i].copyWith(description: filter.censor(description));
            }
          });
          break;
        case 3: // Tour Details
          isValid = _formKeyDetails.currentState!.validate();
          _tour = _tour.copyWith(imageToUpload: _selectedImgIndex == -1 ? _image : _places[_selectedImgIndex!].imageFile);
          logger.i("Reviewing tour: ${_tour.toString()}");
          break;
        default:
          break;
      }
    }
    if (step == _reviewStepIndex){
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
    TourguidePlaceImg? tourguidePlaceImg = await locationProvider.fetchPlacePhoto(placeId: placePrediction.placeId, setAsCurrentImage: false);
    String? photoUrl;
    Image? photo;
    tourguidePlaceImg!.googlePlacesImg!.placePhotoResponse?.maybeWhen(
      image: (image) {
        photo = image;
        logger.i("_updateTourguidePlaceDetails() - googlePlacesImg!.placePhotoResponse?.maybeWhen -> returned image");
      },
      imageUrl: (imageUrl) {
        photoUrl = imageUrl;
        logger.i("_updateTourguidePlaceDetails() - googlePlacesImg!.placePhotoResponse?.maybeWhen -> returned imagUrl=${imageUrl}");
      },
      orElse: () {
        logger.w("_updateTourguidePlaceDetails() - googlePlacesImg!.placePhotoResponse?.maybeWhen -> returned orElse");
      },
    );
    TourguidePlace newTourguidePlace = TourguidePlace(
      latitude: googlePlaceWithDetails!.latLng!.lat,
      longitude: googlePlaceWithDetails!.latLng!.lng,
      googleMapPlaceId: googlePlaceWithDetails!.id!,
      title: placePrediction.primaryText,
      description: '',
      photoUrl: photoUrl ?? '',
      image: photo,
      imageFile: tourguidePlaceImg.file,
      descriptionEditingController: TextEditingController(),
    );
    logger.i("_updateTourguidePlaceDetails() - created updated TourguidePlace: $newTourguidePlace");
    setState(() {
      _places[index] = newTourguidePlace;
    });
  }

  void _setTourImageSelection(int newIndex){
    setState(() {
      _selectedImgIndex = newIndex;
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
                  child: _currentStep != _reviewStepIndex ? const Text('Next') : const Text('Create Tour'),
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
                    minLines: 4,
                    maxLines: 8,
                    maxLength: _descriptionMaxChars,
                    decoration: InputDecoration(
                      labelText: 'Description',
                    ),
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a description for your tour';
                      }
                      if (value != null && value.characters.length > _descriptionMaxChars) {
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
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReorderableListView(
                        buildDefaultDragHandles: false,
                        physics: ClampingScrollPhysics(),
                        shrinkWrap: true,
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (BuildContext context, Widget? child) {
                              final double animValue = Curves.easeInOut.transform(animation.value);
                              final double scale = lerpDouble(1, 1.05, animValue)!;
                              return Transform.scale(
                                scale: scale,
                                child: Material(
                                  color: Colors.white,
                                  elevation: 8,
                                  child: child,
                                ),
                              );
                            },
                            child: child,
                          );
                        },
                        onReorder: (int oldIndex, int newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final TourguidePlace place = _places.removeAt(oldIndex);
                            _places.insert(newIndex, place);

                            final TextEditingController controller = _placeControllers.removeAt(oldIndex);
                            _placeControllers.insert(newIndex, controller);
                          });
                        },
                        children: [
                          for (int index = 0; index < _places.length; index++)
                            Container(
                              key: ValueKey(_placeControllers[index]),
                              width: double.infinity,
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 0),
                                leading: ReorderableDragStartListener(
                                  index: index,
                                  child: Icon(Icons.drag_handle),
                                ),
                                title: PlaceAutocomplete(
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
                            ),
                        ],
                      ),
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
            title: const Text('Places Details'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: Form(
              autovalidateMode: _formPlacesDetailsValidateMode,
              key: _formKeyPlacesDetails,
              child: ListView.builder(
                physics: ClampingScrollPhysics(),
                shrinkWrap: true,
                itemCount: _places.length,
                itemBuilder: (BuildContext context, int index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (index+1).toString() + ")  " + _places[index].title, // Assuming _places[index] has a 'name' field
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 20.0, top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_places[index].image != null)
                                Container(
                                  height: 100, // Set the desired height here
                                  width: double.infinity, // Make it fill the width of its parent
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    clipBehavior: Clip.hardEdge,
                                    child: _places[index].image!,
                                  ),
                                ),
                              SizedBox(height: 2,),
                              TextFormField(
                                controller: _places[index].descriptionEditingController, // Assuming each place has a description controller
                                decoration: InputDecoration(
                                  labelText: 'Description',
                                ),
                                minLines: 3,
                                maxLines: 20,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a description';
                                  }
                                  return null;
                                },
                              ),
                              if (index < _places.length - 1)
                                SizedBox(height: 30,),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Step(
            title: const Text('Details'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            content: Form(
              autovalidateMode: _formDetailsValidateMode,
              key: _formKeyDetails,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select an image for your tour', style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: 16,),
                  SizedBox(
                    height: ((_places.length+1)/2).ceil() * 164,
                    child: GridView.count(
                      crossAxisCount: 2,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: 1.0, // Adjust as needed
                      children: [
                        for (int i = 0; i < _places.length; i++)
                          if (_places[i].image != null)
                            GestureDetector(
                              onTap: () {
                                _setTourImageSelection(i);
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    height: 146, // Set the desired height here
                                    width: 146, // Make it fill the width of its parent
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      clipBehavior: Clip.hardEdge,
                                      child: _places[i].image!,
                                    ),
                                  ),
                                  if (_selectedImgIndex == i)
                                    Container(
                                      color: Colors.white.withOpacity(0.3), // Adjust the opacity to make it darker or lighter
                                    ),
                                  if (_selectedImgIndex == i)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 24,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        GestureDetector(
                          onTap: () {
                            if (_image != null) {
                              _setTourImageSelection(-1);
                            }
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AddImageTile(
                                initialValue: _image,
                                onSaved: (value) {
                                  _image = value;
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _image = value;
                                  });
                                  _setTourImageSelection(-1);
                                },
                                enabled: !_isFormSubmitted,
                              ),
                              if (_selectedImgIndex == -1)
                                IgnorePointer(
                                  child: Container(
                                    color: Colors.white.withOpacity(0.1), // Adjust the opacity to make it darker or lighter
                                  ),
                                ),
                              if (_selectedImgIndex == -1)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Review'),
            isActive: _currentStep >= 4,
            state: _currentStep > 4 ? StepState.complete : StepState.indexed,
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
                  SizedBox(
                    height: 220,
                    child: Shimmer(
                        linearGradient: MyGlobals.shimmerGradient,
                        child: TourTile(tour: _tour)
                    ),
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
