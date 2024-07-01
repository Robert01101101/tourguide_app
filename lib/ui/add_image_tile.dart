import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddImageTile extends StatelessWidget {
  final File? imageFile;
  final VoidCallback pickImageFromCamera;
  final VoidCallback pickImageFromGallery;

  const AddImageTile({
    Key? key,
    this.imageFile,
    required this.pickImageFromCamera,
    required this.pickImageFromGallery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0), // Adjust the radius as needed
        border: Border.all(color: Theme.of(context).primaryColor, width: 2.0), // Grey border, adjust width as needed
        color: Colors.transparent, // Transparent fill
      ),
      height: 200,
      width: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(18.0),
              child: Image.file(
                imageFile!,
                fit: BoxFit.cover,
              ),
            ),
          if (imageFile != null)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18.0),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.2), // Adjust opacity and colors as needed
                  ],
                ),
              ),
            ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (imageFile == null)
                  const Text('Add an image'),
                if (imageFile != null)
                  const Text('Replace image', style: TextStyle(color: Colors.white)),
                SizedBox(height: 15,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: pickImageFromCamera,
                      child: Icon(Icons.camera_alt, color: Theme.of(context).primaryColor),
                      style: ElevatedButton.styleFrom(
                        shape: CircleBorder(),
                        padding: EdgeInsets.all(15),
                      ),
                    ),
                    SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: pickImageFromGallery,
                      child: Icon(Icons.collections, color: Theme.of(context).primaryColor),
                      style: ElevatedButton.styleFrom(
                        shape: CircleBorder(),
                        padding: EdgeInsets.all(15),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}