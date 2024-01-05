import 'package:tourguide_app/debugScreen.dart';
import 'package:tourguide_app/utilities/custom_import.dart';

class Explore extends StatelessWidget {
  const Explore({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
      ),
      body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugScreen()),
              );
            },
            child: const Text('Debug Screen'),
          ),
      ),
    );
  }
}