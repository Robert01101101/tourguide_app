import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/tour/tour_details.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';

import '../main.dart';

class TileData {
  final String tourId;
  final String imageUrl;
  final String title;
  final String description;

  TileData({required this.tourId, required this.imageUrl, required this.title, required this.description});
}

class RoundedTile extends StatefulWidget {
  final TileData tile;

  const RoundedTile({super.key, required this.tile});

  @override
  _RoundedTileState createState() => _RoundedTileState();
}

class _RoundedTileState extends State<RoundedTile> {
  late String imageUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    imageUrl = widget.tile.imageUrl;
  }

  @override
  void didUpdateWidget(covariant RoundedTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tile.imageUrl != widget.tile.imageUrl) {
      setState(() {
        bool imageUrlReady = imageUrl == null || imageUrl == "";
        imageUrl = widget.tile.imageUrl;
        if (imageUrlReady) _loadImage();
      });
    }
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
          child: ExpandedTileOverlay(tile: widget.tile),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool textDataReady = widget.tile.title != null && widget.tile.title != "";

    return GestureDetector(
      onTap: () => _showOverlay(context),
      child: Container(
        width: 150.0,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4.0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
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
                      imageUrl,
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
                  widget.tile.title,
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
                  widget.tile.description,
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
  final TileData tile;

  const ExpandedTileOverlay({Key? key, required this.tile}) : super(key: key);

  @override
  _ExpandedTileOverlayState createState() => _ExpandedTileOverlayState();
}

class _ExpandedTileOverlayState extends State<ExpandedTileOverlay> {
  int thumbsUpCount = 0;
  int thumbsDownCount = 0;

  void incrementThumbsUp() {
    setState(() {
      thumbsUpCount++;
    });
  }

  void incrementThumbsDown() {
    setState(() {
      thumbsDownCount++;
    });
  }

  void tourDetails() {
    TourProvider tourProvider = Provider.of<TourProvider>(context, listen: false);
    tourProvider.selectTourById(widget.tile.tourId);
    // Navigate to the fullscreen tour page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenTourPage(tile: widget.tile),
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
                  widget.tile.title,
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
                    if (widget.tile.imageUrl != null && widget.tile.imageUrl.isNotEmpty)
                      Image.network(
                        widget.tile.imageUrl,
                        width: MediaQuery.of(context).size.width,
                        height: 200.0,
                        fit: BoxFit.cover,
                      ),
                    SizedBox(height: 16.0),
                    Text(
                      widget.tile.description,
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
                            onPressed: incrementThumbsUp,
                            icon: Icon(Icons.thumb_up),
                            iconSize: 18,
                            padding: EdgeInsets.all(6),
                            constraints: BoxConstraints(),
                          ),
                        ),
                        Text(thumbsUpCount.toString(), style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                    SizedBox(width: 2),
                    Column(
                      children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: IconButton(
                            onPressed: incrementThumbsDown,
                            icon: Icon(Icons.thumb_down),
                            iconSize: 18,
                            padding: EdgeInsets.all(6),
                            constraints: BoxConstraints(),
                          ),
                        ),
                        Text(thumbsDownCount.toString(), style: Theme.of(context).textTheme.labelSmall),
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

