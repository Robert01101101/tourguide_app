import 'package:tourguide_app/utilities/custom_import.dart';

class MyTours extends StatelessWidget {
  const MyTours({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('My Tours'),
      ),
      body: Center(
          child: Text("Test")
      ),
    );
  }
}