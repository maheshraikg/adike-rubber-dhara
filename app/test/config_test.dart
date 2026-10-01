import 'package:adike_dhara/config.dart';
import 'package:flutter_test/flutter_test.dart';

// Run in CI with `--dart-define=DATA_BASE_URL=` (empty) as the release build does
// when the optional variable is unset: the app must still use the real address.
void main() {
  test('data address is never empty', () {
    expect(AppConfig.dataBaseUrl, startsWith('https://'));
    expect(AppConfig.githubRepo, contains('/'));
  });
}
