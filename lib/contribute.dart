import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/tour/tour_creation.dart';
import 'package:tourguide_app/ui/horizontal_scroller.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/ui/shimmer_loading.dart';
import 'package:tourguide_app/utilities/ad_banner.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:tourguide_app/utilities/providers/location_provider.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';

import 'explore_map.dart';
import 'main.dart';

class Contribute extends StatefulWidget {
  const Contribute({super.key});

  @override
  State<Contribute> createState() => _ContributeState();
}

class _ContributeState extends State<Contribute> {
  final ScrollController _scrollController = ScrollController();

  Future<void> _downloadTours() async {
    await MyGlobals.downloadTours(context);
  }

  @override
  Widget build(BuildContext context) {
    TourProvider tourProvider = Provider.of<TourProvider>(context);
    myAuth.AuthProvider authProvider = Provider.of(context);

    Future<void> refresh() async {
      if (!tourProvider.isLoadingTours) {
        await _downloadTours();
      }
    }

    List<String> userCreatedTourIds = List.from(tourProvider.userCreatedTours);
    userCreatedTourIds.remove(Tour.addTourTileId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contribute'),
      ),
      body: authProvider.isAnonymous
          ? const StandardLayout(
              children: [
                SizedBox(
                  height: 0,
                ),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                      'You are signed in as a guest. \n\nSign in with Google to create tours and access more features.'),
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: refresh,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Shimmer(
                  linearGradient: MyGlobals.createShimmerGradient(context),
                  child: StandardLayout(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Tours you created",
                              style: Theme.of(context).textTheme.headlineSmall),
                          IconButton(
                              onPressed: tourProvider.userCreatedTours.length <=
                                      1
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => ExploreMap(
                                                tours:
                                                    tourProvider.getToursByIds(
                                                        userCreatedTourIds),
                                                name: "Tours you created")),
                                      );
                                    },
                              icon: const Icon(Icons.map))
                        ],
                      ),
                      StandardLayoutChild(
                        fullWidth: true,
                        child: HorizontalScroller(
                            tours: tourProvider
                                .getToursByIds(tourProvider.userCreatedTours),
                            leftPadding: true),
                      ),
                      StandardLayoutChild(
                        fullWidth: true,
                        child: MyBannerAdWidget(),
                      ),
                      /*Text("Review unreviewed tours", style: Theme.of(context).textTheme.headlineSmall),
                StandardLayoutChild(
                  fullWidth: true,
                  child: SizedBox(
                    height: 220.0, // Set a fixed height for the horizontal scroller
                    child: HorizontalScroller(tours: tourProvider.userCreatedTours, leftPadding: true),
                  ),
                ),*/
                      /*
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ElevatedButton(onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PublicTours(isPublic: true)),
                      );
                    }, child: const Text("Public tours")),
                    SizedBox(width: 16,),
                    ElevatedButton(onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PublicTours(isPublic: false)),
                      );
                    }, child: const Text("Your private tours")),
                  ],
                ),*/
                    ],
                  ),
                ),
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
    MyGlobals.webRoutingFix(TourguideNavigation.contributePath);
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
