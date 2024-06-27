import 'package:flutter/material.dart';

class StandardLayout extends StatelessWidget {
  final List<Widget> children;
  final double gap;

  const StandardLayout({
    super.key,
    required this.children,
    this.gap = 16.0,
  });

  List<Widget> _addGaps(List<Widget> children) {
    List<Widget> spacedChildren = [];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(SizedBox(height: gap));
      }
    }
    return spacedChildren;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: _addGaps(children).map((widget) {
          if (widget is Text) {
            return Align(
              alignment: Alignment.centerLeft,
              child: widget,
            );
          }
          return Align(
            alignment: Alignment.center,
            child: widget,
          );
        }).toList(),
      ),
    );
  }
}