import 'package:profanity_filter/profanity_filter.dart';
import 'package:tourguide_app/model/tourguide_report.dart';
import 'package:tourguide_app/ui/report_dialogue.dart';
import 'package:tourguide_app/utilities/custom_import.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TourguideUserProfileView extends StatefulWidget {
  final String tourguideUserId;
  final String tourguideUserDisplayName;

  const TourguideUserProfileView(
      {super.key,
      required this.tourguideUserId,
      required this.tourguideUserDisplayName});

  @override
  State<TourguideUserProfileView> createState() =>
      _TourguideUserProfileViewState();
}

class _TourguideUserProfileViewState extends State<TourguideUserProfileView> {
  @override
  Widget build(BuildContext context) {
    TourguideUserProvider tourguideUserProvider =
        Provider.of<TourguideUserProvider>(context);

    bool isCurrentUser =
        widget.tourguideUserId == tourguideUserProvider.user!.firebaseAuthId;

    void showReportDialog(BuildContext context) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return TourguideUserProfileViewReportOptions(
              tourguideUserId: widget.tourguideUserId);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tour Author'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 64.0, horizontal: 32),
              child: Text(
                widget.tourguideUserDisplayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (isCurrentUser)
              const Padding(
                padding: EdgeInsets.only(left: 8, right: 8, bottom: 32.0),
                child: Text('This is how other users see your profile.'),
              ),
            ProfileListButton(
              label: 'Block User',
              leftIcon: Icons.block,
              onPressed: () {},
              disabled: true, //isCurrentUser, //TODO
            ),
            ProfileListButton(
              label: 'Report User',
              leftIcon: Icons.report_outlined,
              onPressed: () => showReportDialog(context),
              disabled: isCurrentUser,
            ),
            ProfileListButton(
              label: 'What other options would you like to see here?',
              leftIcon: Icons.feedback_outlined,
              isLastItem: true,
              onPressed: () {
                launchUrl(Uri.parse(
                    "mailto:feedback@tourguide.rmichels.com?subject=Tourguide%20Tour%20Author%20Screen%20Feedback"));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class TourguideUserProfileViewReportOptions extends StatefulWidget {
  final String tourguideUserId;

  const TourguideUserProfileViewReportOptions(
      {super.key, required this.tourguideUserId});

  @override
  State<TourguideUserProfileViewReportOptions> createState() =>
      _TourguideUserProfileViewReportOptionsState();
}

//TODO: maybe find a better solution, state machine or something like that?
class _TourguideUserProfileViewReportOptionsState
    extends State<TourguideUserProfileViewReportOptions> {
  bool _reportSubmitted = false;
  String _selectedReportOption = '';
  final TextEditingController _reportDetailsController =
      TextEditingController();

  void _handleRadioValueChange(String? value) {
    setState(() {
      _selectedReportOption = value!;
    });
  }

  Future<void> _submitReport() async {
    if (_reportSubmitted) return;
    _reportSubmitted = true;
    String additionalDetails = _reportDetailsController.text;
    final filter = ProfanityFilter();
    additionalDetails = filter.censor(additionalDetails);
    logger.t('Selected Option: $_selectedReportOption');
    logger.t('Additional Details: $additionalDetails');

    final tourguideUserProvider =
        Provider.of<TourguideUserProvider>(context, listen: false);
    TourguideReport report = TourguideReport(
      title: _selectedReportOption,
      additionalDetails: additionalDetails,
      reportAuthorId: tourguideUserProvider.user!.firebaseAuthId,
    );

    setState(() {
      //TODO
      tourguideUserProvider.reportUser(report, widget.tourguideUserId);
    });

    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Thank You'),
          content: const Text(
              'Thank you for your report. We will review the user and take appropriate action if necessary.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report User'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            ReportDialogue(
              selectedReportOption: _selectedReportOption,
              onChanged: _handleRadioValueChange,
              reportDetailsController: _reportDetailsController,
              reportItem: 'user',
            )
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            setState(() {
              Navigator.of(context).pop();
            });
          },
        ),
        TextButton(
          onPressed: _selectedReportOption.isEmpty ? null : _submitReport,
          child: const Text('Submit Report'),
        ),
      ],
    );
  }
}
