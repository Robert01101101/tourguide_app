import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/tour/tour_tag.dart';
import 'package:tourguide_app/tour/tour_creation.dart';
import 'package:tourguide_app/tour/tour_details_options.dart';
import 'package:tourguide_app/tour/tourguide_user_profile_view.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/maps/tour_map.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'tour_rating_bookmark_buttons.dart';
import '../utilities/custom_import.dart';
import '../utilities/providers/tourguide_user_provider.dart';
import '../utilities/singletons/tts_service.dart';

class FullscreenTourPage extends StatefulWidget {
  final Tour tour;

  const FullscreenTourPage({Key? key, required this.tour}) : super(key: key);

  @override
  State<FullscreenTourPage> createState() => _FullscreenTourPageState();
}

class _FullscreenTourPageState extends State<FullscreenTourPage> {
  final TourMapController _tourMapController = TourMapController();
  final Completer<GoogleMapController> _mapControllerCompleter = Completer<GoogleMapController>();
  bool _isFullScreen = false;
  bool _isLoading = true, _isLoadingFullscreen = true;
  CameraPosition _currentCameraPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.0,
  );
  Set<Marker> _markers = Set<Marker>();
  Set<Polyline> _polylines = Set<Polyline>();
  final TtsService _ttsService = TtsService();
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _targetKeys = [];
  int thisUsersRating = 0;


  @override
  void initState() {
    thisUsersRating = widget.tour.thisUsersRating ?? 0;
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tourMapController.initTourMapController(
        tour: widget.tour,
        primaryColor:  Theme.of(context).colorScheme.primary,
        onInfoTapped: (int step) {
          logger.t('Step $step tapped');
          //_setStep(step);
        },
        showOptionsDialog: (BuildContext context) {
          _showOptionsDialog(context);
        },
      );
    });
  }

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }


  void _showOptionsDialog(BuildContext context) {
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TourDetailsOptions(
          onEditPressed: () {
            // Handle edit button press
            Navigator.of(context).pop(); // Close the dialog
            Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => CreateEditTour(isEditMode: true,tour: widget.tour.copyWith(isOfflineCreatedTour: true))),
            );
          },
          onDeletePressed: () {
            // Handle delete button press
            Navigator.of(context).pop(); // Close the dialog
            _deleteTour();
          },
          tour: widget.tour,
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
      await tourProvider.deleteTour(widget.tour);
      if (mounted){
        Navigator.of(context).pop();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully deleted tour.')),
        );
      }

    } catch (e) {
      logger.e('Failed to delete tour: $e');
      if (mounted){
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete tour due to an error.')),
        );
      }
    }


  }

  int? currentlyPlayingIndex; // Track the index of the currently playing place

  void _scrollToTarget(int placeIndex) {
    final context = _targetKeys[placeIndex].currentContext;
    if (context != null) {
      setState(() {
        _isFullScreen = false;
      });
      Scrollable.ensureVisible(
        context,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  //TODO unify behavior and UI with tour tile
  void startTour() {
    TourProvider tourProvider = Provider.of<TourProvider>(context, listen: false);
    tourProvider.selectTourById(widget.tour.id);
    // Navigate to the fullscreen tour page
    TourguideNavigation.router.push(
      TourguideNavigation.tourRunningPath,
    );
  }


  @override
  Widget build(BuildContext context) {
    final tourProvider = Provider.of<TourProvider>(context);
    final tourguideUserProvider = Provider.of<TourguideUserProvider>(context);
    bool isOfflineCreatedTour = (widget.tour.isOfflineCreatedTour ?? false);

    bool showMap = widget.tour.latitude != null && widget.tour.latitude != 0 && widget.tour.longitude != null && widget.tour.longitude != 0;
    if (showMap && _currentCameraPosition.target == LatLng(0, 0)) {
      _currentCameraPosition = CameraPosition(
        target: LatLng(widget.tour.latitude, widget.tour.longitude),
        zoom: 14.0,
      );
    }

    return TourMapFullscreen(
      tour: widget.tour,
      tourMapController: _tourMapController,
      child: Scrollbar(
        thumbVisibility: true,
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: StandardLayout(
            children: [
              StandardLayoutChild(
                enableHorizontalPadding: true,
                enableVerticalPadding: false,
                child: Stack(
                  children: [
                    Container(
                      height: kIsWeb ? 300 : 200,
                      child: ClipRRect(
                        child: kIsWeb
                            ?
                        Image.network(widget.tour.imageUrl!,
                            width: MediaQuery.of(context).size.width,
                            height: 300.0,
                            fit: BoxFit.cover)
                            :
                        widget.tour.imageFile != null
                            ?
                        Image.file(widget.tour.imageFile!,
                            width: MediaQuery.of(context).size.width,
                            height: 200.0,
                            fit: BoxFit.cover)
                            : Container(
                          color: Colors.grey,
                          width: MediaQuery.of(context).size.width,
                          height: 200.0,
                        ),
                      ),
                    ),
                    if (tourProvider.isUserCreatedTour(widget.tour))
                      Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (widget.tour.reports.isNotEmpty)
                                  const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.black45,
                                    child: Icon(
                                      Icons.report_outlined,
                                      color: Colors.yellow,
                                      size: 22,),
                                  ),
                                const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.black45,
                                  child: Icon(
                                    Icons.attribution,
                                    color: Colors.white,),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
              Text(
                widget.tour.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              TourTagsRow(
                  tags: TourTag.parseTags(widget.tour.tags!)
              ),
              /*Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                              children: [
                                Container(
                                  height: kIsWeb ? 300 : 200,
                                  child: ClipRRect(
                                    child: kIsWeb
                                        ?
                                    Image.network(widget.tour.imageUrl!,
                                        width: MediaQuery.of(context).size.width,
                                        height: 300.0,
                                        fit: BoxFit.cover)
                                        :
                                    widget.tour.imageFile != null
                                        ?
                                    Image.file(widget.tour.imageFile!,
                                        width: MediaQuery.of(context).size.width,
                                        height: 200.0,
                                        fit: BoxFit.cover)
                                    : Container(
                                      color: Colors.grey,
                                      width: MediaQuery.of(context).size.width,
                                      height: 200.0,
                                    ),
                                  ),
                                ),
                                if (tourProvider.isUserCreatedTour(widget.tour))
                                  Align(
                                      alignment: Alignment.topRight,
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (widget.tour.reports.isNotEmpty)
                                              const CircleAvatar(
                                                radius: 16,
                                                backgroundColor: Colors.black45,
                                                child: Icon(
                                                  Icons.report_outlined,
                                                  color: Colors.yellow,
                                                  size: 22,),
                                              ),
                                            const CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Colors.black45,
                                              child: Icon(
                                                Icons.attribution,
                                                color: Colors.white,),
                                            ),
                                          ],
                                        ),
                                      )),
                              ],
                            ),
                          const SizedBox(height: 16.0),
                          Text(
                            widget.tour.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16.0),
                          TourTagsRow(
                              tags: TourTag.parseTags(widget.tour.tags!)
                          ),
                          const SizedBox(height: 8.0),
                        ],
                      ),*/
              TourMap(
                  tourMapController: _tourMapController,
                  tour: widget.tour,
                  height: 220,
                  heightWeb: 320,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                    'Places you\'ll visit',
                    style: Theme.of(context).textTheme.titleLarge
                ),
              ),
              if (widget.tour.tourguidePlaces.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.tour.tourguidePlaces.asMap().entries.map((entry) {
                    int index = entry.key;
                    var place = entry.value;
                    return Padding(
                      key: _targetKeys.isNotEmpty ? _targetKeys[index] : null,
                      padding: index != 0 ? const EdgeInsets.symmetric(vertical: 12.0) : const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${index+1}.  ${place.title}",
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6.0),
                          Text(
                            place.description, // Assuming each place has a 'description' field
                            style: Theme.of(context).textTheme.bodyMedium,
                            softWrap: true,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              StandardLayoutChild(
                enableHorizontalPadding: true,
                enableVerticalPadding: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.39,
                        child:
                        ElevatedButton(
                          onPressed: isOfflineCreatedTour ? null : startTour,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                          ),
                          child: Text("Start"),),
                      ),
                      TourRatingBookmarkButtons(tour: widget.tour),
                    ],
                  ),
                ),
              ),
              if (!isOfflineCreatedTour && widget.tour.createdDateTime != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'Created on ${widget.tour.createdDateTime!.toLocal().toString().split(' ')[0]} by:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) =>
                            TourguideUserProfileView(
                                tourguideUserId: widget.tour.authorId,
                                tourguideUserDisplayName: widget.tour.authorName)),
                      );
                    }, child: Text(widget.tour.authorName))
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}