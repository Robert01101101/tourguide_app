import 'package:tourguide_app/utilities/custom_import.dart';

class MyTours extends StatelessWidget {
  const MyTours({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tours'),
      ),
      body: Center(
          child: Text("My Tours Test")
      ),
    );
  }
}