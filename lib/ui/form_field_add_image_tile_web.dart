import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as html;

import '../main.dart'; // Conditional import

//TODO: Better solution with web support, try to merge the mobile and web Widgets into one
class AddImageTileWeb extends FormField<XFile?> {
  // Use XFile instead of File
  final bool enabled;
  final bool isSelected;

  AddImageTileWeb({
    Key? key,
    XFile? initialValue, // Change initialValue type to XFile
    FormFieldSetter<XFile?>? onSaved,
    FormFieldValidator<XFile?>? validator,
    ValueChanged<XFile?>? onChanged,
    required this.enabled,
    required this.isSelected,
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
              isSelected: isSelected,
            );
          },
        );
}

class _AddImageTileWebContent extends StatefulWidget {
  final XFile? initialValue;
  final FormFieldState<XFile?> state;
  final ValueChanged<XFile?> onChanged;
  final bool enabled;
  final bool isSelected;

  const _AddImageTileWebContent({
    super.key,
    required this.initialValue,
    required this.state,
    required this.onChanged,
    required this.enabled,
    this.isSelected = false,
  });

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
      child: SizedBox(
        width: 146,
        height: 146,
        child: Stack(
          children: [
            IgnorePointer(
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            if (_imageFile != null)
              ClipRRect(
                child: kIsWeb
                    ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                    : Image.file(File(_imageFile!.path),
                        fit: BoxFit.cover), // Use Image.file for mobile
              ),
            if (_imageFile != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.enabled
                        ? [
                            Colors.black.withOpacity(0.4),
                            Colors.black.withOpacity(0.2),
                          ]
                        : [
                            Colors.grey.withOpacity(0.7),
                            Colors.grey.withOpacity(0.5),
                          ],
                  ),
                ),
              ),
            if (widget.isSelected)
              IgnorePointer(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor.withOpacity(
                      0.4), // Adjust the opacity to make it darker or lighter
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_imageFile == null) const Text('Add an image'),
                  if (_imageFile != null)
                    const Text('Replace image',
                        style: TextStyle(color: Colors.white)),
                  SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: widget.enabled
                            ? () => _pickImage(ImageSource.camera)
                            : () => logger
                                .e("Clicked take image after form submit"),
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(15),
                        ),
                        child: Icon(Icons.camera_alt,
                            color: widget.enabled
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey),
                      ),
                      /*SizedBox(width: 15),
                      ElevatedButton(
                        onPressed: widget.enabled ? () => _pickImage(ImageSource.gallery) : () => logger.e("Clicked pick image after form submit"),
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(15),
                        ),
                        child: Icon(Icons.collections, color: widget.enabled ? Theme.of(context).colorScheme.primary : Colors.grey),
                      ),*/
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
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: widget.isSelected
                      ? Border.all(
                          width: 2.0,
                          color: !widget.state.hasError
                              ? widget.enabled
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey
                              : Theme.of(context).colorScheme.error,
                        )
                      : null,
                ),
              ),
            ),
            if (widget.isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
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
