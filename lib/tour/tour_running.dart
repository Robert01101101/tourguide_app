import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/tour/tour_tag.dart';
import 'package:tourguide_app/tour/tour_creation.dart';
import 'package:tourguide_app/tour/tour_details_options.dart';
import 'package:tourguide_app/tour/tourguide_user_profile_view.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/tour/tour_rating_bookmark_buttons.dart';
import 'package:tourguide_app/ui/tts_text.dart';
import 'package:tourguide_app/utilities/map_utils.dart';
import 'package:tourguide_app/tour/tour_map.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../utilities/custom_import.dart';
import '../utilities/services/tts_service.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart'
    as my_auth;

class TourRunning extends StatefulWidget {
  const TourRunning({super.key});

  @override
  State<TourRunning> createState() => _TourRunningState();
}

class _TourRunningState extends State<TourRunning> {
  final TourMapController _tourMapController = TourMapController();
  final TtsService _ttsService = TtsService();
  StreamSubscription<TtsState>? _ttsSubscription;
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _targetKeys = [];
  Tour _tour = Tour.empty();
  int _currentStep = 0;
  bool _currentStepVisible = true;
  bool _initialZoomToFirstWaypointComplete = false;
  int thisUsersRating = 0;
  bool _tourFinished = false;
  bool _mapCurrentlyPinnedAtTop = false;
  double _mapYposition = 0;
  final GlobalKey _mapKey = GlobalKey();
  bool _ignoreStopEvent = false; //rly scrappy solution TODO: better fix

  @override
  void initState() {
    super.initState();
    TourProvider tourProvider =
        Provider.of<TourProvider>(context, listen: false);
    _tour = tourProvider.selectedTour!;
    thisUsersRating = _tour.thisUsersRating ?? 0;
    //add global keys for each place, as well as one extra for the final scroll
    for (int i = 0; i <= _tour.tourguidePlaces.length; i++) {
      _targetKeys.add(GlobalKey());
    }
    _scrollController.addListener(_handleScroll);

    my_auth.AuthProvider authProvider = Provider.of(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tourMapController.initTourMapController(
        tour: _tour,
        onInfoTapped: (int step) {
          logger.t('Step $step tapped');
          _setStep(step);
        },
        showOptionsDialog: (BuildContext context) {
          _showOptionsDialog(context);
        },
        idToken: authProvider.user!.uid,
      );
      _getMapPosition();
    });

