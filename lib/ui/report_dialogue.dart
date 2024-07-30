import 'package:flutter/material.dart';

class ReportDialogue extends StatelessWidget {
  final String reportItem;
  final String selectedReportOption;
  final ValueChanged<String?> onChanged;
  final TextEditingController reportDetailsController;

  const ReportDialogue({
    Key? key,
    required this.reportItem,
    required this.selectedReportOption,
    required this.onChanged,
    required this.reportDetailsController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(child: Text("Please select the reason why you are reporting this $reportItem. Your feedback is important to us and will help us maintain a safe and respectful community.")),
        ),
        Divider(),
        SizedBox(height: 16.0),
        ReportOption(
          title: 'Nudity or Sexual Content',
          description: 'Contains nudity, sexual activity, or other sexually explicit material.',
          groupValue: selectedReportOption,
          onChanged: onChanged,
        ),
        ReportOption(
          title: 'Violence or Dangerous Behavior',
          description: 'Promotes violence, self-harm, or dangerous behavior.',
          groupValue: selectedReportOption,
          onChanged: onChanged,
        ),
        ReportOption(
          title: 'Harassment or Hate Speech',
          description: 'Includes harassment, hate speech, or abusive content.',
          groupValue: selectedReportOption,
          onChanged: onChanged,
        ),
        ReportOption(
          title: 'Spam or Misleading Information',
          description: 'Contains spam, scams, or misleading information.',
          groupValue: selectedReportOption,
          onChanged: onChanged,
        ),
        ReportOption(
          title: 'Copyright Infringement',
          description: 'Violates copyright laws or includes pirated content.',
          groupValue: selectedReportOption,
          onChanged: onChanged,
        ),
        ReportOption(
          title: 'Harmful or Abusive Content',
          description: 'Contains harmful, abusive, or malicious content.',
          groupValue: selectedReportOption,
          onChanged: onChanged,
        ),
        ReportOption(
          title: 'Illegal Activities',
          description: 'Promotes or involves illegal activities.',
          groupValue: selectedReportOption,
          onChanged: onChanged,
        ),
        ReportOption(
          title: 'Other',
          description: 'Other reasons not listed above.',
          groupValue: selectedReportOption,
          onChanged: onChanged,
        ),
        TextField(
          controller: reportDetailsController,
          decoration: InputDecoration(labelText: 'Additional details (optional)'),
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
        ),
      ],
    );
  }
}

class ReportOption extends StatelessWidget {
  final String title;
  final String description;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  ReportOption({required this.title, required this.description, required this.groupValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioListTile(
          title: Text(title),
          subtitle: Text(description),
          value: title,
          groupValue: groupValue,
          onChanged: onChanged,
        ),
        Divider(),
      ],
    );
  }
}