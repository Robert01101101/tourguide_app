import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

import '../main.dart';

class PlaceAutocomplete extends StatefulWidget {
  final TextEditingController textEditingController;
  final bool isFormSubmitted;
  final Function(AutocompletePrediction) onItemSelected;
  final Function(Place?)? onPlaceInfoFetched;
  final bool restrictToCities;
  final InputDecoration? decoration;
  final bool customLabel;

  PlaceAutocomplete({
    required this.textEditingController,
    required this.isFormSubmitted,
    required this.onItemSelected,
    this.onPlaceInfoFetched,
    this.restrictToCities = true, //default true
    this.decoration,
    this.customLabel = false,
  });

  @override
  _PlaceAutocompleteState createState() => _PlaceAutocompleteState();
}

class _PlaceAutocompleteState extends State<PlaceAutocomplete> {
  // The query currently being searched for. If null, there is no pending
  // request.
  String? _currentQuery;
  // The most recent options received from the API.
  late Iterable<AutocompletePrediction> _lastOptions = <AutocompletePrediction>[];
  late final _Debounceable<Iterable<AutocompletePrediction>?, String> _debouncedSearch;
  // A network error was received on the most recent query.
  bool _networkError = false;
  bool _isValidSelection = false;

  @override
  void initState() {
    logger.i('PlaceAutocomplete.initState(), textEditingController.text=${widget.textEditingController.text}');
    super.initState();
    LocationProvider locationProvider = Provider.of<LocationProvider>(context, listen: false);
    _debouncedSearch = _debounce<Iterable<AutocompletePrediction>?, String>(
            (query) => locationProvider.getAutocompleteSuggestions(query, restrictToCities: widget.restrictToCities));
  }


  @override
  Widget build(BuildContext context) {
    LocationProvider locationProvider = Provider.of<LocationProvider>(context);
    //logger.i('PlaceAutocomplete.build()');

    return LayoutBuilder( //LayoutBuilder is needed to match the list width to text input width
      builder: (BuildContext context, BoxConstraints constraints) {
        return Autocomplete<AutocompletePrediction>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            setState(() {
              _networkError = false; //reset
              _isValidSelection = false;
            });
            final Iterable<AutocompletePrediction>? options =
            await _debouncedSearch(textEditingValue.text);
            if (options == null) {
              return _lastOptions;
            }
            _lastOptions = options;
            return options;
          },
          displayStringForOption: (AutocompletePrediction option) => option.fullText!,
          fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
            // TODO: better understand why the city field in tour creation sometimes resets to empty
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (widget.textEditingController.text.isNotEmpty && fieldTextEditingController.text.isEmpty) {
                fieldTextEditingController.text = widget.textEditingController.text;
                _isValidSelection = true;
                logger.i('Updated text in fieldTextEditingController: ${fieldTextEditingController.text}, addresses bug where city field in tour creation sometimes resets to empty');
              }
            });


            return TextFormField(
              controller: fieldTextEditingController,
              focusNode: fieldFocusNode,
              decoration: widget.decoration?.copyWith(
                labelText: widget.customLabel ? widget.decoration!.labelText : widget.restrictToCities ? 'City' : 'Place',
                errorText: _networkError ? 'Network error, please try again.' : null,
              ) ?? InputDecoration(
                labelText: widget.customLabel ? widget.decoration!.labelText : widget.restrictToCities ? 'City' : 'Place',
                errorText: _networkError ? 'Network error, please try again.' : null,
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a city';
                }
                if (!_isValidSelection) {
                  return 'Select a city from the dropdown';
                }
                return null;
              },
              onEditingComplete: () {
                if (!_isValidSelection) {
                  setState(() {});
                }
              },
              enabled: !widget.isFormSubmitted,
            );
          },
          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<AutocompletePrediction> onSelected, Iterable<AutocompletePrediction> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: Container(
                  width: constraints.maxWidth, // Match width to the text field
                  child: ListView.builder(
                    padding: EdgeInsets.all(8.0),
                    itemCount: options.length,
                    shrinkWrap: true,
                    itemBuilder: (BuildContext context, int index) {
                      final AutocompletePrediction option = options.elementAt(index);
                      return ListTile(
                        title: Text(option.fullText!),
                        onTap: () async {
                          onSelected(option);
                          widget.onItemSelected(option);
                          setState(() {
                            _isValidSelection = true;
                          });
                          if (widget.onPlaceInfoFetched != null) {
                            Place? place = await locationProvider.getLocationDetailsFromPlaceId(option.placeId!);
                            widget.onPlaceInfoFetched!(place);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (AutocompletePrediction selection) {
            widget.textEditingController.text = selection.fullText!;
            widget.textEditingController.selection = TextSelection.fromPosition(TextPosition(offset: selection.fullText!.length));
          },
        );
      },
    );
  }
}


//From https://api.flutter.dev/flutter/material/Autocomplete-class.html
const Duration debounceDuration = Duration(milliseconds: 400);



// A wrapper around Timer used for debouncing.
class _DebounceTimer {
  _DebounceTimer() {
    _timer = Timer(debounceDuration, _onComplete);
  }

  late final Timer _timer;
  final Completer<void> _completer = Completer<void>();

  void _onComplete() {
    _completer.complete();
  }

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    _completer.completeError(const _CancelException());
  }
}

// An exception indicating that the timer was canceled.
class _CancelException implements Exception {
  const _CancelException();
}

// An exception indicating that a network request has failed.
class _NetworkException implements Exception {
  const _NetworkException();
}

typedef _Debounceable<S, T> = Future<S?> Function(T parameter);

/// Returns a new function that is a debounced version of the given function.
///
/// This means that the original function will be called only after no calls
/// have been made for the given Duration.
_Debounceable<S, T> _debounce<S, T>(_Debounceable<S?, T> function) {
  _DebounceTimer? debounceTimer;

  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer();
    try {
      await debounceTimer!.future;
    } catch (error) {
      if (error is _CancelException) {
        return null;
      }
      rethrow;
    }
    return function(parameter);
  };
}