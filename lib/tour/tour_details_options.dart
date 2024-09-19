import 'dart:async';
import 'package:flutter/material.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:provider/provider.dart';
import 'package:tourguide_app/model/tour.dart';
import 'package:tourguide_app/model/tourguide_report.dart';
import 'package:tourguide_app/model/tourguide_user.dart';
import 'package:tourguide_app/ui/report_dialogue.dart';
import 'package:tourguide_app/utilities/providers/tour_provider.dart';
import 'package:tourguide_app/utilities/providers/tourguide_user_provider.dart';
import '../utilities/custom_import.dart';

class TourDetailsOptions extends StatefulWidget {
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;
  final Tour tour;

  TourDetailsOptions({
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.tour,
  });

  @override
  State<TourDetailsOptions> createState() => _TourDetailsOptionsState();
}

//TODO: maybe find a better solution, state machine or something like that?
class _TourDetailsOptionsState extends State<TourDetailsOptions> {
  bool _isConfirmingDelete = false;
  bool _isReportingTour = false;
  bool _isViewingReports = false;
  bool _isRequestingReview = false;
  bool _isDeleteConfirmChecked = false;
  bool _isRequestReviewChecked = false;
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
    //censor details with profanity_filter
    final filter = ProfanityFilter();
    additionalDetails = filter.censor(additionalDetails);

    logger.t('Selected Option: $_selectedReportOption');
    logger.t('Additional Details: $additionalDetails');

    final tourguideUserProvider =
        Provider.of<TourguideUserProvider>(context, listen: false);
    TourguideReport report = TourguideReport(
      title: _selectedReportOption,
      additionalDetails: additionalDetails,
      reportAuthorId: tourguideUserProvider.user != null ? tourguideUserProvider.user!.firebaseAuthId : 'Anonymous',
    );
    //TODO: dont use context across async calls
    final TourguideUser? reportAuthor =
        await tourguideUserProvider.getUserInfo(widget.tour.authorId);
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    setState(() {
      tourProvider.reportTour(widget.tour, report, reportAuthor!);
    });

    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Thank You'),
          content: const Text(
              'Thank you for your report. We will review the content and take appropriate action if necessary.'),
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

  Future<void> _requestReview() async {
    logger.i('_requestReview()');

    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    tourProvider.requestReviewOfTour(widget.tour);

    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tour under Review'),
          content: const Text(
              'Thank you for submitting your request for review. We will review the content and remove the reports if we deem the content to be in compliance with our community guidelines.'),
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
    final tourProvider = Provider.of<TourProvider>(context);
    bool isAuthor = tourProvider.isUserCreatedTour(widget.tour);
    return AlertDialog(
      title: Text(isAuthor
          ? (!_isConfirmingDelete
              ? (!_isViewingReports
                  ? (!_isRequestingReview
                      ? 'Author Options'
                      : 'Request a Review')
                  : 'Reports')
              : 'Delete Tour')
          : (!_isReportingTour ? 'Options' : 'Report Tour')),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Visibility(
              //Main Options
              visible: !_isConfirmingDelete &&
                  !_isReportingTour &&
                  !_isViewingReports &&
                  !_isRequestingReview,
              child: Column(
                children: [
                  if (isAuthor)
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("You\'re the author of this tour."),
                              const SizedBox(height: 8.0),
                              if (widget.tour.reports.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(),
                                    const SizedBox(height: 8.0),
                                    Text("Your tour was reported!",
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium!
                                            .copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error)),
                                    if (widget
                                        .tour.requestReviewStatus.isNotEmpty)
                                      Column(
                                        children: [
                                          const SizedBox(height: 8.0),
                                          Text(
                                            "You have requested a review, but we have not yet reviewed the reports.",
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium!
                                                .copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 8.0),
                                    const Text(
                                        "There are reports for your tour, and it may be in violation of our community guidelines. Please review the reports and take appropriate action. In the meantime this tour is only visible to you."),
                                    const SizedBox(height: 8.0),
                                    const Text(
                                        "If you believe you have addressed the reported issues, or that the reports are in error, you can request a review of your tour by selecting View Reports."),
                                    const SizedBox(height: 8.0),
                                    Align(
                                      alignment: Alignment.center,
                                      child: ElevatedButton.icon(
                                        onPressed: () => setState(() {
                                          _isViewingReports = true;
                                        }),
                                        icon: const Icon(Icons.report_outlined),
                                        label: const Text("View Reports"),
                                      ),
                                    ),
                                    const Divider(),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: widget.onEditPressed,
                          icon: const Icon(Icons.edit),
                          label: const Text("Edit Tour"),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isConfirmingDelete = true;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            //backgroundColor: Theme.of(context).colorScheme.error, // Background color of the button
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .error, // Text color
                            side: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                                width: 2),
                          ),
                          icon: const Icon(Icons.delete),
                          label: const Text("Delete Tour"),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isReportingTour = true;
                            });
                          },
                          icon: const Icon(Icons.report),
                          label: const Text("Report Tour"),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Visibility(
              //Delete Confirmation Options
              visible: _isConfirmingDelete,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                        child: Text(
                            "Are you sure you'd like to delete this tour? This action cannot be undone.")),
                  ),
                  CheckboxListTile(
                    title: const Text("Confirm Delete"),
                    value: _isDeleteConfirmChecked,
                    onChanged: (bool? value) {
                      setState(() {
                        _isDeleteConfirmChecked = value ?? false;
                      });
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isDeleteConfirmChecked = false;
                        _isConfirmingDelete = false;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Cancel"),
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        _isDeleteConfirmChecked ? widget.onDeletePressed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .error, // Background color of the button
                      foregroundColor: Colors.white, // Text color
                    ),
                    icon: const Icon(Icons.delete),
                    label: const Text("Delete Tour Permanently"),
                  ),
                ],
              ),
            ),
            Visibility(
              //Report Options
              visible: _isReportingTour,
              child: ReportDialogue(
                selectedReportOption: _selectedReportOption,
                onChanged: _handleRadioValueChange,
                reportDetailsController: _reportDetailsController,
                reportItem: 'tour',
              ),
            ),
            Visibility(
              //Viewing Reports
              visible: _isViewingReports && !_isRequestingReview,
              child: Column(
                children: [
                  Column(
                    children: widget.tour.reports.map((report) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Card(
                          child: ListTile(
                            title: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(report.title),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(report.additionalDetails),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 8.0),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isViewingReports = false;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Back"),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isRequestingReview = true;
                      });
                    },
                    icon: const Icon(Icons.account_balance),
                    label: const Text("Request a Review"),
                  ),
                ],
              ),
            ),
            Visibility(
              //Requesting Review
              visible: _isRequestingReview,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                        child: Text(
                            "Please only request a review of your tour once you have addressed the reported issues, or if you believe the reports are in error. Our team will review the reports and take appropriate action if necessary.")),
                  ),
                  CheckboxListTile(
                    title: const Text("Confirm Request"),
                    value: _isRequestReviewChecked,
                    onChanged: (bool? value) {
                      setState(() {
                        _isRequestReviewChecked = value ?? false;
                      });
                    },
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isRequestReviewChecked = false;
                        _isRequestingReview = false;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text("Cancel"),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isRequestReviewChecked ? _requestReview : null,
                    icon: const Icon(Icons.account_balance),
                    label: const Text("Request Review"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: !_isReportingTour
          ? null
          : [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  setState(() {
                    _isReportingTour = false;
                  });
                },
              ),
              TextButton(
                child: Text('Submit Report'),
                onPressed: _selectedReportOption.isEmpty ? null : _submitReport,
              ),
            ],
    );
  }
}
