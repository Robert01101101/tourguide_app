import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  bool _emailNotificationsEnabled = false; // State variable for checkbox
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    TourguideUserProvider userProvider = Provider.of<TourguideUserProvider>(context, listen: false);
    setState(() {
      _emailNotificationsEnabled = userProvider.user!.emailSubscribed;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _savingSettings = true;
    });
    TourguideUserProvider userProvider = Provider.of<TourguideUserProvider>(context, listen: false);
    await userProvider.updateUser(userProvider.user!.copyWith(emailSubscribed: _emailNotificationsEnabled));
    setState(() {
      _savingSettings = false;
    });
    if (mounted){
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated App Settings.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    TourguideUserProvider userProvider = Provider.of<TourguideUserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: StandardLayout(
        children: [
          const SizedBox(height: 0),
          Text("Notification Settings", style: Theme.of(context).textTheme.headlineSmall),
          ListTile(
            leading: Checkbox(
              value: _emailNotificationsEnabled,
              onChanged: (bool? value) {
                setState(() {
                  _emailNotificationsEnabled = value ?? false;
                });
              },
            ),
            title: const Text('Receive email notifications'),
            onTap: () {
              setState(() {
                _emailNotificationsEnabled = !_emailNotificationsEnabled;
              });
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: userProvider.user!.emailSubscribed != _emailNotificationsEnabled ? _saveSettings : null,
            child: _savingSettings ? const Text('Saving Settings') : const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}