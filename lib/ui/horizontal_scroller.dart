import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:tourguide_app/main.dart';
import 'package:tourguide_app/ui/rounded_tile.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';

class TileData {
  final String imageUrl;
  final String title;
  final String description;

  TileData({
    required this.imageUrl,
    required this.title,
    required this.description,
  });
}


class HorizontalScroller extends StatelessWidget {
  final List<TileData> tiles;

  HorizontalScroller({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      itemCount: tiles.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(0,0,16.0,0),
          child: RoundedTile(tile: tiles[index]),
        );
      },
    );
  }
}
