import 'package:tourguide_app/testing/flutter_google_places_sample.dart';
import 'package:tourguide_app/gemini_chat.dart';
import 'package:tourguide_app/testing/tour_creation_places_testing.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:tourguide_app/utilities/map_utils.dart';

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
              ElevatedButton(onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GeminiChat()),
                );
              }, child: const Text("Gemini Chat")),
              ElevatedButton(onPressed: (){
                MapUtils.openMap(-3.823216,-38.481700);
              }, child: const Text("Google Maps GPS link")),
              ElevatedButton(onPressed: (){
                MapUtils.openMapWithQuery("Waterfront Vancouver BC Canada");
              }, child: const Text("Google Maps Address link")),
              ElevatedButton(onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              }, child: const Text("Old Map Menu Option")),
            ],)
          ],
        ),
      ),
    );
  }
}