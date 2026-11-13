import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración de Firebase (proyecto `el-asesino-f0e55`).
class DefaultFirebaseOptions {
  static Future<FirebaseOptions> get currentPlatform async {
    // 1. Cargamos el .env asegurándonos de que esté listo
    await dotenv.load(fileName: ".env");

    if (kIsWeb)
      return web; // Ahora llamará al getter que lee de dotenv con éxito

    throw UnsupportedError(
      'Firebase sólo está configurado para web. Registra la app Android/iOS en '
      'la consola de Firebase y ejecuta `flutterfire configure`.',
    );
  }

  // 2. Se convierte en getter para que lea las variables EN EL MOMENTO de ser consultado
  static FirebaseOptions get web => FirebaseOptions(
        apiKey: dotenv.get('FIREBASE_API_KEY'),
        authDomain: dotenv.get('FIREBASE_AUTH_DOMAIN'),
        projectId: dotenv.get('FIREBASE_PROJECT_ID'),
        storageBucket: dotenv.get('FIREBASE_STORAGE_BUCKET'),
        messagingSenderId: dotenv.get('FIREBASE_MESSAGING_SENDER_ID'),
        appId: dotenv.get('FIREBASE_APP_ID'),
      );
}
