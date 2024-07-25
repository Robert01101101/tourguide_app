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

class ProfileListButton extends StatelessWidget {
  final String label;
  final IconData leftIcon;
  final IconData? rightIcon;
  final VoidCallback onPressed;
  final bool? isLastItem;
  final Color? color;
  final bool? disabled;

  const ProfileListButton({
    required this.label,
    required this.leftIcon,
    this.rightIcon,
    required this.onPressed,
    this.isLastItem,
    this.color,
    this.disabled,
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
          onPressed: disabled ?? false ? null : onPressed,
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