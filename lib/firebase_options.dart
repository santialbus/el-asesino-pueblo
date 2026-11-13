import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración de Firebase (proyecto `el-asesino-f0e55`).
class DefaultFirebaseOptions {
  static Future<FirebaseOptions> get currentPlatform async {
    if (kIsWeb)
      return web; // Ahora llamará al getter que lee de dotenv con éxito

    throw UnsupportedError(
      'Firebase sólo está configurado para web. Registra la app Android/iOS en '
      'la consola de Firebase y ejecuta `flutterfire configure`.',
    );
  }

  // 2. Se convierte en getter para que lea las variables EN EL MOMENTO de ser consultado
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    ),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
  );
}
