import 'package:package_info_plus/package_info_plus.dart';
import 'package:tourguide_app/ui/my_layouts.dart';
import 'package:tourguide_app/ui/tts_settings.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:tourguide_app/utilities/providers/theme_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'package:tourguide_app/utilities/providers/auth_provider.dart' as myAuth;

class AppSettings extends StatefulWidget {
  const AppSettings({super.key});

  @override
  State<AppSettings> createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  bool _emailGeneralNotificationsEnabled = true;
  bool _emailReportsNotificationsEnabled = true;
  late bool _emailGeneralNotificationsEnabledInitialState = true;
  late bool _emailReportsNotificationsEnabledInitialState = true;
  bool _savingSettings = false;
  final List<String> themeList = <String>['System', 'Light', 'Dark'];
  late String initialThemeMode;
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    ThemeProvider themeProvider =
        Provider.of<ThemeProvider>(context, listen: false);
    initialThemeMode =
        themeProvider.themeMode.toString().split('.').last.capitalize();
    _loadSettings();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _loadSettings() async {
    TourguideUserProvider userProvider =
        Provider.of<TourguideUserProvider>(context, listen: false);
    setState(() {
      _emailGeneralNotificationsEnabled =
          !(userProvider.user!.emailSubscriptionsDisabled.contains('general'));
      _emailReportsNotificationsEnabled =
          !(userProvider.user!.emailSubscriptionsDisabled.contains('reports'));
      _emailGeneralNotificationsEnabledInitialState =
          _emailGeneralNotificationsEnabled;
      _emailReportsNotificationsEnabledInitialState =
          _emailReportsNotificationsEnabled;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _savingSettings = true;
    });
    TourguideUserProvider userProvider =
        Provider.of<TourguideUserProvider>(context, listen: false);
    userProvider.user!.setEmailSubscriptionEnabled(
        'general', !_emailGeneralNotificationsEnabled);
    userProvider.user!.setEmailSubscriptionEnabled(
        'reports', !_emailReportsNotificationsEnabled);
    await userProvider.updateUser(userProvider.user!);
    setState(() {
      _emailGeneralNotificationsEnabledInitialState =
          _emailGeneralNotificationsEnabled;
      _emailReportsNotificationsEnabledInitialState =
          _emailReportsNotificationsEnabled;
      _savingSettings = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated Notification Settings.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    TourguideUserProvider userProvider =
        Provider.of<TourguideUserProvider>(context);
    ThemeProvider themeProvider = Provider.of<ThemeProvider>(context);
    myAuth.AuthProvider authProvider = Provider.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: StandardLayout(
            children: [
              const SizedBox(height: 0),
              if (!authProvider.isAnonymous)
                Text("Notifications",
                    style: Theme.of(context).textTheme.titleLarge),
              if (!authProvider.isAnonymous)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Checkbox(
                        value: _emailGeneralNotificationsEnabled,
                        onChanged: (bool? value) {
                          setState(() {
                            _emailGeneralNotificationsEnabled = value ?? false;
                          });
                        },
                      ),
                      title: const Text('Receive general email notifications'),
                      onTap: () {
                        setState(() {
                          _emailGeneralNotificationsEnabled =
                              !_emailGeneralNotificationsEnabled;
                        });
                      },
                    ),
                    ListTile(
                      leading: Checkbox(
                        value: _emailReportsNotificationsEnabled,
                        onChanged: (bool? value) {
                          setState(() {
                            _emailReportsNotificationsEnabled = value ?? false;
                          });
                        },
                      ),
                      title: const Text(
                          'Receive email notifications when users report your tours'),
                      onTap: () {
                        setState(() {
                          _emailReportsNotificationsEnabled =
                              !_emailReportsNotificationsEnabled;
                        });
                      },
                    ),
                    ElevatedButton(
                      onPressed: _emailGeneralNotificationsEnabledInitialState !=
                                  _emailGeneralNotificationsEnabled ||
                              _emailReportsNotificationsEnabledInitialState !=
                                  _emailReportsNotificationsEnabled
                          ? _saveSettings
                          : null,
                      child: _savingSettings
                          ? const Text('Saving Notification Settings')
                          : const Text('Save Notification Settings'),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text("Theme", style: Theme.of(context).textTheme.titleLarge),
              DropdownMenu<String>(
                initialSelection: initialThemeMode,
                onSelected: (String? value) {
                  // This is called when the user selects an item.
                  String themeModeString = 'ThemeMode.${value!.toLowerCase()}';
                  themeProvider.setThemeModeWithString(themeModeString);
                },
                dropdownMenuEntries:
                    themeList.map<DropdownMenuEntry<String>>((String value) {
                  return DropdownMenuEntry<String>(value: value, label: value);
                }).toList(),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Text to Speech",
                      style: Theme.of(context).textTheme.titleLarge),
                  const TtsSettings(),
                ],
              ),
              const SizedBox(height: 16),
              Text("App Info", style: Theme.of(context).textTheme.titleLarge),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    'Tourguide v',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    _packageInfo.version,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    ', build ',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    _packageInfo.buildNumber,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
              const SizedBox(height: 0),
            ],
          ),
        ),
      ),
    );
  }
}
