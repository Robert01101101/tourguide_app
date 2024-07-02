import 'package:flutter/material.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';

class TileData {
  final String imageUrl;
  final String title;
  final String description;

  TileData({required this.imageUrl, required this.title, required this.description});
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

  @override
  Widget build(BuildContext context) {
    bool textDataReady = widget.tile.title != null && widget.tile.title != "";

    return Container(
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
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
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
                style: TextStyle(
                  fontSize: 12.0,
                  color: Colors.grey[600],
                ),
              ) :
              Container(width: 100, height: 23,  decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10), // Adjust the value to your preference
              ),),
            ),
          ),
        ],
      ),
    );
  }
}