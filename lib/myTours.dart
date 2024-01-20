import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/tourCreation/tourCreation.dart';
import 'package:tourguide_app/utilities/custom_import.dart';

import 'main.dart';


class MyTours extends StatefulWidget {
  const MyTours({super.key});

  @override
  State<MyTours> createState() => _MyTours();
}

class _MyTours extends State<MyTours> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 32.0, // Vertical padding
          horizontal: 16.0, // Horizontal padding
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Create a new tour", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateTour()),
              );
            }, child: const Text("Create a tour")),
            const SizedBox(height: 64),
            Text("View existing tours", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PublicTours(isPublic: true)),
                  );
                }, child: const Text("Public tours")),
                ElevatedButton(onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PublicTours(isPublic: false)),
                  );
                }, child: const Text("Your private tours")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



//_________________________________________________________________________ PUBLIC TOURS
class PublicTours extends StatefulWidget {
  const PublicTours({super.key, required this.isPublic});

  final bool isPublic;

  @override
  State<PublicTours> createState() => _PublicToursState();
}


class _PublicToursState extends State<PublicTours> {
  FirebaseFirestore db = FirebaseFirestore.instance;
  FirebaseAuth auth = FirebaseAuth.instance;
  late bool isPublic;

  // List to store tour data
  List<Map<String, dynamic>> tours = [];

  @override
  void initState() {
    super.initState();
    isPublic = widget.isPublic;
    _firestoreGetPublicTours(widget.isPublic);
  }


  _firestoreGetPublicTours(bool isPublic) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    FirebaseAuth auth = FirebaseAuth.instance;

    //get userid
    final User user = auth.currentUser!; //assuming we're logged in here
    final uid = user.uid;

    // get public tours
    QuerySnapshot querySnapshot;
    if (isPublic){
      querySnapshot = await db
          .collection("tours")
          .where("visibility", isEqualTo: "public")
          .get();
    } else {
      querySnapshot = await db
          .collection("tours")
          .where("visibility", isEqualTo: "private")
          .where("uid", isEqualTo: uid)
          .get();
    }
    

    // populate tours list
    setState(() {
      tours = List<Map<String, dynamic>>.from(querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'name': data['name'] ?? 'No Name Specified',
          'city': data['city'] ?? 'No City Specified',
          // Add more properties with null checks if needed
        };
      }));
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Tours'),
      ),
      body: ListView.builder(
        itemCount: tours.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              title: Text(tours[index]['name']),
              subtitle: Text(tours[index]['city']),
              // You can customize the ListTile based on your data structure
            ),
          );
        },
      ),
    );
  }
}

