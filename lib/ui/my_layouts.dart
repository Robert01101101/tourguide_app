import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class StandardLayout extends StatelessWidget {
  static const double defaultGap = 16.0;

  final List<Widget> children;
  final double gap;
  final bool enableVerticalPadding;
  final bool enableHorizontalPadding;

  const StandardLayout({
    Key? key,
    required this.children,
    this.gap = defaultGap,
    this.enableVerticalPadding = true,
    this.enableHorizontalPadding = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    EdgeInsets insets = EdgeInsets.symmetric(vertical: enableVerticalPadding ? 8.0 : 0, horizontal: enableHorizontalPadding ? 16 : 0);

    return Padding(
      padding: kIsWeb && MediaQuery.of(context).size.width > 1280 ? EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width/5) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.map((widget) {
          if (widget is StandardLayoutChild) {
            return widget;
          } else {
            return Padding(
              padding: insets,
              child: widget,
            );
          }
        }).toList(),
      ),
    );
  }
}

//to allow setting some items to full width
class StandardLayoutChild extends StatelessWidget {
  final Widget child;
  final bool fullWidth;
  final bool enableHorizontalPadding;
  final bool enableVerticalPadding;

  const StandardLayoutChild({
    super.key,
    required this.child,
    this.fullWidth = false,
    this.enableHorizontalPadding = false,
    this.enableVerticalPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: enableVerticalPadding ? 8 : 0, horizontal: enableHorizontalPadding ? 16 : 0),
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