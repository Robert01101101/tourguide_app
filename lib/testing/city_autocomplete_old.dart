import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';

import 'package:tourguide_app/main.dart';

class CityAutocompleteOld extends StatefulWidget {
  @override
  _CityAutocompleteOldState createState() => _CityAutocompleteOldState();
}

class _CityAutocompleteOldState extends State<CityAutocompleteOld> {
  final TextEditingController _cityController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final String _sessionToken = Uuid().v4();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showOverlay() {
    print('Showing overlay');
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
    }
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context)!.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    print('Hiding overlay');
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 5.0,
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          child: Material(
            elevation: 4.0,
            child: _isLoading
                ? Container(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
                : ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_suggestions[index]),
                  onTap: () {
                    print('Selected: ${_suggestions[index]}');
                    _cityController.text = _suggestions[index];
                    _hideOverlay();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _onTextChanged(String value) async {
    print('Text changed: $value');
    if (value.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var apikey = MyGlobals.googleApiKey;
      final response = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$value&types=(cities)&key=$apikey&sessiontoken=$_sessionToken'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'];
        setState(() {
          _suggestions = List<String>.from(
              predictions.map((prediction) => prediction['description']));
          _isLoading = false;
        });
        _showOverlay();
        print('Suggestions: $_suggestions');
      } else {
        setState(() {
          _isLoading = false;
        });
        print('Failed to fetch suggestions. Status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching suggestions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _cityController,
        focusNode: _focusNode,
        decoration: const InputDecoration(
          labelText: 'City',
        ),
        onChanged: _onTextChanged,
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        title: Text('City Autocomplete Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CityAutocompleteOld(),
      ),
    ),
  ));
}
