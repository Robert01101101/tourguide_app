import 'package:flutter/material.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/tour/tour_tile.dart';

class HorizontalScroller extends StatelessWidget {
  final List<Tour> tours;
  final bool leftPadding;

  const HorizontalScroller({super.key, required this.tours, this.leftPadding = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 256,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(leftPadding ? 16 : 0, 2, 16, 8),
        itemCount: tours.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 16.0, 0),
            child: TourTile(tour: tours[index]),
          );
        },
      ),
    );
  }
}