/// Build-time configuration. Pass values with --dart-define (see docs/README.md).
/// Nothing secret lives here: Gemini / data.gov.in / service-account keys are
/// only in GitHub Actions secrets, never in the app.
class AppConfig {
  /// GitHub Pages base URL that serves /data/*.json (gh-pages branch).
  /// The release workflow passes `--dart-define=DATA_BASE_URL=` with an empty
  /// value when the optional repository variable is unset, which
  /// String.fromEnvironment does not replace with its default; treat empty as unset.
  static const _dataBaseUrlDefine = String.fromEnvironment('DATA_BASE_URL');
  static const dataBaseUrl = _dataBaseUrlDefine == ''
      ? 'https://maheshraikg.github.io/adike-rubber-dhara/'
      : _dataBaseUrlDefine;

  /// Repository hosting the pipeline (for the admin "Run now" link).
  static const _githubRepoDefine = String.fromEnvironment('GITHUB_REPO');
  static const githubRepo = _githubRepoDefine == '' ? 'maheshraikg/adike-rubber-dhara' : _githubRepoDefine;

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
