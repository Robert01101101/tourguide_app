import 'package:flutter/material.dart';

class Tag extends StatelessWidget {
  final String label;
  bool leftPadding;

  Tag({required this.label, this.leftPadding = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding ? 3 : 0),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ),
      ),
    );
  }
}

class TagsRow extends StatelessWidget {
  final List<String> tags;

  TagsRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double availableWidth = constraints.maxWidth;
        double usedWidth = 0;
        bool leftPadding = false;
        List<Widget> visibleTags = [];

        for (String tag in tags) {
          // Measure the width of the tag's text
          final TextPainter textPainter = TextPainter(
            text: TextSpan(
              text: tag,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout();

          double tagWidth = textPainter.width + 12 + (leftPadding ? 3 : 0); // Add padding and container's padding

          if (usedWidth + tagWidth <= availableWidth) {
            usedWidth += tagWidth;
            visibleTags.add(Tag(label: tag, leftPadding: leftPadding));
            leftPadding = true;
          } else {
            break; // Stop adding tags if they overflow
          }
        }

        return Row(
          children: visibleTags,
        );
      },
    );
  }
}