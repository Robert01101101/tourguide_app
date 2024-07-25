import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tourguide_app/model/tourguide_user.dart';
import 'package:tourguide_app/profile/app_settings.dart';
import 'package:tourguide_app/profile/profile_settings.dart';
import 'package:tourguide_app/profile/to_tour_list.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TourguideUserProfileView extends StatefulWidget {
  final String tourguideUserId;
  final String tourguideUserDisplayName;

  const TourguideUserProfileView({Key? key, required this.tourguideUserId, required this.tourguideUserDisplayName}) : super(key: key);

  @override
  State<TourguideUserProfileView> createState() => _TourguideUserProfileViewState();
}

class _TourguideUserProfileViewState extends State<TourguideUserProfileView> {

  @override
  Widget build(BuildContext context) {
    TourguideUserProvider tourguideUserProvider = Provider.of<TourguideUserProvider>(context);

    bool isCurrentUser = widget.tourguideUserId == tourguideUserProvider.user!.firebaseAuthId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tour Author'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [/*
            StandardLayout(
              children: [
                SizedBox(height: 0,),
                ListTile(
                  leading: GoogleUserCircleAvatar(
                    identity: authProvider.googleSignInUser!,
                  ),
                  title: Text(authProvider.googleSignInUser!.displayName ?? ''),
                  subtitle: Text(authProvider.googleSignInUser!.email),
                ),
                SizedBox(height: 8,),
              ],
            ),*/
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 64.0, horizontal: 32),
              child: Text(widget.tourguideUserDisplayName, style: Theme.of(context).textTheme.titleLarge,),
            ),
            if (isCurrentUser)
              const Padding(
                padding: EdgeInsets.only(left:  8, right: 8, bottom: 32.0),
                child: Text('This is how other users see your profile.'),
              ),
            ProfileListButton(
              label: 'Block User',
              leftIcon: Icons.block,
              rightIcon: Icons.arrow_forward_ios,
              onPressed: (){},
              disabled: isCurrentUser,
            ),
            ProfileListButton(
              label: 'Report User',
              leftIcon: Icons.report_outlined,
              rightIcon: Icons.arrow_forward_ios,
              onPressed: (){},
              disabled: isCurrentUser,
            ),
            ProfileListButton(
              label: 'What other options would you like to see here?',
              leftIcon: Icons.feedback_outlined,
              isLastItem: true,
              onPressed: () {
                launchUrl(Uri.parse("mailto:feedback@tourguide.rmichels.com?subject=Tourguide%20Tour%20Author%20Screen%20Feedback"));
              },
            ),
          ],
        ),
      ),
    );
  }
}