import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';

class AddImageTile extends FormField<File?> {
  final bool enabled;

  AddImageTile({
    Key? key,
    File? initialValue,
    FormFieldSetter<File?>? onSaved,
    FormFieldValidator<File?>? validator,
    ValueChanged<File?>? onChanged,
    required this.enabled,
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
      );
    },
  );
}

class _AddImageTileContent extends StatefulWidget {
  final File? initialValue;
  final FormFieldState<File?> state;
  final ValueChanged<File?> onChanged;
  final bool enabled;

  const _AddImageTileContent({
    Key? key,
    required this.initialValue,
    required this.state,
    required this.onChanged,
    required this.enabled,
  }) : super(key: key);

  @override
  __AddImageTileContentState createState() => __AddImageTileContentState();
}

class __AddImageTileContentState extends State<_AddImageTileContent> {
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: !widget.state.hasError
                ? widget.enabled ? Theme.of(context).primaryColor : Colors.grey
                : Theme.of(context).colorScheme.error,
            width: 2.0,
          ),
          color: Colors.transparent,
        ),
        height: 200,
        width: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(18.0),
                child: Image.file(
                  _imageFile!,
                  fit: BoxFit.cover,
                ),
              ),
            if (_imageFile != null)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18.0),
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
                        child: Icon(Icons.camera_alt, color: widget.enabled ? Theme.of(context).primaryColor : Colors.grey),
                        style: ElevatedButton.styleFrom(
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(15),
                        ),
                      ),
                      SizedBox(width: 15),
                      ElevatedButton(
                        onPressed: widget.enabled ? () => _pickImage(ImageSource.gallery) : () => logger.e("Clicked pick image after form submit"),
                        child: Icon(Icons.collections, color: widget.enabled ? Theme.of(context).primaryColor : Colors.grey),
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
          _imageFile = File(pickedFile.path);
        });
        widget.onChanged(_imageFile);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }
}
