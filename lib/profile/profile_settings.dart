import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'package:url_launcher/url_launcher.dart';

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {

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
        title: const Text('Profile Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            StandardLayout(
              children: [
                /*  //debug view
                StandardLayout(
                  enableHorizontalPadding: false,
                  enableVerticalPadding: false,
                  children: [
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
                ),*/
                SizedBox(height: 0,),
                ListTile(
                  leading: GoogleUserCircleAvatar(
                    identity: authProvider.user!,
                  ),
                  title: Text(authProvider.user!.displayName ?? ''),
                  subtitle: Text(authProvider.user!.email),
                ),
                SizedBox(height: 8,),
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
                  label: 'Update Firestore profile data (get)',
                  leftIcon: Icons.data_object,
                  onPressed: () {
                    setState(() {
                      _profileDataFuture = _firestoreGetUserProfileData();
                    });
                  },
                ),
                ProfileListButton(
                  label: 'Delete Account',
                  leftIcon: Icons.delete_outline,
                  rightIcon: Icons.arrow_forward_ios,
                  isLastItem: true,
                  onPressed: () {
                    Navigator.push(
                      context,
                      SlideTransitionRoute(
                        page: ProfileSettingsDeleteAccount(),
                        beginOffset: Offset(1.0, 0.0), // Slide in from right
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}




class ProfileSettingsDeleteAccount extends StatefulWidget {
  const ProfileSettingsDeleteAccount({super.key});

  @override
  State<ProfileSettingsDeleteAccount> createState() => _ProfileSettingsDeleteAccountState();
}

class _ProfileSettingsDeleteAccountState extends State<ProfileSettingsDeleteAccount> {
  final TextEditingController _confirmFieldController = TextEditingController();
  bool _isDeleteEnabled = false;

  @override
  void initState() {
    super.initState();
    _confirmFieldController.addListener(_checkDeleteText);
  }

  @override
  void dispose() {
    _confirmFieldController.removeListener(_checkDeleteText);
    _confirmFieldController.dispose();
    super.dispose();
  }

  void _checkDeleteText() {
    setState(() {
      _isDeleteEnabled = _confirmFieldController.text == "DELETE";
    });
  }

  void _deleteAccount(){
    logger.w("Delete account confirmed and pressed");
  }


  @override
  Widget build(BuildContext context) {
    logger.t('FirebaseAuth.instance.currentUser=${FirebaseAuth.instance.currentUser}');
    myAuth.AuthProvider authProvider = Provider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
      ),
      body: SingleChildScrollView(
        child: StandardLayout(
          children: [
            SizedBox(height: 0,),
            Text("Confirm Account Deletion", style: Theme.of(context).textTheme.headlineSmall),
            Text("Hey there!"
                "\n\n"
                'Before you go ahead and delete your account, just a heads-up: this action is permanent and cannot be undone. Deleting your account means all your personal information and contributions, like the tours you\'ve created and the ratings you\'ve left, will be permanently removed.'
                '\n\n'
                'We\'d hate to see you go, but if you\'re sure, hit that delete button. Just remember, once it\'s gone, it\'s gone for good!'
                '\n\n'
                'Keep exploring the world,'
                '\n'
                'Your Tourguide Team', style: Theme.of(context).textTheme.bodyLarge),
            SizedBox(height: 16,),
            TextFormField(
              controller: _confirmFieldController,
              decoration: InputDecoration(
                labelText: 'Type "DELETE" to confirm',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.error,),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name for your tour';
                }
                return null;
              },
              //enabled: !_isFormSubmitted,
            ),
            Center(
              child: ElevatedButton(
                  onPressed: _isDeleteEnabled ? _deleteAccount : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                      textStyle: TextStyle(
                          fontWeight: FontWeight.bold,)),
                  child: const Text("Permanently Delete Account and Contributions")),
            ),
          ],
        )
      ),
    );
  }
}