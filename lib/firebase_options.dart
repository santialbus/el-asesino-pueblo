import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración de Firebase (proyecto `el-asesino-f0e55`).
///
/// Hoy sólo está registrada la app web. Para Android/iOS: registra las apps en
/// la consola de Firebase y ejecuta `flutterfire configure` (sobrescribe este
/// archivo). Estos valores NO son secretos: identifican el proyecto; lo que
/// protege los datos son las reglas de Firestore (`firestore.rules`).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Firebase sólo está configurado para web. Registra la app Android/iOS en '
      'la consola de Firebase y ejecuta `flutterfire configure`.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAYwEN8CxR9yc42RBauVkBM7iG05qxePRs',
    authDomain: 'el-asesino-f0e55.firebaseapp.com',
    projectId: 'el-asesino-f0e55',
    storageBucket: 'el-asesino-f0e55.firebasestorage.app',
    messagingSenderId: '319987433651',
    appId: '1:319987433651:web:e43f385df6f499271470c6',
  );
}
