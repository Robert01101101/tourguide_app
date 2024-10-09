import 'dart:math';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/tour/tour_creation.dart';
import 'package:tourguide_app/tour/tour_details.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/tour/tour_tag.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/tourguide_navigation.dart';
import 'tour_rating_bookmark_buttons.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;

class TourTile extends StatefulWidget {
  static const double height = 300.0;
  static const double width = 230.0;
  final Tour tour;

  const TourTile({super.key, required this.tour});

  @override
  State<TourTile> createState() => _TourTileState();
}

class _TourTileState extends State<TourTile> {
  @override
  void initState() {
    super.initState();
  }

  void _showOverlay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      clipBehavior: Clip.antiAlias,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (BuildContext context) {
        // Adjust the height based on screen size
        final double screenHeightPortion =
            MediaQuery.of(context).size.height * 0.4;
        final double desiredHeight = max(540, screenHeightPortion);

        return Container(
          width: MediaQuery.of(context).size.width, // Full width
          height: desiredHeight,
          padding: EdgeInsets.zero,
          child: ExpandedTourTileOverlay(tour: widget.tour),
        );
      },
    );
  }

  void _createTour() {
    myAuth.AuthProvider authProvider = Provider.of(context, listen: false);
    if (authProvider.isAnonymous) {
      _showSignupDialog('create tours');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateEditTour()),
    );
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

  @override
  Widget build(BuildContext context) {
    bool textDataReady = widget.tour.name != null && widget.tour.name != "";
    TourProvider tourProvider = Provider.of<TourProvider>(context);
    bool isLoadingImage = widget.tour.imageFile == null && !kIsWeb;
    bool isOfflineCreatedTour = widget.tour.isOfflineCreatedTour ?? false;
    bool isAddTourTile = widget.tour.isAddTourTile ?? false;

    //logger.t("TourTile: ${widget.tour.name} ${widget.tour.id}, imageUrl: ${widget.tour.imageUrl}, kIsWeb: $kIsWeb, imageFile: ${widget.tour.imageFile}");

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: TourTile.width,
        child: Card(
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            splashColor: Theme.of(context).colorScheme.primary.withAlpha(10),
            onTap: () => isAddTourTile ? _createTour() : _showOverlay(context),
            child: isAddTourTile
                ? Center(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_outline_sharp,
                              color: Colors.grey),
                          const SizedBox(height: 16),
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
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12.0)),
                        child: Stack(
                          children: [
                            ShimmerLoading(
                              isLoading:
                                  isOfflineCreatedTour ? false : isLoadingImage,
                              child: kIsWeb
                                  ? Stack(
                                      children: [
                                        isOfflineCreatedTour &&
                                                widget.tour
                                                        .imageFileToUploadWeb !=
                                                    null
                                            ? Image.network(
                                                widget.tour
                                                    .imageFileToUploadWeb!.path,
                                                width: TourTile.width,
                                                height: 0.55 *
                                                    TourTile.width.ceil(),
                                                fit: BoxFit.cover)
                                            : Image.network(
                                                widget.tour.imageUrl!,
                                                width: TourTile.width,
                                                height: 0.55 *
                                                    TourTile.width.ceil(),
                                                fit: BoxFit.cover),
                                        Container(
                                          width: TourTile.width,
                                          height: 0.55 * TourTile.width.ceil(),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.black.withOpacity(0.02),
                                                Colors.black.withOpacity(0.1),
                                              ],
                                            ),
                                          ),
                                        )
                                      ],
                                    )
                                  : widget.tour.imageFile != null
                                      ? Stack(
                                          children: [
                                            Image.file(widget.tour.imageFile!,
                                                width: TourTile.width,
                                                height: 0.55 *
                                                    TourTile.width.ceil(),
                                                fit: BoxFit.cover),
                                            Container(
                                              width: TourTile.width,
                                              height:
                                                  0.55 * TourTile.width.ceil(),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.black
                                                        .withOpacity(0.02),
                                                    Colors.black
                                                        .withOpacity(0.1),
                                                  ],
                                                ),
                                              ),
                                            )
                                          ],
                                        )
                                      : Container(
                                          width: TourTile.width,
                                          height: 0.55 * TourTile.width.ceil(),
                                          color: Colors.white,
                                        ),
                            ),
                            if (tourProvider.isUserCreatedTour(widget.tour))
                              Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
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
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 8.0, right: 8, top: 5, bottom: 4),
                        child: ShimmerLoading(
                          isLoading: !textDataReady,
                          child: textDataReady
                              ? Text(
                                  "${widget.tour.name}\n", //trick to get min 2 lines in combo with maxLines:2
                                  style: Theme.of(context).textTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                )
                              : Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Container(
                                    width: 140,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                          10), // Adjust the value to your preference
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Container(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 8, right: 8, bottom: 2),
                          child: ShimmerLoading(
                            isLoading: !textDataReady,
                            child: textDataReady
                                ? Container(
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        widget.tour.description,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 4,
                                      ),
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2.0),
                                    child: Container(
                                      width: 100,
                                      height: 23,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                            10), // Adjust the value to your preference
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 8, top: 6, right: 8, bottom: 10),
                        child: TourTagsAndRatingRow(
                          tags: TourTag.parseTags(widget.tour.tags!,
                              shorten: true),
                          rating: (widget.tour.upvotes - widget.tour.downvotes),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class ExpandedTourTileOverlay extends StatefulWidget {
  final Tour tour;

  const ExpandedTourTileOverlay({super.key, required this.tour});

  @override
  _ExpandedTourTileOverlayState createState() =>
      _ExpandedTourTileOverlayState();
}

class _ExpandedTourTileOverlayState extends State<ExpandedTourTileOverlay> {
  int thisUsersRating = 0;

  @override
  void initState() {
    thisUsersRating = widget.tour.thisUsersRating ?? 0;
    super.initState();
    FirebaseAnalytics.instance
        .logSelectContent(contentType: 'tour_tile', itemId: widget.tour.id);
  }

  //TODO unify behavior and UI with tour details
  void startTour() {
    TourProvider tourProvider =
        Provider.of<TourProvider>(context, listen: false);
    tourProvider.selectTourById(widget.tour.id);
    // Navigate to the fullscreen tour page
    TourguideNavigation.router.push(
      TourguideNavigation.tourRunningPath,
    );
  }

  void tourDetails() {
    TourProvider tourProvider =
        Provider.of<TourProvider>(context, listen: false);
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
    bool isOfflineCreatedTour = widget.tour.isOfflineCreatedTour ?? false;

    double imageHeight = MediaQuery.of(context).size.height < 700
        ? MediaQuery.of(context).size.height / 3.5
        : 200;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SelectionArea(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.fromLTRB(16, 0, 0, 0),
                        child: Text(
                          widget.tour.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall!
                              .copyWith(
                                overflow: TextOverflow.ellipsis,
                              ),
                          maxLines: 2,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 16,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16, top: 12, right: 16, bottom: 8),
                      child: Stack(
                        children: [
                          kIsWeb
                              ? isOfflineCreatedTour &&
                                      widget.tour.imageFileToUploadWeb != null
                                  ? Image.network(
                                      widget.tour.imageFileToUploadWeb!.path,
                                      width: MediaQuery.of(context).size.width,
                                      height: imageHeight,
                                      fit: BoxFit.cover)
                                  : Image.network(widget.tour.imageUrl!,
                                      width: MediaQuery.of(context).size.width,
                                      height: imageHeight,
                                      fit: BoxFit.cover)
                              : widget.tour.imageFile != null
                                  ? Image.file(widget.tour.imageFile!,
                                      width: MediaQuery.of(context).size.width,
                                      height: imageHeight,
                                      fit: BoxFit.cover)
                                  : Container(
                                      width: MediaQuery.of(context).size.width,
                                      height: imageHeight,
                                      color: Colors.white,
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
                    StandardLayout(
                      disableAdaptiveHorizontalPadding: true,
                      children: [
                        Text(
                          widget.tour.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TourTagsRow(tags: TourTag.parseTags(widget.tour.tags!)),
                      ],
                    ),
                  ],
                ),
              ],
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
                      onPressed: isOfflineCreatedTour ? null : startTour,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                      ),
                      child: const Text("Start"),
                    ),
                    const SizedBox(width: 8.0),
                    ElevatedButton.icon(
                      onPressed: tourDetails,
                      label: const Text("Details"),
                      icon: widget.tour.reports.isNotEmpty
                          ? const Icon(
                              Icons.report_outlined,
                            )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainer,
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
