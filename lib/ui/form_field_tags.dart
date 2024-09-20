import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class FormFieldTags<T> extends FormField<Map<String, dynamic>> {
  final bool enabled;

  FormFieldTags({
    super.key,
    super.validator,
    Widget? hintText,
    required this.enabled,
    Map<String, dynamic>? initialValue,
  }) : super(
          initialValue: initialValue,
          builder: (state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormFieldTagsContent(
                  enabled: enabled,
                  onChanged: (selectedValues) {
                    state.didChange(selectedValues); // Update form field state
                  },
                  initialValue: state.value,
                ),
                if (state.hasError)
                  Text(state.errorText ?? "",
                      style: Theme.of(state.context)
                          .textTheme
                          .labelMedium!
                          .copyWith(
                              color:
                                  Theme.of(state.context).colorScheme.error)),
              ],
            );
          },
        );
}

class _FormFieldTagsContent extends StatefulWidget {
  //final FormFieldState<T> state;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;
  final Map<String, dynamic>? initialValue;
  //final bool isSelected;

  const _FormFieldTagsContent({
    super.key,
    //required this.initialValue,
    //required this.state,
    required this.onChanged,
    required this.enabled,
    //this.isSelected = false,
    this.initialValue,
  });

  @override
  _FormFieldTagsContentState createState() => _FormFieldTagsContentState();
}

class _FormFieldTagsContentState extends State<_FormFieldTagsContent> {
  String? _duration;
  List<String> _descriptiveTags = [];
  final List<String> _durationPresets = [
    '1h',
    '3h',
    '6h',
    '1 day',
    '2 days',
    '3 days'
  ];
  final List<String> _descriptiveTagsPresets = [
    'Scenic',
    'Historic',
    'Urban',
    'Cultural',
    'Natural',
    'Sporty',
    'Relaxing',
    'Educational',
    'Family',
    'Romantic',
    'Adventurous',
    'Foodie',
    'Shopping',
    'Nightlife',
    'Festive',
    'Seasonal',
    'Budget',
    'Pet-friendly',
    'Eco-friendly',
    'Sustainable',
    'LGBTQ+'
  ];

  @override
  void initState() {
    super.initState();

    // Initialize _duration and _descriptiveTags from widget.initialValue
    if (widget.initialValue != null) {
      _duration = widget.initialValue?['duration'] as String?;
      _descriptiveTags = List<String>.from(widget.initialValue?['descriptive'] ?? []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Duration',
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: List<Widget>.generate(_durationPresets.length, (index) {
              return ChoiceChip(
                label: Text(_durationPresets[index]),
                selected: _duration == _durationPresets[index],
                onSelected: (bool selected) {
                  setState(() {
                    _duration = selected ? _durationPresets[index] : null;
                  });
                  widget.onChanged({
                    'duration': _duration,
                    'descriptive': _descriptiveTags,
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            'Descriptive Tags (${_descriptiveTags.length}/5)',
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing:
                kIsWeb && MediaQuery.of(context).size.width > 1280 ? 8 : 0,
            children:
                List<Widget>.generate(_descriptiveTagsPresets.length, (index) {
              String descriptiveTag = _descriptiveTagsPresets[index];
              return FilterChip(
                label: Text(descriptiveTag),
                selected: _descriptiveTags.contains(descriptiveTag),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      if (_descriptiveTags.length < 5)
                        _descriptiveTags.add(descriptiveTag);
                    } else {
                      _descriptiveTags.remove(descriptiveTag);
                    }
                  });
                  widget.onChanged({
                    'duration': _duration,
                    'descriptive': _descriptiveTags,
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
