import 'package:tourguide_app/tourCreation/flutterGooglePlacesSample.dart';
import 'package:tourguide_app/tourCreation/tourCreationPlacesTesting.dart';
import 'package:tourguide_app/utilities/custom_import.dart';

//Debug Screen

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => DebugScreenState();
}

class DebugScreenState extends State<DebugScreen> {

  //do on page load
  @override
  void initState() {
    super.initState();

    //doing nothing custom atm -> remove?
  }


  //________________________________________________________________________________________ MapSample StatefulWidget - BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug'),
      ),


      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Debug Options',
                style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(
              height: 80,
            ),
            Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,children: [
              ElevatedButton(onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapSample()),
                );
              }, child: const Text("Map Sample")),
              ElevatedButton(onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapSampleDrawRoute()),
                );
              }, child: const Text("Map Routing")),
              ElevatedButton(onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SecondRoute()),
                );
              }, child: const Text("Route 2")),
              ElevatedButton(onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FlutterGooglePlacesSample()),
                );
              }, child: const Text("Places")),
              ElevatedButton(onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateTourTesting()),
                );
              }, child: const Text("Tour creation places testing")),
            ],)
          ],
        ),
      ),
    );
  }
}