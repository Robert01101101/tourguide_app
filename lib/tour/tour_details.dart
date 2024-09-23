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
import 'package:tourguide_app/tour/tour_map.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'tour_rating_bookmark_buttons.dart';
import '../utilities/custom_import.dart';
import '../utilities/providers/tourguide_user_provider.dart';
import '../utilities/services/tts_service.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart'
    as my_auth;

class FullscreenTourPage extends StatefulWidget {
  final Tour tour;

  const FullscreenTourPage({super.key, required this.tour});

  @override
  State<FullscreenTourPage> createState() => _FullscreenTourPageState();
}

class _FullscreenTourPageState extends State<FullscreenTourPage> {
  final TourMapController _tourMapController = TourMapController();
  final TtsService _ttsService = TtsService();
  final ScrollController _scrollController = ScrollController();
  int thisUsersRating = 0;

  @override
  void initState() {
    thisUsersRating = widget.tour.thisUsersRating ?? 0;
    super.initState();

    my_auth.AuthProvider authProvider = Provider.of(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tourMapController.initTourMapController(
        tour: widget.tour,
        onInfoTapped: (int step) {
          logger.t('Step $step tapped');
          //_setStep(step);
        },
        showOptionsDialog: (BuildContext context) {
          _showOptionsDialog(context);
        },
        idToken: authProvider.user!.uid,
      );
    });
  }

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
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
                      tour: widget.tour.copyWith(isOfflineCreatedTour: true))),
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

  //TODO unify behavior and UI with tour tile
  void startTour() {
    TourProvider tourProvider =
        Provider.of<TourProvider>(context, listen: false);
    tourProvider.selectTourById(widget.tour.id);
    // Navigate to the fullscreen tour page
    TourguideNavigation.router.push(
      TourguideNavigation.tourRunningPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tourProvider = Provider.of<TourProvider>(context);

    bool isOfflineCreatedTour = (widget.tour.isOfflineCreatedTour ?? false);

    return TourMapFullscreen(
      tour: widget.tour,
      tourMapController: _tourMapController,
      alwaysShowAppBar: true,
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
                            ? Image.network(widget.tour.imageUrl!,
                                width: MediaQuery.of(context).size.width,
                                height: 300.0,
                                fit: BoxFit.cover)
                            : widget.tour.imageFile != null
                                ? Image.file(widget.tour.imageFile!,
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
                                      size: 22,
                                    ),
                                  ),
                                const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.black45,
                                  child: Icon(
                                    Icons.attribution,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
              SelectionArea(
                child: Column(
                  children: [
                    Text(
                      widget.tour.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: StandardLayout.defaultGap),
                    TourTagsRow(tags: TourTag.parseTags(widget.tour.tags!)),
                  ],
                ),
              ),
              TourMap(
                tourMapController: _tourMapController,
                tour: widget.tour,
                height: 220,
                heightWeb: 320,
              ),
              if (widget.tour.tourguidePlaces.isNotEmpty)
                SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text('Places you\'ll visit',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      const SizedBox(height: StandardLayout.defaultGap),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.tour.tourguidePlaces
                            .asMap()
                            .entries
                            .map((entry) {
                          int index = entry.key;
                          var place = entry.value;
                          return Padding(
                            padding: index != 0
                                ? const EdgeInsets.symmetric(vertical: 12.0)
                                : const EdgeInsets.only(bottom: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${index + 1}.  ${place.title}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  maxLines: 2,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  place
                                      .description, // Assuming each place has a 'description' field
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .copyWith(
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              StandardLayoutChild(
                enableHorizontalPadding: true,
                enableVerticalPadding: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.39,
                        child: ElevatedButton(
                          onPressed: isOfflineCreatedTour ? null : startTour,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                          ),
                          child: const Text("Start"),
                        ),
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
                    TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TourguideUserProfileView(
                                    tourguideUserId: widget.tour.authorId,
                                    tourguideUserDisplayName:
                                        widget.tour.authorName)),
                          );
                        },
                        child: Text(widget.tour.authorName))
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
