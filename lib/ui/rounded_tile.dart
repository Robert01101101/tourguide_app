import 'package:flutter/material.dart';
import 'package:tourguide_app/ui/horizontal_scroller.dart';
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
        imageUrl = widget.tile.imageUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLoading = imageUrl == null || imageUrl == "";

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
                  Container(width: 150, height: 100, color: Colors.red,),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              widget.tile.title,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              widget.tile.description,
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}