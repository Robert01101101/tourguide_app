import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

//_________________________________________________________________________ CREATE FORM
class CreateTour extends StatefulWidget {
  const CreateTour({super.key});

  @override
  State<CreateTour> createState() => _CreateTourState();
}

class _CreateTourState extends State<CreateTour> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  bool _tourIsPublic = false; // Initial boolean value
  bool _isFormSubmitted = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final int _descriptionMaxChars = 100;



  _firestoreCreateTour() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    FirebaseAuth auth = FirebaseAuth.instance;

    //get userid
    final User user = auth.currentUser!; //assuming we're logged in here
    final uid = user.uid;

    final tour = <String, dynamic>{
      "name": _nameController.text,
      "description": _descriptionController.text,
      "city": _cityController.text,
      "uid": uid,
      "visibility": _tourIsPublic ? "public" : "private",
    };

    // Add a new document with a generated ID
    db.collection("tours").add(tour).then((DocumentReference doc){
        print('DocumentSnapshot added with ID: ${doc.id}');
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully created tour!')),
        );

        Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a new tour'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 32.0, // Vertical padding
            horizontal: 16.0, // Horizontal padding
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name for your tour';
                    }
                    return null;
                  },
                  enabled: !_isFormSubmitted,
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a city for your tour';
                    }
                    return null;
                  },
                  enabled: !_isFormSubmitted,
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                  maxLength: _descriptionMaxChars,
                  decoration: InputDecoration(
                    labelText: 'Description',
                  ),
                  validator: (String? value) {
                    if (value != null && value.length > _descriptionMaxChars-1) {
                      return 'Please enter a maximum of 100 characters';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {}); // Trigger a rebuild to update the character counter
                  },
                  enabled: !_isFormSubmitted,
                ),
                SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Make Public'), // Text label for the switch
                  value: _tourIsPublic, // The boolean value
                  onChanged: !_isFormSubmitted
                      ? (newValue) {
                    setState(() {
                      _tourIsPublic = newValue; // Update the boolean value
                    });
                  }
                      : null, // Disable switch if form is submitted
                  secondary: const Icon(Icons.public),
                  inactiveThumbColor: _isFormSubmitted ? Colors.grey : null,
                  inactiveTrackColor: _isFormSubmitted ? Colors.grey[300] : null,
                ),
                SizedBox(height: 32),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton(onPressed: () {
                    // Validate will return true if the form is valid, or false if
                    // the form is invalid.
                    if (_formKey.currentState!.validate()) {
                      // If the form is valid, display a snackbar. In the real world,
                      // you'd often call a server or save the information in a database.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Uploading')),
                      );
                      setState(() {
                        _isFormSubmitted = true;
                      });
                      _firestoreCreateTour();
                    }
                  }, child: const Text("Save and create tour")),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}