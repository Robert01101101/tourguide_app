import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tourguide_app/profile/profile_settings.dart';
import 'package:tourguide_app/profile/to_tour_list.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {

  final TextEditingController _usernameController = TextEditingController();


  @override
  void initState() {
    super.initState();
  }


  //db = FirebaseFirestore.instance;
  @override
  Widget build(BuildContext context) {
    logger.t('FirebaseAuth.instance.currentUser=${FirebaseAuth.instance.currentUser}');
    myAuth.AuthProvider authProvider = Provider.of(context);
    TourProvider tourProvider = Provider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
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
                    identity: authProvider.googleSignInUser!,
                  ),
                  title: Text(authProvider.googleSignInUser!.displayName ?? ''),
                  subtitle: Text(authProvider.googleSignInUser!.email),
                ),
                SizedBox(height: 8,),
                /*
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
                SizedBox(height: 32,),*/
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProfileListButton(
                  label: 'Saved Tours',
                  leftIcon: Icons.bookmark_outline_rounded,
                  rightIcon: Icons.arrow_forward_ios,
                  onPressed: () {
                    Navigator.push(
                      context,
                      SlideTransitionRoute(
                        page: ToTourList(),
                        beginOffset: Offset(1.0, 0.0), // Slide in from right
                      ),
                    );
                  },
                ),
                ProfileListButton(
                  label: 'Profile Settings',
                  leftIcon: Icons.person_outline,
                  rightIcon: Icons.arrow_forward_ios,
                  onPressed: () {
                    Navigator.push(
                      context,
                      SlideTransitionRoute(
                        page: ProfileSettings(),
                        beginOffset: Offset(1.0, 0.0), // Slide in from right
                      ),
                    );
                  },
                ),
                ProfileListButton(
                  label: 'App Settings',
                  leftIcon: Icons.settings_outlined,
                  rightIcon: Icons.arrow_forward_ios,
                  onPressed: () {

                  },
                ),
                ProfileListButton(
                  label: 'Privacy Policy',
                  leftIcon: Icons.privacy_tip_outlined,
                  onPressed: () {
                    launchUrl(Uri.parse("https://tourguide.rmichels.com/privacyPolicy.html"));
                  },
                ),
                /*
                ProfileListButton(
                  label: 'Update Firestore profile data (get)',
                  leftIcon: Icons.data_object,
                  onPressed: () {
                    setState(() {
                      _profileDataFuture = _firestoreGetUserProfileData();
                    });
                  },
                ),*/
                ProfileListButton(
                  label: 'Sign out',
                  leftIcon: Icons.logout,
                  onPressed: () {
                    tourProvider.resetTourProvider();
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
  final Color? color;

  const ProfileListButton({
    required this.label,
    required this.leftIcon,
    this.rightIcon,
    required this.onPressed,
    this.isLastItem,
    this.color
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
            foregroundColor: color != null ? color : Theme.of(context).colorScheme.primary,
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