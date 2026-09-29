/// Build-time configuration. Pass values with --dart-define (see docs/README.md).
/// Nothing secret lives here: Gemini / data.gov.in / service-account keys are
/// only in GitHub Actions secrets, never in the app.
class AppConfig {
  /// GitHub Pages base URL that serves /data/*.json (gh-pages branch).
  static const dataBaseUrl = String.fromEnvironment(
    'DATA_BASE_URL',
    defaultValue: 'https://maheshraikg.github.io/adike-rubber-dhara/',
  );

  /// Repository hosting the pipeline (for the admin "Run now" link).
  static const githubRepo = String.fromEnvironment(
    'GITHUB_REPO',
    defaultValue: 'maheshraikg/adike-rubber-dhara',
  );

  static const collectWorkflowFile = 'adike-collect.yml';

  static const contactEmail = String.fromEnvironment(
    'CONTACT_EMAIL',
    defaultValue: 'maheshraikg@gmail.com',
  );

  /// MET Norway requires an identifying User-Agent with contact info.
  static const userAgent = 'AdikeRubberDhara/1.0 (Android; $contactEmail)';

  static String get collectWorkflowUrl =>
      'https://github.com/$githubRepo/actions/workflows/$collectWorkflowFile';
}
