import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tourguide_app/profile/app_settings.dart';
import 'package:tourguide_app/profile/premium.dart';
import 'package:tourguide_app/profile/profile_settings.dart';
import 'package:tourguide_app/profile/to_tour_list.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tourguide_app/utilities/ad_banner.dart';

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

    MyGlobals.webRoutingFix(TourguideNavigation.profilePath);
  }

  @override
  Widget build(BuildContext context) {
    //logger.t('FirebaseAuth.instance.currentUser=${FirebaseAuth.instance.currentUser}');
    myAuth.AuthProvider authProvider = Provider.of(context);
    TourguideUserProvider userProvider = Provider.of(context);
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
                const SizedBox(
                  height: 0,
                ),
                if (authProvider.isAnonymous)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                        'You are signed in as a guest. \n\nSign in with Google to save tours and access more features.'),
                  ),
                if (!authProvider.isAnonymous)
                  userProvider.user == null
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                              'Tourguide has ran into an issue while displaying your profile. Please sign out and sign in again.'),
                        )
                      : ListTile(
                          leading: authProvider.googleSignInUser != null
                              ? GoogleUserCircleAvatar(
                                  identity: authProvider.googleSignInUser!,
                                )
                              : null,
                          title: Text(userProvider.user!.displayName ?? ''),
                          subtitle: Text(userProvider.user!.email),
                        ),
                const SizedBox(
                  height: 8,
                ),
              ],
            ),
            MyBannerAdWidget(),
            const SizedBox(
              height: 32,
            ),
            StandardLayout(
              enableHorizontalPadding: false,
              enableVerticalPadding: false,
              children: [
                ProfileListButton(
                  label: 'Premium',
                  leftIcon: Icons.workspace_premium_rounded,
                  onPressed: () {
                    Navigator.push(
                      context,
                      SlideTransitionRoute(
                        page: const Premium(),
                        beginOffset:
                            const Offset(1.0, 0.0), // Slide in from right
                      ),
                    );
                  },
                  disabled: authProvider.isAnonymous,
                ),
                ProfileListButton(
                  label: 'Saved Tours',
                  leftIcon: Icons.bookmark_outline_rounded,
                  rightIcon: Icons.arrow_forward_ios,
                  onPressed: () {
                    Navigator.push(
                      context,
                      SlideTransitionRoute(
                        page: const ToTourList(),
                        beginOffset:
                            const Offset(1.0, 0.0), // Slide in from right
                      ),
                    );
                  },
                  disabled: authProvider.isAnonymous,
                ),
                ProfileListButton(
                  label: 'Profile Settings',
                  leftIcon: Icons.person_outline,
                  rightIcon: Icons.arrow_forward_ios,
                  onPressed: () {
                    Navigator.push(
                      context,
                      SlideTransitionRoute(
                        page: const ProfileSettings(),
                        beginOffset:
                            const Offset(1.0, 0.0), // Slide in from right
                      ),
                    );
                  },
                  disabled: authProvider.isAnonymous,
                ),
                ProfileListButton(
                  label: 'App Settings',
                  leftIcon: Icons.settings_outlined,
                  rightIcon: Icons.arrow_forward_ios,
                  onPressed: () {
                    Navigator.push(
                      context,
                      SlideTransitionRoute(
                        page: const AppSettings(),
                        beginOffset:
                            const Offset(1.0, 0.0), // Slide in from right
                      ),
                    );
                  },
                ),
                if (kIsWeb)
                  ProfileListButton(
                    label: 'Get the Android App on Google Play',
                    leftIcon: FontAwesomeIcons.googlePlay,
                    onPressed: () {
                      launchUrl(Uri.parse(
                          "https://play.google.com/store/apps/details?id=com.robertmichelsdigitalmedia.tourguideapp"));
                    },
                  ),
                ProfileListButton(
                  label: 'Community Guidelines',
                  leftIcon: Icons.local_library_outlined,
                  onPressed: () {
                    launchUrl(Uri.parse(
                        "https://tourguide.rmichels.com/communityGuidelines.html"));
                  },
                ),
                ProfileListButton(
                  label: 'Terms of Service',
                  leftIcon: Icons.description_outlined,
                  onPressed: () {
                    launchUrl(Uri.parse(
                        "https://tourguide.rmichels.com/termsOfService.html"));
                  },
                ),
                ProfileListButton(
                  label: 'Privacy Policy',
                  leftIcon: Icons.privacy_tip_outlined,
                  onPressed: () {
                    launchUrl(Uri.parse(
                        "https://tourguide.rmichels.com/privacyPolicy.html"));
                  },
                ),
                if (!kIsWeb)
                  ProfileListButton(
                    label: 'Rate Tourguide',
                    leftIcon: Icons.star_border,
                    onPressed: () {
                      launchUrl(Uri.parse(
                          "https://play.google.com/store/apps/details?id=com.robertmichelsdigitalmedia.tourguideapp"));
                    },
                  ),
                ProfileListButton(
                  label: 'Provide Feedback',
                  leftIcon: Icons.feedback_outlined,
                  onPressed: () {
                    launchUrl(Uri.parse(
                        "mailto:feedback@tourguide.rmichels.com?subject=Tourguide%20Feedback"));
                  },
                ),
                ProfileListButton(
                  label: 'Sign out',
                  leftIcon: Icons.logout,
                  onPressed: () {
                    tourProvider.resetTourProvider();
                    authProvider.signOut();
                  },
                  isLastItem: true,
                ),
                const SizedBox(
                  height: 16,
                )
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
            padding: EdgeInsets.all(
                (kIsWeb && MediaQuery.of(context).size.width > 1280) ? 24 : 16),
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(0), // Set to 0 for sharp corners
            ),
            foregroundColor:
                color != null ? color : Theme.of(context).colorScheme.primary,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(leftIcon), // Left icon
                  SizedBox(
                      width:
                          16), // Adjust spacing between icon and text as needed
                  Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (rightIcon != null)
                Icon(
                  rightIcon,
                  size: 20,
                ), // Right icon if provided
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
