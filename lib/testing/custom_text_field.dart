import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final String labelText;

  const CustomTextField({
    Key? key,
    required this.labelText,
  }) : super(key: key);

  @override
  CustomTextFieldState createState() => CustomTextFieldState();
}

//DELETE? Used for now because I thought I need custom styles and it was good practice, but turns out labelText works for what I want
class CustomTextFieldState extends State<CustomTextField> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        //hintText: widget.labelText,
        //helperText: _controller.text.isEmpty ? null: widget.labelText,
        labelText: widget.labelText,
      ),
      onChanged: (text) {
        setState(() {
          // Update the helper text when the user enters some text
        });
      },
    );
  }

  String getText() {
    return _controller.text;
  }
}
