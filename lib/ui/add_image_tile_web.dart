import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as html;

import '../main.dart';  // Conditional import

class AddImageTileWeb extends FormField<XFile?> {  // Use XFile instead of File
  final bool enabled;

  AddImageTileWeb({
    Key? key,
    XFile? initialValue,  // Change initialValue type to XFile
    FormFieldSetter<XFile?>? onSaved,
    FormFieldValidator<XFile?>? validator,
    ValueChanged<XFile?>? onChanged,
    required this.enabled,
  }) : super(
    key: key,
    initialValue: initialValue,
    onSaved: onSaved,
    validator: validator,
    builder: (FormFieldState<XFile?> state) {
      return _AddImageTileWebContent(
        initialValue: initialValue,
        state: state,
        onChanged: onChanged != null
            ? (XFile? file) {
          state.didChange(file);
          onChanged(file);
        }
            : state.didChange,
        enabled: enabled,
      );
    },
  );
}

class _AddImageTileWebContent extends StatefulWidget {
  final XFile? initialValue;
  final FormFieldState<XFile?> state;
  final ValueChanged<XFile?> onChanged;
  final bool enabled;

  const _AddImageTileWebContent({
    Key? key,
    required this.initialValue,
    required this.state,
    required this.onChanged,
    required this.enabled,
  }) : super(key: key);

  @override
  _AddImageTileWebContentState createState() => _AddImageTileWebContentState();
}

class _AddImageTileWebContentState extends State<_AddImageTileWebContent> {
  XFile? _imageFile;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: !widget.state.hasError
                ? widget.enabled ? Theme.of(context).colorScheme.primary : Colors.grey
                : Theme.of(context).colorScheme.error,
            width: 2.0,
          ),
          color: Colors.transparent,
        ),
        height: 146,
        width: 146,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_imageFile != null)
              ClipRRect(
                child: kIsWeb
                    ? Image.network(_imageFile!.path)  // Use Image.network for web
                    : Image.file(File(_imageFile!.path)),  // Use Image.file for mobile
              ),
            if (_imageFile != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.enabled ? [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.2),
                    ] : [
                      Colors.grey.withOpacity(0.7),
                      Colors.grey.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_imageFile == null)
                    const Text('Add an image'),
                  if (_imageFile != null)
                    const Text('Replace image', style: TextStyle(color: Colors.white)),
                  SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: widget.enabled ? () => _pickImage(ImageSource.camera) : () => logger.e("Clicked take image after form submit"),
                        child: Icon(Icons.camera_alt, color: widget.enabled ? Theme.of(context).colorScheme.primary : Colors.grey),
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(15),
                        ),
                      ),
                      SizedBox(width: 15),
                      ElevatedButton(
                        onPressed: widget.enabled ? () => _pickImage(ImageSource.gallery) : () => logger.e("Clicked pick image after form submit"),
                        child: Icon(Icons.collections, color: widget.enabled ? Theme.of(context).colorScheme.primary : Colors.grey),
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(15),
                        ),
                      ),
                    ],
                  ),
                  if (widget.state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        widget.state.errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    // Check and request permissions if needed
    if (source == ImageSource.camera) {
      if (await Permission.camera.request().isDenied) {
        return; // Permission denied, do not proceed
      }
    } else if (source == ImageSource.gallery) {
      if (await Permission.photos.request().isDenied) {
        return; // Permission denied, do not proceed
      }
    }

    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
        widget.onChanged(_imageFile);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }
}