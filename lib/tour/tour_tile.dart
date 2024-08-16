import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/model/tourguide_user.dart';
import 'package:tourguide_app/tour/tour_creation.dart';
import 'package:tourguide_app/tour/tour_details.dart';
import 'package:tourguide_app/tour/tour_running.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'package:tourguide_app/utilities/services/tour_service.dart';
import 'package:tourguide_app/utilities/tourguide_navigation.dart';

import '../main.dart';
import '../ui/tour_rating_bookmark_buttons.dart';

class TourTile extends StatefulWidget {
  final Tour tour;

  const TourTile({super.key, required this.tour});

  @override
  _TourTileState createState() => _TourTileState();
}

class _TourTileState extends State<TourTile> {

  @override
  void initState() {
    super.initState();
  }


  void _showOverlay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.0)),
      ),
      builder: (BuildContext context) {
        // Adjust the height based on screen size
        final double screenHeight = MediaQuery.of(context).size.height;
        final double desiredHeight = screenHeight * 0.6;

        return Container(
          width: MediaQuery.of(context).size.width, // Full width
          height: desiredHeight,
          padding: EdgeInsets.all(8.0),
          child: ExpandedTourTileOverlay(tour: widget.tour),
        );
      },
    );
  }

  void _createTour(){
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateEditTour()),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool textDataReady = widget.tour.name != null && widget.tour.name != "";
    TourProvider tourProvider = Provider.of<TourProvider>(context);
    bool isLoadingImage = widget.tour.imageFile == null;
    double tileWidth = 210;

    return GestureDetector(
      onTap: () => widget.tour.isAddTourTile ? _createTour() : _showOverlay(context),
      child: Container(
        width: tileWidth,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4.0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: widget.tour.isAddTourTile
          ? Center(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_sharp, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      "Add Tour",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            )
          : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
              child: Stack(
                children: [
                  ShimmerLoading(
                    isLoading: widget.tour.isOfflineCreatedTour ? false : isLoadingImage,
                    child: widget.tour.imageFile != null
                        ?
                    Image.file(widget.tour.imageFile!,
                        width: tileWidth,
                        height: 0.55*tileWidth.ceil(),
                        fit: BoxFit.cover)
                        :
                    Container(width: tileWidth, height: 0.55*tileWidth.ceil(), color: Colors.white,),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5),
              child: ShimmerLoading(
                isLoading: !textDataReady,
                child: textDataReady ?
                Text(
                  widget.tour.name + "\n", //trick to get min 2 lines in combo with maxLines:2
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ) :
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Container(width: 140, height: 30,  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10), // Adjust the value to your preference
                  ),),
                ),
              ),
            ),
            Container(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
                child: ShimmerLoading(
                  isLoading: !textDataReady,
                  child: textDataReady ?
                   Container(
                     child: Align(
                       alignment: Alignment.topLeft,
                       child: Text(
                        widget.tour.description,
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                         overflow: TextOverflow.ellipsis,
                         maxLines: 4,
                       ),
                     ),
                   ) :
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Container(width: 100, height: 23,  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10), // Adjust the value to your preference
                    ),),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ExpandedTourTileOverlay extends StatefulWidget {
  final Tour tour;

  const ExpandedTourTileOverlay({Key? key, required this.tour}) : super(key: key);

  @override
  _ExpandedTourTileOverlayState createState() => _ExpandedTourTileOverlayState();
}

class _ExpandedTourTileOverlayState extends State<ExpandedTourTileOverlay> {
  int thisUsersRating = 0;

  @override
  void initState() {
    thisUsersRating = widget.tour.thisUsersRating ?? 0;
    super.initState();
    FirebaseAnalytics.instance.logSelectContent(contentType: 'tour_tile', itemId: widget.tour.id);
  }



  //TODO unify behavior and UI with tour details
  void startTour() {
    TourProvider tourProvider = Provider.of<TourProvider>(context, listen: false);
    tourProvider.selectTourById(widget.tour.id);
    // Navigate to the fullscreen tour page
    TourguideNavigation.router.push(
      TourguideNavigation.tourRunningPath,
    );
  }

  void tourDetails() {
    TourProvider tourProvider = Provider.of<TourProvider>(context, listen: false);
    tourProvider.selectTourById(widget.tour.id);
    // Navigate to the fullscreen tour page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenTourPage(tour: widget.tour),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    TourProvider tourProvider = Provider.of<TourProvider>(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 0, 0, 0),
                  child: Text(
                    widget.tour.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        widget.tour.imageFile != null  //add null safety for img to upload
                            ?
                        Image.file(widget.tour.imageFile!,
                            width: MediaQuery.of(context).size.width,
                            height: 200.0,
                            fit: BoxFit.cover)
                            :
                        Container(width: MediaQuery.of(context).size.width, height: 200, color: Colors.white,),
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
                    SizedBox(height: 16.0),
                    Text(
                      widget.tour.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: widget.tour.isOfflineCreatedTour ? null : startTour,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      ),
                      child: Text("Start"),),
                    SizedBox(width: 8.0),
                    ElevatedButton.icon(
                      onPressed: tourDetails,
                      label: Text("Details"),
                      icon: widget.tour.reports.isNotEmpty ? Icon(Icons.report_outlined,) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TourRatingBookmarkButtons(tour: widget.tour),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

