
class TourguideReport {
 final String title;
 final String additionalDetails;
 final String reportAuthorId;

  TourguideReport({
    required this.title,
    required this.additionalDetails,
    required this.reportAuthorId,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'additionalDetails': additionalDetails,
      'reportAuthorId': reportAuthorId,
    };
  }

 factory TourguideReport.fromMap(Map<String, dynamic> data) {
   return TourguideReport(
     title: data['title'],
     additionalDetails: data['additionalDetails'],
     reportAuthorId: data['reportAuthorId'],
   );
 }

  TourguideReport copyWith({
    String? title,
    String? additionalDetails,
    String? reportAuthorId,
  }) {
    return TourguideReport(
      title: title ?? this.title,
      additionalDetails: additionalDetails ?? this.additionalDetails,
      reportAuthorId: reportAuthorId ?? this.reportAuthorId,
    );
  }

  @override
  String toString() {
    return 'TourguideReport(title: $title, additionalDetails: $additionalDetails, reportAuthorId: $reportAuthorId)';
  }
}
