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
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'package:tourguide_app/utilities/services/tour_service.dart';
import 'package:tourguide_app/utilities/tourguide_navigation.dart';

import '../main.dart';

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

    return GestureDetector(
      onTap: () => widget.tour.isAddTourTile ? _createTour() : _showOverlay(context),
      child: Container(
        width: 180.0,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: widget.tour.isAddTourTile ? Border.all(color: Color(0xaa9e9e9e), width: 2.0) : Border.all(color: Colors.transparent, width: 0), // Adjust the width as needed
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
                        width: 180.0,
                        height: 100.0,
                        fit: BoxFit.cover)
                        :
                    Container(width: 180, height: 100, color: Colors.white,),
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
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                         overflow: TextOverflow.ellipsis,
                         maxLines: 3,
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

  //TODO unify behavior and UI with tour details and tour running
  void toggleThumbsUp() {
    if (widget.tour.isOfflineCreatedTour) return; // Tour creation tile should not have rating

    myAuth.AuthProvider authProvider = Provider.of(context, listen: false);

    setState(() {
      if (thisUsersRating == 1) {
        // Cancel upvote
        thisUsersRating = 0;
        widget.tour.upvotes--; // Decrease upvotes
      } else {
        // Upvote
        if (thisUsersRating == -1) {
          widget.tour.downvotes--; // Cancel downvote if any
        }
        thisUsersRating = 1;
        widget.tour.upvotes++; // Increase upvotes
      }
      TourService.addOrUpdateRating(widget.tour.id, thisUsersRating, authProvider.user!.uid);
    });
  }

  //TODO unify behavior and UI with tour details and tour running
  void toggleThumbsDown() {
    if (widget.tour.isOfflineCreatedTour) return; // Tour creation tile should not have rating

    myAuth.AuthProvider authProvider = Provider.of(context, listen: false);

    setState(() {
      if (thisUsersRating == -1) {
        // Cancel downvote
        thisUsersRating = 0;
        widget.tour.downvotes--; // Decrease downvotes
      } else {
        // Downvote
        if (thisUsersRating == 1) {
          widget.tour.upvotes--; // Cancel upvote if any
        }
        thisUsersRating = -1;
        widget.tour.downvotes++; // Increase downvotes
      }
      TourService.addOrUpdateRating(widget.tour.id, thisUsersRating, authProvider.user!.uid);
    });
  }

  //TODO unify behavior and UI with tour details and tour running
  void saveTour() {
    if (widget.tour.isOfflineCreatedTour) return; // Tour creation tile should not have rating

    TourguideUserProvider tourguideUserProvider = Provider.of(context, listen: false);

    setState(() {
      tourguideUserProvider.user!.savedTourIds.contains(widget.tour.id)
          ? tourguideUserProvider.user!.savedTourIds.remove(widget.tour.id)
          : tourguideUserProvider.user!.savedTourIds.add(widget.tour.id);
      tourguideUserProvider.updateUser(tourguideUserProvider.user!);
    });
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
    TourguideUserProvider tourguideUserProvider = Provider.of<TourguideUserProvider>(context);

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
                        backgroundColor: Theme.of(context).primaryColor, // background
                        foregroundColor: Colors.white, // foreground
                      ),
                      child: Text("Start"),),
                    SizedBox(width: 8.0),
                    ElevatedButton.icon(
                      onPressed: tourDetails,
                      label: Text("Details"),
                      icon: widget.tour.reports.isNotEmpty ? Icon(Icons.report_outlined,) : null,
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: widget.tour.isOfflineCreatedTour ? null : saveTour,
                      style: ElevatedButton.styleFrom(
                        shape: CircleBorder(),
                        padding: EdgeInsets.all(0),
                        foregroundColor:
                        tourguideUserProvider.user != null && tourguideUserProvider.user!.savedTourIds.contains(widget.tour.id) ?
                        Theme.of(context).primaryColor : Colors.grey,
                      ),
                      child: Icon(Icons.bookmark_rounded), // Replace with your desired icon
                    ),
                    Material(
                      elevation: 1,
                      color: Color(0xffeff5f3),
                      borderRadius: BorderRadius.circular(32.0),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 35,
                              height: 35,
                              child: IconButton(
                                onPressed: toggleThumbsUp,
                                icon: Icon(Icons.thumb_up, color: thisUsersRating == 1 ? Theme.of(context).primaryColor : Colors.grey),
                                iconSize: 18,
                                padding: EdgeInsets.all(0),
                                constraints: BoxConstraints(),
                              ),
                            ),
                            Text(
                                '${(widget.tour.upvotes - widget.tour.downvotes).sign == 1 ? '+' : ''}${widget.tour.upvotes - widget.tour.downvotes}',
                                style: Theme.of(context).textTheme.labelMedium,
                                overflow: TextOverflow.visible,
                                maxLines: 1,
                            ),
                            SizedBox(
                              width: 35,
                              height: 35,
                              child: IconButton(
                                onPressed: toggleThumbsDown,
                                icon: Icon(Icons.thumb_down, color: thisUsersRating == -1 ? Theme.of(context).primaryColor : Colors.grey),
                                iconSize: 18,
                                padding: EdgeInsets.all(0),
                                constraints: BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

