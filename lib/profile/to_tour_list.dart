import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/ui/horizontal_scroller.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';

class ToTourList extends StatefulWidget {
  const ToTourList({super.key});

  @override
  State<ToTourList> createState() => _ToTourListState();
}

class _ToTourListState extends State<ToTourList> {
  @override
  Widget build(BuildContext context) {
    TourProvider tourProvider = Provider.of<TourProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Tours'),
      ),
      body: Shimmer(
        linearGradient: MyGlobals.createShimmerGradient(context),
        child: StandardLayout(
          children: [
            const SizedBox(height: 0),
            Text("To Tour List",
                style: Theme.of(context).textTheme.headlineSmall),
            StandardLayoutChild(
              fullWidth: true,
              child: HorizontalScroller(
                  leftPadding: true,
                  tours:
                      tourProvider.getToursByIds(tourProvider.userSavedTours)),
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
    if (isPublic) {
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
