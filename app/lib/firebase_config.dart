import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase client config (public identifiers, not secrets — access is
/// controlled by firestore.rules). Supplied with --dart-define so the repo
/// holds no project ids. Alternatively run `flutterfire configure` and replace
/// this with the generated firebase_options.dart.
class FirebaseConfig {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');

  static bool get isConfigured =>
      _projectId.isNotEmpty &&
      _senderId.isNotEmpty &&
      (kIsWeb ? _webAppId.isNotEmpty : _androidAppId.isNotEmpty) &&
      (_apiKey.isNotEmpty || _webApiKey.isNotEmpty);

  static FirebaseOptions get options => FirebaseOptions(
        apiKey: kIsWeb && _webApiKey.isNotEmpty ? _webApiKey : _apiKey,
        appId: kIsWeb ? _webAppId : _androidAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        authDomain: '$_projectId.firebaseapp.com',
      );
}
