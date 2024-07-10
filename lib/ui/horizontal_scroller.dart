import 'package:flutter/material.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/tour/rounded_tile.dart';

class HorizontalScroller extends StatelessWidget {
  final List<Tour> tours;

  const HorizontalScroller({super.key, required this.tours});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      itemCount: tours.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 16.0, 0),
          child: RoundedTile(tour: tours[index]),
        );
      },
    );
  }
}