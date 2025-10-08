import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';

enum NameDisplaySetting { displayName, username }

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  late TextEditingController _usernameController;
  bool _updatingUsername = false;
  bool _updatingUseUsername = false;
  String _newUsername = '';
  bool _isUsernameAvailable = true;
  bool _profanityDetected = false;
  final _filter = ProfanityFilter();
  NameDisplaySetting? _nameDisplaySetting = NameDisplaySetting.displayName;

  @override
  void initState() {
    super.initState();
    TourguideUserProvider userProvider = Provider.of(context, listen: false);
    _usernameController =
        TextEditingController(text: userProvider.user!.username);
    _newUsername = userProvider.user!.username;
    _usernameController.addListener(_onUsernameChanged);
    _nameDisplaySetting = userProvider.user!.useUsername
        ? NameDisplaySetting.username
        : NameDisplaySetting.displayName;
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    setState(() {
      _newUsername = _usernameController.text;
      List<String> profanityDetectableWords =
          _newUsername.split(RegExp(r'[A-Z]|_|-|\.')); // Split camel case
      for (String word in profanityDetectableWords) {
        _profanityDetected = _filter.hasProfanity(word);
        if (_profanityDetected) {
          break;
        }
      }
    });
  }

  void _onUseUsernameChanged(NameDisplaySetting? value) {
    setState(() {
      _nameDisplaySetting = value;
    });
  }

  // TODO: fix access to context -> don't do in async
  Future<void> _setUsername() async {
    logger.t('Setting username');
    if (_updatingUsername) return;
    setState(() {
      _updatingUsername = true;
    });
    TourguideUserProvider userProvider = Provider.of(context, listen: false);
    TourProvider tourProvider = Provider.of(context, listen: false);
    if (await userProvider.checkUsernameAvailability(_newUsername)) {
      setState(() {
        _isUsernameAvailable = true;
      });
    } else {
      setState(() {
        _isUsernameAvailable = false;
        _updatingUsername = false;
      });
      return;
    }
    logger.i('Updating username to $_newUsername');
    await userProvider.updateUser(userProvider.user!.copyWith(
        username: _newUsername, displayName: userProvider.user!.displayName));
    await tourProvider.updateAuthorNameForAllTheirTours(
        userProvider.user!.firebaseAuthId,
        userProvider.user!.useUsername
            ? userProvider.user!.username
            : userProvider.user!.displayName);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Updated username to ${userProvider.user!.username}')),
      );
    }
    setState(() {
      _updatingUsername = false;
    });
  }

  // TODO: fix access to context -> don't do in async
  Future<void> _setUseUsername() async {
    logger.t('Setting use username');
    if (_updatingUseUsername) return;
    setState(() {
      _updatingUseUsername = true;
    });
    TourguideUserProvider userProvider = Provider.of(context, listen: false);
    TourProvider tourProvider = Provider.of(context, listen: false);
    logger.i(
        'Updating useUsername to ${_nameDisplaySetting == NameDisplaySetting.username}');
    await userProvider.updateUser(userProvider.user!.copyWith(
        //TODO improve async safety
        useUsername: _nameDisplaySetting == NameDisplaySetting.username));
    await tourProvider.updateAuthorNameForAllTheirTours(
        userProvider.user!.firebaseAuthId,
        userProvider.user!.useUsername
            ? userProvider.user!.username
            : userProvider.user!.displayName);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Now using your ${userProvider.user!.useUsername ? 'username' : 'display name'}')),
      );
    }
    setState(() {
      _updatingUseUsername = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    myAuth.AuthProvider authProvider = Provider.of(context);
    TourguideUserProvider userProvider = Provider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
      ),
      body: userProvider.user != null && authProvider.user != null
          ? SingleChildScrollView(
              child: Column(
                children: [
                  StandardLayout(
                    children: [
                      const SizedBox(
                        height: 0,
                      ),
                      ListTile(
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
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usernameController,
                              maxLength: 25,
                              decoration: InputDecoration(
                                hintText: 'Enter your new username',
                                labelText: 'Username',
                                errorText: _profanityDetected
                                    ? 'No profanity please'
                                    : !_isUsernameAvailable
                                        ? 'Username is already taken'
                                        : null,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 32,
                          ),
                          ElevatedButton(
                              onPressed: (_profanityDetected ||
                                      _updatingUsername ||
                                      _newUsername ==
                                          userProvider.user!.username)
                                  ? null
                                  : () => _setUsername(),
                              child: _updatingUsername
                                  ? const Text("Saving")
                                  : const Text("Save")),
                        ],
                      ),
                      Text("Your name will be displayed as:",
                          style: Theme.of(context).textTheme.labelLarge),
                      Column(
                        children: [
                          RadioListTile<NameDisplaySetting>(
                            title: Text(
                                'Display Name \n(${userProvider.user!.displayName})'),
                            value: NameDisplaySetting.displayName,
                            groupValue: _nameDisplaySetting,
                            onChanged: _onUseUsernameChanged,
                          ),
                          RadioListTile<NameDisplaySetting>(
                            title: Text(
                                'Username \n(${userProvider.user!.username.isEmpty ? 'not set' : userProvider.user!.username})'),
                            value: NameDisplaySetting.username,
                            groupValue: _nameDisplaySetting,
                            onChanged: _onUseUsernameChanged,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                                onPressed: (_updatingUseUsername ||
                                        (_nameDisplaySetting ==
                                                NameDisplaySetting.username) ==
                                            userProvider.user!.useUsername)
                                    ? null
                                    : () => _setUseUsername(),
                                child: _updatingUseUsername
                                    ? const Text("Saving")
                                    : const Text("Save")),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 32,
                      ),
                    ],
                  ),
                  StandardLayout(
                    children: [
                      ProfileListButton(
                        label: 'Delete Account',
                        leftIcon: Icons.delete_outline,
                        rightIcon: Icons.arrow_forward_ios,
                        isLastItem: true,
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () {
                          Navigator.push(
                            context,
                            SlideTransitionRoute(
                              page: const ProfileSettingsDeleteAccount(),
                              beginOffset:
                                  const Offset(1.0, 0.0), // Slide in from right
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            )
          : const Text("Profile not loaded"),
    );
  }
}

class ProfileSettingsDeleteAccount extends StatefulWidget {
  const ProfileSettingsDeleteAccount({super.key});

  @override
  State<ProfileSettingsDeleteAccount> createState() =>
      _ProfileSettingsDeleteAccountState();
}

class _ProfileSettingsDeleteAccountState
    extends State<ProfileSettingsDeleteAccount> {
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

  bool _deleteStarted = false;
  void _deleteAccount() async {
    myAuth.AuthProvider authProvider = Provider.of(context, listen: false);
    TourProvider tourProvider = Provider.of(context, listen: false);
    TourguideUserProvider tourguideUserProvider =
        Provider.of(context, listen: false);

    if (_deleteStarted) return;
    logger.w("Delete account confirmed and pressed");
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        _deleteStarted = true;
        tourProvider.resetTourProvider();
        tourguideUserProvider.resetUserProvider();
        await user.delete();
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.remove('firstTimeUser');
        authProvider.deleteUser();

        TourguideNavigation.router.go(
          TourguideNavigation.signInPath,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account successfully deleted')),
          );
        }

        logger.w("User account deleted");
      } on FirebaseAuthException catch (e, stack) {
        logger.e("Error deleting user account: $e \n $stack");

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Failed to delete account. For security reasons you ned to re-authenticate first.')),
          );
        }
        authProvider.signOut();
      } catch (e, stack) {
        logger.e("Error deleting user account: $e \n $stack");

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Failed to delete account. Try logging out and back in. Or email contact@tourguide.rmichels.com.')),
          );
        }
      }
    } else {
      logger.w("No user is currently signed in");
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Failed to delete account. Try logging out and back in. Or email contact@tourguide.rmichels.com.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //logger.t('FirebaseAuth.instance.currentUser=${FirebaseAuth.instance.currentUser}');
    myAuth.AuthProvider authProvider = Provider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
      ),
      body: SingleChildScrollView(
          child: StandardLayout(
        children: [
          const SizedBox(
            height: 0,
          ),
          Text("Confirm Account Deletion",
              style: Theme.of(context).textTheme.headlineSmall),
          Text(
              "Hey there!"
              "\n\n"
              'Before you go ahead and delete your account, just a heads-up: this action is permanent and cannot be undone. Deleting your account means all your personal information and contributions, like the tours you\'ve created and the ratings you\'ve left, will be permanently removed.'
              '\n\n'
              'We\'d hate to see you go, but if you\'re sure, hit that delete button. Just remember, once it\'s gone, it\'s gone for good!'
              '\n\n'
              'Keep exploring the world,'
              '\n'
              'Your Tourguide Team',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(
            height: 16,
          ),
          TextFormField(
            controller: _confirmFieldController,
            decoration: InputDecoration(
              labelText: 'Type "DELETE" to confirm',
              labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.error),
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
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                    )),
                child:
                    const Text("Permanently Delete Account and Contributions")),
          ),
        ],
      )),
    );
  }
}
