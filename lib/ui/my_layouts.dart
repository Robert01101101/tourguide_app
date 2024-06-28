import 'package:flutter/material.dart';

class StandardLayout extends StatelessWidget {
  final List<Widget> children;
  final double gap;

  const StandardLayout({
    Key? key,
    required this.children,
    this.gap = 16.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((widget) {
        if (widget is StandardLayoutChild) {
          return widget;
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
            child: widget,
          );
        }
      }).toList(),
    );
  }
}

//to allow setting some items to full width
class StandardLayoutChild extends StatelessWidget {
  final Widget child;
  final bool fullWidth;

  const StandardLayoutChild({
    Key? key,
    required this.child,
    this.fullWidth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: fullWidth
          ? SizedBox(
        width: double.infinity,
        child: child,
      )
          : Align(
        alignment:
        child is Text ? Alignment.centerLeft : Alignment.center,
        child: child,
      ),
    );
  }
}