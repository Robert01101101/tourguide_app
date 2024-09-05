import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';

class AddImageTile extends FormField<File?> {
  final bool enabled;
  final bool isSelected;

  AddImageTile({
    Key? key,
    File? initialValue,
    FormFieldSetter<File?>? onSaved,
    FormFieldValidator<File?>? validator,
    ValueChanged<File?>? onChanged,
    required this.enabled,
    required this.isSelected,
  }) : super(
    key: key,
    initialValue: initialValue,
    onSaved: onSaved,
    validator: validator,
    builder: (FormFieldState<File?> state) {
      return _AddImageTileContent(
        initialValue: initialValue,
        state: state,
        onChanged: onChanged != null
            ? (File? file) {
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

class _AddImageTileContent extends StatefulWidget {
  final File? initialValue;
  final FormFieldState<File?> state;
  final ValueChanged<File?> onChanged;
  final bool enabled;
  final bool isSelected;

  const _AddImageTileContent({
    super.key,
    required this.initialValue,
    required this.state,
    required this.onChanged,
    required this.enabled,
    this.isSelected = false,
  });

  @override
  _AddImageTileContentState createState() => _AddImageTileContentState();
}

class _AddImageTileContentState extends State<_AddImageTileContent> {
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _imageFile = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              if (_imageFile != null)
                ClipRRect(
                  child: Image.file(
                    _imageFile!,
                    fit: BoxFit.cover,
                  ),
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
              if (widget.isSelected)
                IgnorePointer(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.4), // Adjust the opacity to make it darker or lighter
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
                          style: ElevatedButton.styleFrom(
                            shape: CircleBorder(),
                            padding: EdgeInsets.all(15),
                          ),
                          child: Icon(Icons.camera_alt, color: widget.enabled ? Theme.of(context).colorScheme.primary : Colors.grey),
                        ),
                        SizedBox(width: 15),
                        ElevatedButton(
                          onPressed: widget.enabled ? () => _pickImage(ImageSource.gallery) : () => logger.e("Clicked pick image after form submit"),
                          style: ElevatedButton.styleFrom(
                            shape: CircleBorder(),
                            padding: EdgeInsets.all(15),
                          ),
                          child: Icon(Icons.collections, color: widget.enabled ? Theme.of(context).colorScheme.primary : Colors.grey),
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
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: widget.isSelected ? Border.all(
                  width: 2.0,
                  color: !widget.state.hasError
                      ? widget.enabled ? Theme.of(context).colorScheme.primary : Colors.grey
                      : Theme.of(context).colorScheme.error,) : null,
              ),
              height: 146,
              width: 146,
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
          _imageFile = File(pickedFile.path);
        });
        widget.onChanged(_imageFile);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }
}
