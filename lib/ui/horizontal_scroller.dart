import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/tour/tour_tile.dart';
import 'package:tourguide_app/utilities/crossplatform_utils.dart';

class HorizontalScroller extends StatefulWidget {
  final List<Tour> tours;
  final bool leftPadding;

  const HorizontalScroller({
    super.key,
    required this.tours,
    this.leftPadding = true,
  });

  @override
  _HorizontalScrollerState createState() => _HorizontalScrollerState();
}

class _HorizontalScrollerState extends State<HorizontalScroller> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listView = ListView.builder(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(widget.leftPadding ? 16 : 0, 2, 16, 8),
      itemCount: widget.tours.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 16.0, 0),
          child: TourTile(tour: widget.tours[index]),
        );
      },
    );

    return SizedBox(
      height: TourTile.height,
      // On web, wrap in GestureDetector to enable drag scrolling
      child: CrossplatformUtils.isMobile()
          ? GestureDetector(
              onHorizontalDragUpdate: (details) {
                _scrollController.jumpTo(
                  _scrollController.offset - details.delta.dx,
                );
              },
              child: Scrollbar(
                controller: _scrollController,
                child: listView,
              ),
            )
          : listView,
    );
  }
}
