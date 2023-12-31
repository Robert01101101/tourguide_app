import 'package:tourguide_app/utilities/custom_import.dart';

class Map extends StatelessWidget {
  const Map({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Map'),
      ),
      body: Center(
          child: Text("Test")
      ),
    );
  }
}