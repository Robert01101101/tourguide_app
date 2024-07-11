import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/tour/tour_creation.dart';
import 'package:tourguide_app/tour/tour_details.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;

import '../main.dart';

class RoundedTile extends StatefulWidget {
  final Tour tour;

  const RoundedTile({super.key, required this.tour});

  @override
  _RoundedTileState createState() => _RoundedTileState();
}

class _RoundedTileState extends State<RoundedTile> {
  late String imageUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    imageUrl = widget.tour.imageUrl;
    startImageLoad();
  }

  @override
  void didUpdateWidget(covariant RoundedTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tour.imageUrl != widget.tour.imageUrl || (imageUrl != null && imageUrl != "")) {
      setState(() {
        startImageLoad();
      });
    }
  }

  void startImageLoad(){
    imageUrl = widget.tour.imageUrl;
    bool imageUrlReady = imageUrl != null && imageUrl != "";
    if (imageUrlReady) _loadImage();
  }

  Future<void> _loadImage() async {
    final ImageStream imageStream = NetworkImage(imageUrl).resolve(ImageConfiguration.empty);
    final ImageStreamListener listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }, onError: (dynamic exception, StackTrace? stackTrace) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
    imageStream.addListener(listener);
  }

  void _showOverlay(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.0)),
      ),
      builder: (BuildContext context) {
        // Adjust the height based on screen size
        final double screenHeight = MediaQuery.of(context).size.height;
        final double desiredHeight = screenHeight * 11 / 20;

        return Container(
          width: MediaQuery.of(context).size.width, // Full width
          height: desiredHeight,
          padding: EdgeInsets.all(8.0),
          child: ExpandedTileOverlay(tour: widget.tour),
        );
      },
    );
  }

  void _createTour(){
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTour()),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool textDataReady = widget.tour.name != null && widget.tour.name != "";

    return GestureDetector(
      onTap: () => widget.tour.isAddTourTile ? _createTour() : _showOverlay(context),
      child: Container(
        width: 150.0,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          border: widget.tour.isAddTourTile ? Border.all(color: Colors.grey, width: 2.0) : Border.all(color: Colors.transparent, width: 0), // Adjust the width as needed
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
                    isLoading: isLoading,
                    child: !isLoading ?
                    Image.network(
                      widget.tour.imageUrl,
                      width: 150.0,
                      height: 100.0,
                      fit: BoxFit.cover,
                    ) :
                    Container(width: 150, height: 100, color: Colors.white,),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ShimmerLoading(
                isLoading: !textDataReady,
                child: textDataReady ?
                Text(
                  widget.tour.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ) :
                Container(width: 100, height: 23,  decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10), // Adjust the value to your preference
                ),),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ShimmerLoading(
                isLoading: !textDataReady,
                child: textDataReady ?
                 Text(
                  widget.tour.description,
                   style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                   overflow: TextOverflow.ellipsis,
                   maxLines: 2,
                ) :
                Container(width: 100, height: 23,  decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10), // Adjust the value to your preference
                ),),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ExpandedTileOverlay extends StatefulWidget {
  final Tour tour;

  const ExpandedTileOverlay({Key? key, required this.tour}) : super(key: key);

  @override
  _ExpandedTileOverlayState createState() => _ExpandedTileOverlayState();
}

class _ExpandedTileOverlayState extends State<ExpandedTileOverlay> {
  int thisUsersRating = 0;

  @override
  void initState() {
    thisUsersRating = widget.tour.thisUsersRating ?? 0;
    super.initState();
  }

  void toggleThumbsUp() {
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
      TourService.addOrUpdateRating(widget.tour.id, thisUsersRating, authProvider.user!.id);
    });
  }

  void toggleThumbsDown() {
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
      TourService.addOrUpdateRating(widget.tour.id, thisUsersRating, authProvider.user!.id);
    });
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(16, 0, 0, 0),
                child: Text(
                  widget.tour.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
                    if (widget.tour.imageUrl != null && widget.tour.imageUrl.isNotEmpty)
                      Image.network(
                        widget.tour.imageUrl,
                        width: MediaQuery.of(context).size.width,
                        height: 200.0,
                        fit: BoxFit.cover,
                      ),
                    SizedBox(height: 16.0),
                    Text(
                      widget.tour.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(height: 16.0),
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
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor, // background
                        foregroundColor: Colors.white, // foreground
                      ),
                      child: Text("Start Tour"),),
                    SizedBox(width: 8.0),
                    ElevatedButton(onPressed: tourDetails, child: Text("Tour Details")),
                  ],
                ),
                Row(
                  children: [
                    Column(
                      children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: IconButton(
                            onPressed: toggleThumbsUp,
                            icon: Icon(Icons.thumb_up, color: thisUsersRating == 1 ? Theme.of(context).primaryColor : Colors.grey),
                            iconSize: 18,
                            padding: EdgeInsets.all(6),
                            constraints: BoxConstraints(),
                          ),
                        ),
                        Text(widget.tour.upvotes.toString(), style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                    SizedBox(width: 2),
                    Column(
                      children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: IconButton(
                            onPressed: toggleThumbsDown,
                            icon: Icon(Icons.thumb_down, color: thisUsersRating == -1 ? Theme.of(context).primaryColor : Colors.grey),
                            iconSize: 18,
                            padding: EdgeInsets.all(6),
                            constraints: BoxConstraints(),
                          ),
                        ),
                        Text(widget.tour.downvotes.toString(), style: Theme.of(context).textTheme.labelSmall),
                      ],
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
