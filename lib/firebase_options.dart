import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static Future<FirebaseOptions> get currentPlatform async {
    if (!kIsWeb) {
      throw UnsupportedError(
        'Firebase sólo está configurado para web.',
      );
    }

    const requiredValues = {
      'FIREBASE_API_KEY': String.fromEnvironment('FIREBASE_API_KEY'),
      'FIREBASE_AUTH_DOMAIN': String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      'FIREBASE_PROJECT_ID': String.fromEnvironment('FIREBASE_PROJECT_ID'),
      'FIREBASE_STORAGE_BUCKET':
          String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      'FIREBASE_MESSAGING_SENDER_ID':
          String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      'FIREBASE_APP_ID': String.fromEnvironment('FIREBASE_APP_ID'),
    };

    final missing = requiredValues.entries
        .where((entry) => entry.value.isEmpty)
        .map((entry) => entry.key)
        .toList();

    if (missing.isNotEmpty) {
      throw StateError(
        'Faltan variables de Firebase: ${missing.join(', ')}',
      );
    }

    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
  );
}
