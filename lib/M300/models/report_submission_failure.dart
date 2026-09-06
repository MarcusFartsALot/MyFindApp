/// User-facing feedback only: never expose storage URLs or backend exceptions.
class ReportSubmissionFailure {
  const ReportSubmissionFailure(this.title, this.message);
  final String title;
  final String message;

  factory ReportSubmissionFailure.from(
    Object error, {
    required bool reportRequestStarted,
  }) {
    final details = error.toString().toLowerCase();
    final connection = [
      'socketexception',
      'clientexception',
      'failed host lookup',
      'network',
      'connection',
      'failed to fetch',
      'timeout',
      'timed out',
      'xmlhttprequest',
      'unreachable',
    ].any(details.contains);
    if (reportRequestStarted) {
      return ReportSubmissionFailure(
        'Submission not confirmed',
        '${connection ? 'The connection was interrupted.' : 'We could not confirm that your report was saved.'} Check your connection and look in Track Ticket before submitting again to avoid a duplicate. Your details and attachments are still here while this form stays open.',
      );
    }
    return ReportSubmissionFailure(
      connection ? 'Check your internet connection' : 'Report not submitted',
      '${connection ? 'We could not upload your evidence. Check your Wi-Fi or mobile data, then tap Submit Incident Report again.' : 'We could not prepare your report. Please try again. If this continues, contact support.'} Your details and attachments are still here while this form stays open.',
    );
  }
}
