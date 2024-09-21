import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'package:tourguide_app/utilities/providers/tour_provider.dart';

import '../main.dart';
import '../model/tour.dart';
import '../utilities/providers/tourguide_user_provider.dart';
import '../utilities/services/tour_service.dart';

class TourRatingBookmarkButtons extends StatefulWidget {
  final Tour tour;

  const TourRatingBookmarkButtons({
    super.key,
    required this.tour,
  });

  @override
  State<TourRatingBookmarkButtons> createState() =>
      _TourRatingBookmarkButtonsState();
}

class _TourRatingBookmarkButtonsState extends State<TourRatingBookmarkButtons> {
  late int _thisUsersRating;

  @override
  void initState() {
    super.initState();
    //logger.i('upvotes: ${widget.tour.upvotes}, downvotes: ${widget.tour.downvotes}');
    _thisUsersRating = widget.tour.thisUsersRating ?? 0;
  }

  void toggleThumbsUp() {
    myAuth.AuthProvider authProvider = Provider.of(context, listen: false);
    if (authProvider.isAnonymous) {
      _showSignupDialog('rate tours');
      return;
    }
    if (widget.tour.isOfflineCreatedTour ?? false)
      return; // Tour creation tile should not have rating

    TourProvider tourProvider = Provider.of(context, listen: false);

    setState(() {
      if (_thisUsersRating == 1) {
        // Cancel upvote
        _thisUsersRating = 0;
        widget.tour.upvotes--; // Decrease upvotes
      } else {
        // Upvote
        if (_thisUsersRating == -1) {
          widget.tour.downvotes--; // Cancel downvote if any
        }
        _thisUsersRating = 1;
        widget.tour.upvotes++; // Increase upvotes
      }
      widget.tour.thisUsersRating = _thisUsersRating;
      tourProvider.updateTour(widget.tour, localUpdateOnly: true);
      TourService.addOrUpdateRating(
          widget.tour.id, _thisUsersRating, authProvider.user!.uid);
    });
  }

  void toggleThumbsDown() {
    myAuth.AuthProvider authProvider = Provider.of(context, listen: false);
    if (authProvider.isAnonymous) {
      _showSignupDialog('rate tours');
      return;
    }
    if (widget.tour.isOfflineCreatedTour ?? false)
      return; // Tour creation tile should not have rating

    TourProvider tourProvider = Provider.of(context, listen: false);

    setState(() {
      if (_thisUsersRating == -1) {
        // Cancel downvote
        _thisUsersRating = 0;
        widget.tour.downvotes--; // Decrease downvotes
      } else {
        // Downvote
        if (_thisUsersRating == 1) {
          widget.tour.upvotes--; // Cancel upvote if any
        }
        _thisUsersRating = -1;
        widget.tour.downvotes++; // Increase downvotes
      }
      widget.tour.thisUsersRating = _thisUsersRating;
      tourProvider.updateTour(widget.tour, localUpdateOnly: true);
      TourService.addOrUpdateRating(
          widget.tour.id, _thisUsersRating, authProvider.user!.uid);
    });
  }

  Future<void> _showSignupDialog(String action) async {
    myAuth.AuthProvider authProvider = Provider.of(context, listen: false);
    TourProvider tourProvider = Provider.of(context, listen: false);
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sign in to $action'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'You are signed in as a guest. \n\nSign in with Google to $action and access more features.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Sign In'),
              onPressed: () {
                tourProvider.resetTourProvider();
                authProvider.signOut();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void saveTour() {
    myAuth.AuthProvider authProvider = Provider.of(context, listen: false);
    TourProvider tourProvider = Provider.of(context, listen: false);
    TourguideUserProvider tourguideUserProvider = Provider.of(context, listen: false);

    if (authProvider.isAnonymous) {
      _showSignupDialog('save tours');
      return;
    }
    if (widget.tour.isOfflineCreatedTour ?? false){
      return; // Tour creation tile should not have rating
    }

    bool wasAlreadySaved = tourguideUserProvider.user!.savedTourIds.contains(widget.tour.id);
    setState(() {
      wasAlreadySaved
          ? tourguideUserProvider.user!.savedTourIds.remove(widget.tour.id)
          : tourguideUserProvider.user!.savedTourIds.add(widget.tour.id);
      tourguideUserProvider.updateUser(tourguideUserProvider.user!);
      tourProvider.userSavedTour(widget.tour.id, !wasAlreadySaved);
    });
  }

  @override
  Widget build(BuildContext context) {
    TourguideUserProvider tourguideUserProvider =
        Provider.of<TourguideUserProvider>(context);

    return Row(
      children: [
        ElevatedButton(
          onPressed:
              (widget.tour.isOfflineCreatedTour ?? false) ? null : saveTour,
          style: ElevatedButton.styleFrom(
            shape: CircleBorder(),
            padding: EdgeInsets.all(0),
            foregroundColor: tourguideUserProvider.user != null &&
                    tourguideUserProvider.user!.savedTourIds
                        .contains(widget.tour.id)
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          ),
          child: Icon(Icons.bookmark_rounded), // Replace with your desired icon
        ),
        Material(
          elevation: 1,
          color: Theme.of(context).colorScheme.surfaceContainer,
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
                    icon: Icon(Icons.thumb_up,
                        color: (widget.tour.thisUsersRating ?? 0) == 1
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey),
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
                    icon: Icon(Icons.thumb_down,
                        color: (widget.tour.thisUsersRating ?? 0) == -1
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey),
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
    );
  }
}