    //Listen to tts state changes
    _ttsSubscription = _ttsService.ttsStateStream.listen((TtsState state) {
      if (_ignoreStopEvent) {
        _ignoreStopEvent = false;
        return;
      }
      if (state == TtsState.stopped) {
        setState(() {
          currentlyPlayingIndex = null;
          logger
              .t('TTS stopped, currentlyPlayingIndex: $currentlyPlayingIndex');
        });
      }
    });
  }

  @override
  void dispose() {
    _ttsService.stop();
    _ttsSubscription?.cancel();
    super.dispose();
  }

  void _handleScroll() {
    // Get the scroll offset
    final scrollOffset = _scrollController.offset;

    // Determine the height of the SliverPinnedHeader
    //final pinnedHeaderHeight = kIsWeb ? 450.0 : 350.0;
    // Get the render box of the map widget
    final RenderBox renderBox =
        _mapKey.currentContext?.findRenderObject() as RenderBox;

    // Get the offset of the map widget relative to the screen
    final Offset position = renderBox.localToGlobal(Offset.zero);

    // Get the vertical position (Y-coordinate)
    final double yPosition = position.dy;

    // Check if the scroll offset has reached the point where the header is pinned
    final isPinned = scrollOffset >= _mapYposition; //pinnedHeaderHeight;

    // Update the state if the pinned state has changed
    if (_mapCurrentlyPinnedAtTop != isPinned) {
      logger.i(
          'Map pinned at top: $isPinned, scrollOffset: $scrollOffset, yPosition: $yPosition'); // pinnedHeaderHeight: $pinnedHeaderHeight');
      setState(() {
        _mapCurrentlyPinnedAtTop = isPinned;
      });
    }
  }

  void _getMapPosition() {
    // Get the render box of the map widget
    final RenderBox renderBox =
        _mapKey.currentContext?.findRenderObject() as RenderBox;

    // Get the offset of the map widget relative to the screen
    final Offset position = renderBox.localToGlobal(Offset.zero);

    // Get the vertical position (Y-coordinate)
    _mapYposition = position.dy;

    // Now you can use yPosition as needed
    //logger.t("Map Y Position: $_mapYposition");
  }

  void _showOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TourDetailsOptions(
          onEditPressed: () {
            // Handle edit button press
            Navigator.of(context).pop(); // Close the dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CreateEditTour(
                      isEditMode: true,
                      tour: _tour.copyWith(isOfflineCreatedTour: true))),
            );
          },
          onDeletePressed: () {
            // Handle delete button press
            Navigator.of(context).pop(); // Close the dialog
            _deleteTour();
          },
          tour: _tour,
        );
      },
    );
  }

  void _deleteTour() async {
    try {
      // Handle delete tour
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleting tour...')),
      );
      final tourProvider = Provider.of<TourProvider>(context, listen: false);
      await tourProvider.deleteTour(_tour);
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully deleted tour.')),
        );
      }
    } catch (e) {
      logger.e('Failed to delete tour: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to delete tour due to an error.')),
        );
      }
    }
  }

  int? currentlyPlayingIndex; // Track the index of the currently playing place

  Future<void> _toggleTTS(String description, int index) async {
    logger.t(
        'Toggling TTS for place $index, currentlyPlayingIndex: $currentlyPlayingIndex, description: $description');
    await _ttsService.stop();
    if (currentlyPlayingIndex == index) {
      //stop
      setState(() {
        currentlyPlayingIndex = null; // Reset the index
      });
    } else {
      //play
      await Future.delayed(
          const Duration(milliseconds: 100)); //TODO: better fix
      setState(() {
        currentlyPlayingIndex = index; // Set the currently playing index
      });
      _ttsService.speak(description); // Start speaking
    }
    logger.t(
        'Toggling TTS for place $index, currentlyPlayingIndex: $currentlyPlayingIndex, description: $description AFTER');
  }

  Future<void> _changeTtsSpeakPosition(String newSubstring) async {
    _ignoreStopEvent = true;
    await _ttsService.stop();
    await Future.delayed(const Duration(milliseconds: 100)); //TODO: better fix
    _ttsService.speak(newSubstring);
    logger.t(
        'Changing TTS speak position to: $newSubstring, currentlyPlayingIndex: $currentlyPlayingIndex');
  }

  void _scrollToTarget(int placeIndex, {bool delay = false}) {
    if (delay) {
      Future.delayed(const Duration(milliseconds: 350), () {
        _scrollToTarget(placeIndex);
      });
    } else {
      final context = _targetKeys[placeIndex].currentContext;
      if (context != null) {
        _tourMapController.setFullScreen(false);
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _finishTour() {
    logger.i('Tour Finished');
    setState(() {
      _tourFinished = true;
    });
    _scrollToTarget(_tour.tourguidePlaces.length, delay: true);
  }

  void _setStep(int step) {
    setState(() {
      if (_currentStep == step) {
        _currentStepVisible = !_currentStepVisible;
      } else {
        _currentStepVisible = true;
      }
      _currentStep = step;
    });
    _scrollToTarget(_currentStep, delay: true);
    _tourMapController.moveCameraToMarkerAndHighlightMarker!(_currentStep);
    //_moveCameraToMarkerAndHighlightMarker(_currentStep);
  }

  @override
  Widget build(BuildContext context) {
    bool isOfflineCreatedTour = (_tour.isOfflineCreatedTour ?? false);

    //logger.t('TourRunning.build()');

    return TourMapFullscreen(
      tour: _tour,
      tourMapController: _tourMapController,
      tourRunningMap: true,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            actions: [
              if (!isOfflineCreatedTour)
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showOptionsDialog(context);
                  },
                ),
            ],
            foregroundColor: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).scaffoldBackgroundColor
                : Colors.white,
            floating: false,
            pinned: false,
            expandedHeight: 230.0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Transform.translate(
                offset: Offset(0, -32),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 56.0),
                  child: Text(
                      textAlign: TextAlign.left,
                      _tour.name,
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Theme.of(context).scaffoldBackgroundColor
                                    : Colors.white,
                          )),
                ),
              ),
              titlePadding: EdgeInsets.only(bottom: 0.0),
              expandedTitleScale: 1,
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    height: kIsWeb ? 400 : 230,
                    child: ClipRRect(
                      child: kIsWeb
                          ? Image.network(_tour.imageUrl!,
                              width: MediaQuery.of(context).size.width,
                              height: 400.0,
                              fit: BoxFit.cover)
                          : _tour.imageFile != null
                              ? //add null safety for img to upload
                              Image.file(_tour.imageFile!,
                                  width: MediaQuery.of(context).size.width,
                                  height: 230.0,
                                  fit: BoxFit.cover)
                              : Container(
                                  color: Colors.grey,
                                  width: MediaQuery.of(context).size.width,
                                  height: 230.0,
                                ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SelectionArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: StandardLayout(
                  children: [
                    Text(
                      _tour.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TourTagsRow(tags: TourTag.parseTags(_tour.tags!)),
                  ],
                ),
              ),
            ),
          ),
          SliverPinnedHeader(
            child: TourMap(
              tour: _tour,
              tourMapController: _tourMapController,
              tourRunningMap: true,
              mapKey: _mapKey,
              mapCurrentlyPinnedAtTop: _mapCurrentlyPinnedAtTop,
            ),
          ),
          SliverToBoxAdapter(
            child: StandardLayout(
              children: [
                StandardLayoutChild(
                  fullWidth: true,
                  child: Column(
                    //wrap in columnn to remove gap between stepper and bottom row, since stepper has a lot of margin by default
                    children: [
                      if (kIsWeb) const SizedBox(height: 32.0),
                      if (_tour.tourguidePlaces.isNotEmpty)
                        Transform.translate(
                          // Move the stepper up to hide top margin, seems to be the easiest way to achieve it
                          offset: Offset(0, -32),
                          child: Stepper(
                            currentStep: _currentStep,
                            physics: NeverScrollableScrollPhysics(),
                            onStepTapped: (step) {
                              _setStep(step);
                            },
                            onStepContinue: () {
                              if (_currentStep < _tour.tourguidePlaces.length) {
                                setState(() {
                                  _currentStep += 1;
                                });
                                _scrollToTarget(_currentStep, delay: true);
                                _tourMapController
                                        .moveCameraToMarkerAndHighlightMarker!(
                                    _currentStep);
                                //_moveCameraToMarkerAndHighlightMarker(_currentStep);
                              }
                            },
                            onStepCancel: () {
                              if (_currentStep > 0) {
                                setState(() {
                                  _currentStep -= 1;
                                });
                                _scrollToTarget(_currentStep, delay: true);
                                _tourMapController
                                        .moveCameraToMarkerAndHighlightMarker!(
                                    _currentStep);
                                //_moveCameraToMarkerAndHighlightMarker(_currentStep);
                              }
                            },
                            controlsBuilder: (BuildContext context,
                                ControlsDetails controlsDetails) {
                              return Stack(
                                children: [
                                  Visibility(
                                      visible: !_currentStepVisible,
                                      child: Container()),
                                  Visibility(
                                    visible: _currentStepVisible,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: <Widget>[
                                          const SizedBox(width: 8),
                                          if (_currentStep > 0)
                                            TextButton(
                                              onPressed:
                                                  controlsDetails.onStepCancel,
                                              style: ElevatedButton.styleFrom(
                                                elevation: 0,
                                                backgroundColor:
                                                    Colors.transparent,
                                                foregroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onSecondaryContainer,
                                                //primary: Colors.blue, // Custom color for "Continue" button
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          3.0), // Custom radius
                                                ),
                                              ),
                                              child:
                                                  const Text('Previous Place'),
                                            ),
                                          const SizedBox(
                                              width:
                                                  24), // Add spacing between buttons if needed
                                          TextButton(
                                            onPressed: _currentStep !=
                                                    _tour.tourguidePlaces
                                                            .length -
                                                        1
                                                ? controlsDetails.onStepContinue
                                                : !_tourFinished
                                                    ? _finishTour
                                                    : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              foregroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerLow,
                                              //primary: Colors.grey, // Custom color for "Back" button
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        3.0), // Custom radius
                                              ),
                                            ),
                                            child: _currentStep !=
                                                    _tour.tourguidePlaces
                                                            .length -
                                                        1
                                                ? const Text('Next Place')
                                                : const Text('Finish Tour'),
                                          ),
                                          Spacer(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                            margin: EdgeInsets.zero,
                            steps: _tour.tourguidePlaces
                                .asMap()
                                .entries
                                .map((entry) {
                              int index = entry.key;
                              var place = entry.value;
                              return Step(
                                title: Text(
                                    key: _targetKeys.isNotEmpty &&
                                            _targetKeys.length > index
                                        ? _targetKeys[index]
                                        : null,
                                    place.title),
                                isActive: _currentStep >= (index),
                                state: _currentStep > (index)
                                    ? StepState.complete
                                    : StepState.indexed,
                                content: Visibility(
                                  visible: _currentStepVisible,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        //Title Row
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Row(
                                              children: [
                                                Text(
                                                  "${index + 1}. ",
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium!
                                                      .copyWith(
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                  maxLines: 2,
                                                ),
                                                const SizedBox(width: 8.0),
                                                Flexible(
                                                  child: Text(
                                                    "${place.title}",
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium!
                                                        .copyWith(
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                    maxLines: 2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                onPressed: () =>
                                                    MapUtils.openMapWithQuery(
                                                        place.title),
                                                icon: Icon(Icons.directions),
                                              ),
                                            ],
                                          ),
                                          IconButton(
                                            onPressed: () => _toggleTTS(
                                                place.description, index),
                                            icon: Icon(
                                                currentlyPlayingIndex == index
                                                    ? Icons.stop
                                                    : Icons.play_circle),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 6.0),
                                      VisibilityDetector(
                                        key: Key('place$index'),
                                        onVisibilityChanged:
                                            (VisibilityInfo info) {
                                          if (info.visibleFraction == 1) {
                                            if (!_initialZoomToFirstWaypointComplete) {
                                              logger.t(
                                                  'Place $index visibility: ${info.visibleFraction} - > _initialZoomToFirstWaypoint');
                                              _initialZoomToFirstWaypointComplete =
                                                  true;
                                              //_moveCameraToMarkerAndHighlightMarker(0);
                                              _tourMapController
                                                  .moveCameraToMarkerAndHighlightMarker!(0);
                                            }
                                          }
                                        },
                                        child: TtsText(
                                          text: place.description,
                                          ttsService: _ttsService,
                                          currentlyPlayingItem:
                                              currentlyPlayingIndex == index,
                                          onWordTapped:
                                              (String remainingString) {
                                            _changeTtsSpeakPosition(
                                                remainingString);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      Visibility(
                        visible: _tourFinished,
                        child: Column(
                          children: [
                            Text(
                                key: _targetKeys.isNotEmpty &&
                                        _targetKeys.length >
                                            _tour.tourguidePlaces.length
                                    ? _targetKeys[_targetKeys.length - 1]
                                    : null,
                                'We hope you\'ve enjoyed this tour!',
                                style: Theme.of(context).textTheme.bodyMedium),
                            SizedBox(height: 32.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TourRatingBookmarkButtons(tour: _tour),
                              ],
                            ),
                            SizedBox(height: 32.0),
                          ],
                        ),
                      ),
                      if (!isOfflineCreatedTour)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                'Created on ${_tour.createdDateTime!.toLocal().toString().split(' ')[0]} by:',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              TourguideUserProfileView(
                                                  tourguideUserId:
                                                      _tour.authorId,
                                                  tourguideUserDisplayName:
                                                      _tour.authorName)),
                                    );
                                  },
                                  child: Text(_tour.authorName))
                            ],
                          ),
                        ),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
