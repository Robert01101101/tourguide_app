import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tourguide_app/model/tourguide_place.dart';
import 'package:tourguide_app/tour/tour_tile.dart';
import 'package:tourguide_app/ui/form_field_add_image_tile.dart';
import 'package:tourguide_app/ui/form_field_add_image_tile_web.dart';
import 'package:tourguide_app/ui/form_field_tags.dart';
import 'package:tourguide_app/ui/place_autocomplete.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;

import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:profanity_filter/profanity_filter.dart';

import '../model/tour.dart';
import '../utilities/providers/tour_provider.dart';

/// If isEditMode is true, tour is required. Edit mode is off by default.
class CreateEditTour extends StatefulWidget {
  final bool isEditMode;
  final Tour? tour;

  const CreateEditTour({super.key, this.isEditMode = false, this.tour});

  @override
  State<CreateEditTour> createState() => _CreateEditTourState();
}

class _CreateEditTourState extends State<CreateEditTour> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _formKeyPlaces = GlobalKey<FormState>();
  final GlobalKey<FormState> _formKeyPlacesDetails = GlobalKey<FormState>();
  final GlobalKey<FormState> _formKeyDetails = GlobalKey<FormState>();
  final GlobalKey<FormFieldState> _formFieldTagsKey =
      GlobalKey<FormFieldState>();
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
  XFile? _imageWeb;
  Place? _city;
  int _selectedImgIndex = 0;
  int _currentStep = 0;
  int _maxStepReached = 0;
  bool _stepChanging = false;
  KeyboardVisibilityController? keyboardVisibilityController;

  @override
  void initState() {
    super.initState();

    logger.t('TourCreation initState() - isEditMode: ${widget.isEditMode}');

    if (widget.isEditMode) {
      _maxStepReached = _reviewStepIndex;
      _tour = widget.tour!;
      _nameController.text = _tour.name;
      _descriptionController.text = _tour.description;
      _cityController.text = _tour.city;
      //for loop
      for (int i = 0; i < _tour.tourguidePlaces.length; i++) {
        TourguidePlace place = _tour.tourguidePlaces[i];
        _placeControllers.add(TextEditingController(text: place.title));
        _placeControllers[i].selection = TextSelection.fromPosition(
            TextPosition(offset: _placeControllers[i].text.length));
        place.descriptionEditingController =
            TextEditingController(text: place.description);
        place.descriptionEditingController!.selection =
            TextSelection.fromPosition(TextPosition(
                offset: place.descriptionEditingController!.text.length));
        _updateTourguidePlaceDetailsWithPlaceId(
            i, place.googleMapPlaceId, place.title);
      }
    }

    keyboardVisibilityController = KeyboardVisibilityController();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _addPlace() {
    setState(() {
      _tour.tourguidePlaces.add(TourguidePlace(
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
      _tour.tourguidePlaces.removeAt(index);
      _placeControllers[index].dispose();
      _placeControllers.removeAt(index);
    });
  }

  // TODO: ensure city matches the city of the places
  // TODO: move to provider
  // TODO; don't use context in async!!
  Future<void> _firestoreCreateTour() async {
    try {
      /*  //should be handled by the form validation, don't validate form inactive due to not being in current step
      if (!(_formKey.currentState!.validate() && _formKeyPlaces.currentState!.validate() && _formKeyPlacesDetails.currentState!.validate() && _formKeyDetails.currentState!.validate())){
        //log the form that failed
        if (!(_formKey.currentState!.validate())) logger.e('Error creating tour: Basic Info form validation failed');
        if (!(_formKeyPlaces.currentState!.validate())) logger.e('Error creating tour: Places form validation failed');
        if (!(_formKeyPlacesDetails.currentState!.validate())) logger.e('Error creating tour: Places Details form validation failed');
        if (!(_formKeyDetails.currentState!.validate())) logger.e('Error creating tour: Details form validation failed');
        throw Exception('Error creating tour: Form validation failed');
      }*/
      final tourProvider = Provider.of<TourProvider>(context, listen: false);
      setState(() {
        _isFormSubmitted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${widget.isEditMode ? 'Updating' : 'Uploading'} tour...')),
      );
      //Final update to tour data
      final myAuth.AuthProvider authProvider =
          Provider.of(context, listen: false);
      DateTime? createdDateTime = _tour.createdDateTime;
      _tour = _tour.copyWith(
        visibility: _tourIsPublic ? "public" : "private", //always true for now
        createdDateTime: createdDateTime ?? DateTime.now(),
        lastChangedDateTime: DateTime.now(),
        authorId: authProvider.user!.uid,
        authorName: authProvider.user!.displayName,
      );
      // Validation passed, proceed with tour creation
      widget.isEditMode
          ? await tourProvider.updateTour(_tour)
          : await tourProvider.uploadTour(_tour);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Successfully ${widget.isEditMode ? 'updated' : 'uploaded'} tour. Thanks for contributing!')),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      logger.e('Error creating tour: $e \n stackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to create tour. Please try again.')),
        );
      }
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
    Reference ref = FirebaseStorage.instance
        .ref()
        .child('tour_images')
        .child(DateTime.now().millisecondsSinceEpoch.toString());

    // Upload the file to Firebase Storage
    UploadTask uploadTask = ref.putFile(imageFile);

    // Await the completion of the upload task
    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);

    // Upon completion, get the download URL for the image
    String imageUrl = await taskSnapshot.ref.getDownloadURL();

    return imageUrl;
  }

  /// Try to go to the step, but first validate and update the tour if data is valid
  void _tryToGoToStep(int step) {
    try {
      if (_stepChanging) return;
      _stepChanging = true;
      final tourProvider = Provider.of<TourProvider>(context, listen: false);

      if (step == _reviewStepIndex + 1) {
        // Final step (Review), create the tour
        logger
            .t("_currentStep: $_currentStep, step: $step -> Creating tour...");
        _firestoreCreateTour();
        _stepChanging = false;
        return;
      }

      final filter = ProfanityFilter();
      bool isValid = false;
      bool skipPermitted = step <= _currentStep + 1 ||
          step <=
              _maxStepReached; //true if not skipping, or skipping to a previous step

      if (step < _currentStep) {
        isValid = true;
      } else {
        // Determine which form key to validate based on the step
        switch (_currentStep) {
          case 0: // Basic Info
            isValid = _formKey.currentState!.validate() && skipPermitted;
            if (isValid) {
              final selectedTags = _formFieldTagsKey.currentState?.value;
              //logger.i("Selected tags: $selectedTags");
              setState(() {
                if (!widget.isEditMode) {
                  _tour = _tour.copyWith(
                      name: filter.censor(_nameController.text),
                      description: filter.censor(_descriptionController.text),
                      city: _cityController.text,
                      latitude: _city!.latLng!.lat,
                      longitude: _city!.latLng!.lng,
                      placeId: _city!.id,
                      tags: selectedTags);
                } else {
                  _tour = _tour.copyWith(
                      name: filter.censor(_nameController.text),
                      description: filter.censor(_descriptionController.text),
                      city: _cityController.text,
                      tags: selectedTags);
                  //TODO: why not update city lat/lng here in edit mode? investigate...
                }
              });
            }
            break;
          case 1: // Places
            isValid = _formKeyPlaces.currentState!.validate() && skipPermitted;
            if (isValid) {
              setState(() {
                LatLng centerPoint = _calculateCenterPoint(_tour.tourguidePlaces
                    .map((p) => LatLng(lat: p.latitude, lng: p.longitude))
                    .toList());
                _tour = _tour.copyWith(
                    latitude: centerPoint.lat,
                    longitude: centerPoint.lng,
                    tourguidePlaces: _tour.tourguidePlaces);
              });
            }
            break;
          case 2: // Place Details
            isValid =
                _formKeyPlacesDetails.currentState!.validate() && skipPermitted;
            //Set the description of the places using the controller
            setState(() {
              for (int i = 0; i < _tour.tourguidePlaces.length; i++) {
                String description =
                    _tour.tourguidePlaces[i].descriptionEditingController!.text;
                //logger.t("Updating place $i with description: $description");
                _tour.tourguidePlaces[i] = _tour.tourguidePlaces[i]
                    .copyWith(description: filter.censor(description));
              }
            });
            break;
          case 3: // Tour Details
            isValid = _formKeyDetails.currentState!.validate() && skipPermitted;
            if (kIsWeb) {
              _tour = _tour.copyWith(
                  imageFileToUploadWeb: _selectedImgIndex == -1
                      ? _imageWeb
                      : _tour.tourguidePlaces[_selectedImgIndex!]
                          .imageFileToUploadWeb);
            } else {
              _tour = _tour.copyWith(
                  imageFile: _selectedImgIndex == -1
                      ? _image
                      : _tour.tourguidePlaces[_selectedImgIndex!].imageFile);
            }
            logger.i("Reviewing tour: ${_tour.toString()}");
            break;
          default:
            break;
        }
      }

      logger.t(
          "_currentStep: $_currentStep, step: $step, isValid: $isValid, skipPermitted: $skipPermitted");

      _setAutoValidate(isValid);

      _goToStepAsync(isValid, step);
    } catch (e, stackTrace) {
      logger.e('Error trying to go to step: $e \n stackTrace: $stackTrace');
    }
  }

  Future<void> _goToStepAsync(bool isValid, int step) async {
    try {
      if (isValid) {
        final isKeyboardOpen = keyboardVisibilityController!.isVisible ||
            (_currentStep == 2 &&
                step >
                    _currentStep); //Places Details is super buggy, always wait here
        //logger.i('Keyboard visibility goToStepAsync = ${keyboardVisibilityController!.isVisible}');
        setState(() {
          FocusScope.of(context).unfocus(); // Hide the keyboard
        });
        //bugfix for bug where keyboard being open and scrolled all the way down
        // causes a huge gap after places details, when advancing from it to details
        // (last text box selected prior to clicking next)
        if (isKeyboardOpen) {
          logger.i('Keyboard is open, waiting for it to close...');
          await Future.delayed(const Duration(milliseconds: 500));
        }
        setState(() {
          _currentStep = step; // Move to the next step
          _maxStepReached = max(_maxStepReached, _currentStep);
        });
        if (isKeyboardOpen) {
          //logger.i('Keyboard is open, waiting for it to close...');
          await Future.delayed(const Duration(milliseconds: 400));
        }
        setState(() {});
      }
      _stepChanging = false;
    } catch (e, stackTrace) {
      logger.e('Error trying to go to step: $e \n stackTrace: $stackTrace');
      _stepChanging = false;
    }
  }

  void _setAutoValidate(bool isValid) {
    switch (_currentStep) {
      case 0:
        setState(() {
          _formValidateMode = isValid
              ? AutovalidateMode.disabled
              : AutovalidateMode.onUserInteraction;
        });
        break;
      case 1:
        setState(() {
          _formPlacesValidateMode = isValid
              ? AutovalidateMode.disabled
              : AutovalidateMode.onUserInteraction;
        });
        break;
      case 2:
        setState(() {
          _formDetailsValidateMode = isValid
              ? AutovalidateMode.disabled
              : AutovalidateMode.onUserInteraction;
        });
        break;
      default:
        break;
    }
  }

  Future<void> _updateTourguidePlaceDetails(
      int index, AutocompletePrediction placePrediction) async {
    _updateTourguidePlaceDetailsWithPlaceId(
        index, placePrediction.placeId, placePrediction.primaryText);
  }

  Future<void> _updateTourguidePlaceDetailsWithPlaceId(
      int index, String placeId, String primaryText) async {
    try {
      bool existingPlace = false;
      //check if it has a place with placeId
      if (_tour.tourguidePlaces.length > index &&
          _tour.tourguidePlaces[index].googleMapPlaceId == placeId) {
        logger.i(
            "_updateTourguidePlaceDetails() - place already exists with placeId: $placeId");
        existingPlace = true;
      }

      LocationProvider locationProvider = Provider.of(context, listen: false);
      Place? googlePlaceWithDetails =
          await locationProvider.getLocationDetailsFromPlaceId(placeId);
      TourguidePlaceImg? tourguidePlaceImg = await locationProvider
          .fetchPlacePhoto(placeId: placeId, setAsCurrentImage: false);
      String? photoUrl;
      Image? photo;
      if (tourguidePlaceImg == null) {
        logger.w("_updateTourguidePlaceDetails() - tourguidePlaceImg is null");
      } else {
        tourguidePlaceImg!.googlePlacesImg!.placePhotoResponse?.maybeWhen(
          image: (image) {
            photo = image;
            logger.i(
                "_updateTourguidePlaceDetails() - googlePlacesImg!.placePhotoResponse?.maybeWhen -> returned image");
          },
          imageUrl: (imageUrl) {
            photoUrl = imageUrl;
            logger.i(
                "_updateTourguidePlaceDetails() - googlePlacesImg!.placePhotoResponse?.maybeWhen -> returned imagUrl=${imageUrl}");
          },
          orElse: () {
            logger.w(
                "_updateTourguidePlaceDetails() - googlePlacesImg!.placePhotoResponse?.maybeWhen -> returned orElse");
          },
        );
      }
      TourguidePlace newTourguidePlace = TourguidePlace(
        latitude: googlePlaceWithDetails!.latLng!.lat,
        longitude: googlePlaceWithDetails!.latLng!.lng,
        googleMapPlaceId: googlePlaceWithDetails!.id!,
        title: primaryText,
        description: '',
        photoUrl: photoUrl ?? '',
        image: photo,
        imageFile: tourguidePlaceImg?.file,
        descriptionEditingController: TextEditingController(),
      );
      logger.i(
          "_updateTourguidePlaceDetails() - created updated TourguidePlace: $newTourguidePlace");
      setState(() {
        if (existingPlace) {
          _tour.tourguidePlaces[index] = _tour.tourguidePlaces[index].copyWith(
              latitude: newTourguidePlace.latitude,
              longitude: newTourguidePlace.longitude,
              googleMapPlaceId: newTourguidePlace.googleMapPlaceId,
              title: newTourguidePlace.title,
              photoUrl: newTourguidePlace.photoUrl,
              image: newTourguidePlace.image,
              imageFile: newTourguidePlace.imageFile);
        } else {
          _tour.tourguidePlaces[index] = newTourguidePlace;
        }
      });
    } catch (e, stack) {
      logger.e("_updateTourguidePlaceDetails() - error: $e, stack: $stack");
      return;
    }
  }

  void _setTourImageSelection(int newIndex) {
    setState(() {
      _selectedImgIndex = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Tour' : 'Create a new Tour'),
      ),
      body: Padding(
        padding: kIsWeb && MediaQuery.of(context).size.width > 1280
            ? EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width / 5)
            : EdgeInsets.zero,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () => _tryToGoToStep(_currentStep + 1),
          onStepCancel: () => _tryToGoToStep(_currentStep - 1),
          onStepTapped: (int step) => _tryToGoToStep(step),
          controlsBuilder:
              (BuildContext context, ControlsDetails controlsDetails) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: <Widget>[
                  if (_currentStep > 0) const SizedBox(width: 8),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: controlsDetails.onStepCancel,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                        //primary: Colors.blue, // Custom color for "Continue" button
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(3.0), // Custom radius
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  const SizedBox(
                      width: 24), // Add spacing between buttons if needed
                  TextButton(
                    onPressed: _isFormSubmitted
                        ? null
                        : controlsDetails.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor:
                          Theme.of(context).colorScheme.surfaceContainerLow,
                      //primary: Colors.grey, // Custom color for "Back" button
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(3.0), // Custom radius
                      ),
                    ),
                    child: _currentStep != _reviewStepIndex
                        ? const Text('Next')
                        : widget.isEditMode
                            ? const Text('Update Tour')
                            : const Text('Create Tour'),
                  ),
                  Spacer(),
                  /*if (_currentStep == 1) //TODO Map view
                    IconButton(
                        padding: EdgeInsets.all(10),
                        onPressed: (){},
                        icon: Icon(Icons.map))*/
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Basic Info'),
              isActive: _currentStep >= 0,
              state:
                  _maxStepReached > 0 ? StepState.complete : StepState.indexed,
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
                        if (value != null &&
                            value.characters.length > _descriptionMaxChars) {
                          return 'Please enter a maximum of $_descriptionMaxChars characters';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(
                            () {}); // Trigger a rebuild to update the character counter
                      },
                      enabled: !_isFormSubmitted,
                    ),
                    FormFieldTags(
                      key: _formFieldTagsKey,
                      enabled: !_isFormSubmitted,
                      validator: (Map<String, dynamic>? value) {
                        if (value == null || value['duration'] == null) {
                          return 'Please select a duration';
                        }
                        if (value['descriptive'] == null ||
                            (value['descriptive'] as List).isEmpty) {
                          return 'Please select at least 1 descriptive tag';
                        }
                        if ((value['descriptive'] as List).length > 5) {
                          return 'You can select up to 5 descriptive tags';
                        }
                        return null;
                      },
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
              state:
                  _maxStepReached > 1 ? StepState.complete : StepState.indexed,
              content: Form(
                autovalidateMode: _formPlacesValidateMode,
                key: _formKeyPlaces,
                child: FormField(
                  validator: (value) {
                    if (_tour.tourguidePlaces.length < 2) {
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
                                final double animValue =
                                    Curves.easeInOut.transform(animation.value);
                                final double scale =
                                    lerpDouble(1, 1.05, animValue)!;
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
                              final TourguidePlace place =
                                  _tour.tourguidePlaces.removeAt(oldIndex);
                              _tour.tourguidePlaces.insert(newIndex, place);

                              final TextEditingController controller =
                                  _placeControllers.removeAt(oldIndex);
                              _placeControllers.insert(newIndex, controller);
                            });
                          },
                          children: [
                            for (int index = 0;
                                index < _tour.tourguidePlaces.length;
                                index++)
                              Container(
                                key: ValueKey(_placeControllers[index]),
                                width: double.infinity,
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 0.0, horizontal: 0),
                                  leading: ReorderableDragStartListener(
                                    index: index,
                                    child: Icon(Icons.drag_handle),
                                  ),
                                  title: PlaceAutocomplete(
                                    textEditingController:
                                        _placeControllers[index],
                                    restrictToCities: false,
                                    isFormSubmitted: _isFormSubmitted,
                                    decoration: InputDecoration(
                                      labelText: 'Place ${index + 1}',
                                      border: const UnderlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: const Icon(
                                            Icons.remove_circle_outline),
                                        onPressed: () {
                                          _removePlace(index);
                                        },
                                      ),
                                    ),
                                    customLabel: true,
                                    onItemSelected:
                                        (AutocompletePrediction prediction) {
                                      _updateTourguidePlaceDetails(
                                          index, prediction);
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addPlace,
                            icon: Icon(Icons.add),
                            label: const Text('Add Place'),
                          ),
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        if (state.hasError)
                          Text(
                            state.errorText ?? '',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
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
              state:
                  _maxStepReached > 2 ? StepState.complete : StepState.indexed,
              content: Form(
                autovalidateMode: _formPlacesDetailsValidateMode,
                key: _formKeyPlacesDetails,
                child: Column(
                  children: [
                    for (int index = 0;
                        index < _tour.tourguidePlaces.length;
                        index++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (index + 1).toString() +
                                  ")  " +
                                  _tour.tourguidePlaces[index]
                                      .title, // Assuming _places[index] has a 'name' field
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 20.0, top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_tour.tourguidePlaces[index].image !=
                                      null)
                                    Container(
                                      height:
                                          100, // Set the desired height here
                                      width: double
                                          .infinity, // Make it fill the width of its parent
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        clipBehavior: Clip.hardEdge,
                                        child:
                                            _tour.tourguidePlaces[index].image!,
                                      ),
                                    ),
                                  SizedBox(
                                    height: 2,
                                  ),
                                  TextFormField(
                                    controller: _tour.tourguidePlaces[index]
                                        .descriptionEditingController, // Assuming each place has a description controller
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
                                  if (index < _tour.tourguidePlaces.length - 1)
                                    SizedBox(
                                      height: 30,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                  ],
                ),
              ),
            ),
            Step(
              title: const Text('Details'),
              isActive: _currentStep >= 3,
              state:
                  _maxStepReached > 3 ? StepState.complete : StepState.indexed,
              content: Form(
                autovalidateMode: _formDetailsValidateMode,
                key: _formKeyDetails,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select an image for your tour',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(
                      height: 16,
                    ),
                    SizedBox(
                      height: kIsWeb
                          ? 438
                          : ((_tour.tourguidePlaces.length + 1) / 2).ceil() *
                              167,
                      child: GridView.count(
                        crossAxisCount: kIsWeb ? 4 : 2,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                        childAspectRatio: 1.0, // Adjust as needed
                        children: [
                          for (int i = 0; i < _tour.tourguidePlaces.length; i++)
                            if (!kIsWeb &&
                                _tour.tourguidePlaces[i].image != null)
                              GestureDetector(
                                onTap: () {
                                  _setTourImageSelection(i);
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.cover,
                                      clipBehavior: Clip.hardEdge,
                                      child: _tour.tourguidePlaces[i].image!,
                                    ),
                                    if (_selectedImgIndex == i)
                                      Container(
                                        height: 146,
                                        width: 146,
                                        decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .scaffoldBackgroundColor
                                                .withOpacity(0.4),
                                            border: _selectedImgIndex == i
                                                ? Border.all(
                                                    width: 2,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary)
                                                : null),
                                      ),
                                    if (_selectedImgIndex == i)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 24,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          GestureDetector(
                            onTap: () {
                              if (kIsWeb && _imageWeb != null ||
                                  !kIsWeb && _image != null) {
                                _setTourImageSelection(-1);
                              }
                            },
                            child: Container(
                              height: kIsWeb ? 64 : 146,
                              width: kIsWeb ? 64 : 146,
                              child: kIsWeb
                                  ? AddImageTileWeb(
                                      initialValue: _imageWeb,
                                      onSaved: (value) {
                                        _imageWeb = value;
                                      },
                                      onChanged: (value) {
                                        setState(() {
                                          _imageWeb = value;
                                        });
                                        _setTourImageSelection(-1);
                                      },
                                      enabled: !_isFormSubmitted,
                                      isSelected: _selectedImgIndex == -1,
                                    )
                                  : AddImageTile(
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
                                      isSelected: _selectedImgIndex == -1,
                                    ),
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
              state:
                  _maxStepReached > 4 ? StepState.complete : StepState.indexed,
              content: Container(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      // small body text
                      child: Text('Here\'s what your tour will look like',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    SizedBox(
                      height: TourTile.height,
                      child: Shimmer(
                          linearGradient:
                              MyGlobals.createShimmerGradient(context),
                          child: TourTile(tour: _tour)),
                    ),
                    SizedBox(
                      height: 32,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
