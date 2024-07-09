import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'package:url_launcher/url_launcher.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {

  final TextEditingController _usernameController = TextEditingController();
  late Future<DocumentSnapshot> _profileDataFuture;


  @override
  void initState() {
    //_firebaseCloudFirestoreTest();
    _profileDataFuture = _firestoreGetUserProfileData();

    super.initState();
  }

  _firebaseCloudFirestoreTest() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    FirebaseAuth auth = FirebaseAuth.instance;

    //get userid
    final User user = auth.currentUser!; //assuming we're logged in here
    final uid = user.uid;


    final profile = <String, dynamic>{
      "username": "Robeat",
    };

    // Add a new document with the userid
    /*
    db.collection("profiles").doc(uid).set(profile).then((_) =>
        logger.t('DocumentSnapshot added with ID: ${uid}'));*/

    /*
    final tourPrivate = <String, dynamic>{
      "name": "Robert Tour Two",
      "visibility": "private"
    };

    // Add a new document with a generated ID
    db.collection("tours").add(tourPrivate).then((DocumentReference doc) =>
        logger.t('DocumentSnapshot added with ID: ${doc.id}'));*/

    //get
    logger.t('GET -------');
    DocumentSnapshot profileSnapshot = await db.collection("profiles").doc(uid).get();
    if (profileSnapshot.exists) {
      // Profile exists, you can access the data
      var profileData = profileSnapshot.data();
      logger.t('Profile data: $profileData');
    } else {
      // Profile doesn't exist
      logger.t('Profile not found');
    }



    /*
    https://firebase.google.com/dohttps://firebase.google.com/docs/firestore/quickstartcs/firestore/quickstart

    //Cloud Firestore stores data in Documents, which are stored in Collections. Cloud Firestore creates collections and documents
    // implicitly the first time you add data to the document. You do not need to explicitly create collections or documents.
    // Create a new user with a first and last name
    final user = <String, dynamic>{
      "first": "Ada",
      "last": "Lovelace",
      "born": 1815
    };

    // Add a new document with a generated ID
    db.collection("users").add(user).then((DocumentReference doc) =>
        logger.t('DocumentSnapshot added with ID: ${doc.id}'));

    //Now add another document to the users collection. Notice that this document includes a key-value pair (middle name) that does not
    // appear in the first document. Documents in a collection can contain different sets of information.
    // Create a new user with a first and last name
    final userAlt = <String, dynamic>{
      "first": "Alan",
      "middle": "Mathison",
      "last": "Turing",
      "born": 1912
    };

    // Add a new document with a generated ID
    db.collection("users").add(userAlt).then((DocumentReference doc) =>
        logger.t('DocumentSnapshot added with ID: ${doc.id}'));

    //Use the data viewer in the Firebase console to quickly verify that you've added data to Cloud Firestore.
    // You can also use the "get" method to retrieve the entire collection.
    await db.collection("users").get().then((event) {
      for (var doc in event.docs) {
        logger.t("${doc.id} => ${doc.data()}");
      }
    });
    */
  }


  Future<DocumentSnapshot> _firestoreGetUserProfileData() async {
    logger.t('-- _firestoreGetUserProfileData()');
    FirebaseFirestore db = FirebaseFirestore.instance;
    FirebaseAuth auth = FirebaseAuth.instance;

    //get userid
    final User user = auth.currentUser!; //assuming we're logged in here
    final uid = user.uid;

    //get
    logger.t('GET -------');
    DocumentSnapshot profileSnapshot = await db.collection("profiles").doc(uid).get();
    if (profileSnapshot.exists) {
      // Profile exists, you can access the data
      var profileData = profileSnapshot.data();
      logger.t('Profile data: $profileData');
    } else {
      // Profile doesn't exist
      logger.t('Profile not found');
    }



    return profileSnapshot;
  }

  _firestoreSetUserProfileData() async {
    logger.t('-- _firestoreSetUserProfileData()');
    FirebaseFirestore db = FirebaseFirestore.instance;
    FirebaseAuth auth = FirebaseAuth.instance;

    //get userid
    final User user = auth.currentUser!; //assuming we're logged in here
    final uid = user.uid;


    final profile = <String, dynamic>{
      "username": _usernameController.text,
    };

    db.collection("profiles").doc(uid).set(profile).then((_) =>
        logger.t('DocumentSnapshot added with ID: ${uid}'));
  }


  //db = FirebaseFirestore.instance;
  @override
  Widget build(BuildContext context) {
    logger.t('FirebaseAuth.instance.currentUser=${FirebaseAuth.instance.currentUser}');
    myAuth.AuthProvider authProvider = Provider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            StandardLayout(
              children: [
                StandardLayout(
                  enableHorizontalPadding: false,
                  enableVerticalPadding: false,
                  children: [
                    ListTile(
                      leading: GoogleUserCircleAvatar(
                        identity: authProvider.user!,
                      ),
                      title: Text(authProvider.user!.displayName ?? ''),
                      subtitle: Text(authProvider.user!.email),
                    ),
                    SizedBox(height: 16,),
                    Text("Your userdata:", style: Theme.of(context).textTheme.headlineSmall),
                    SizedBox(height: 8,),
                    Text("Google Auth data", style: Theme.of(context).textTheme.bodyLarge),
                    SizedBox(height: 8,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("uid:"),
                            Text("Display Name:"),
                            Text("email:"),
                            Text("email verified:"),
                            Text("multiFactor:"),
                            Text("phoneNumber: "),
                          ],
                        ),
                        SizedBox(width: 32,),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${FirebaseAuth.instance.currentUser!.uid}"),
                            Text("${FirebaseAuth.instance.currentUser!.displayName}"),
                            Text("${FirebaseAuth.instance.currentUser!.email}"),
                            Text("${FirebaseAuth.instance.currentUser!.emailVerified}"),
                            Text("${FirebaseAuth.instance.currentUser!.multiFactor}"),
                            Text("${FirebaseAuth.instance.currentUser!.phoneNumber}"),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16,),
                    Text("Firestore profile data", style: Theme.of(context).textTheme.bodyLarge),
                    SizedBox(height: 8,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("username:"),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<DocumentSnapshot>(
                              future: _profileDataFuture,
                        builder: (context, snapshot){
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return CircularProgressIndicator();
                                } else if (snapshot != null && snapshot.hasData && !snapshot.hasError && snapshot.data!.exists){
                                  final username = snapshot.data!['username'];
                                  return Text("${username}");
                                } else {
                                  return Text("Error: ${snapshot.error}");
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter your new username',
                        ),
                      ),
                    ),
                    SizedBox(width: 32,),
                    ElevatedButton(onPressed: () {
                      _firestoreSetUserProfileData();
                    }, child: const Text("Save")),
                  ],
                ),
                SizedBox(height: 32,),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProfileListButton(
                  label: 'Privacy Policy',
                  leftIcon: Icons.privacy_tip_outlined,
                  rightIcon: Icons.arrow_forward_ios,
                  onPressed: () {
                    launchUrl(Uri.parse("https://tourguide.rmichels.com/privacyPolicy.html"));
                  },
                ),
                ProfileListButton(
                  label: 'Update Firestore profile data (get)',
                  leftIcon: Icons.data_object,
                  onPressed: () {
                    setState(() {
                      _profileDataFuture = _firestoreGetUserProfileData();
                    });
                  },
                ),
                ProfileListButton(
                  label: 'Sign out',
                  leftIcon: Icons.logout,
                  onPressed: () {
                    authProvider.signOut();
                  },
                  isLastItem: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileListButton extends StatelessWidget {
  final String label;
  final IconData leftIcon;
  final IconData? rightIcon;
  final VoidCallback onPressed;
  final bool? isLastItem;

  const ProfileListButton({
    required this.label,
    required this.leftIcon,
    this.rightIcon,
    required this.onPressed,
    this.isLastItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(height: 1, color: Colors.grey),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: EdgeInsets.all(16.0),
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0), // Set to 0 for sharp corners
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(leftIcon), // Left icon
                  SizedBox(width: 16), // Adjust spacing between icon and text as needed
                  Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (rightIcon != null) Icon(rightIcon, size: 20,), // Right icon if provided
            ],
          ),
        ),
        if (isLastItem ?? false)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(height: 1, color: Colors.grey),
          ),
      ],
    );
  }
}