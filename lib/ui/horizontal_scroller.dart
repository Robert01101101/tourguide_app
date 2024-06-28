import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

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



class RoundedTile extends StatelessWidget {
  final TileData tile;

  const RoundedTile({super.key, required this.tile});

  @override
  Widget build(BuildContext context) {
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
            child: Image.network(
              tile.imageUrl,
              width: 150.0,
              height: 100.0,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              tile.title,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              tile.description,
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