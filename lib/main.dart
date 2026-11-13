import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/services/settings.dart';
import 'features/game/application/providers.dart';
import 'features/game/data/firestore_backend.dart';
import 'features/game/data/switchable_backend.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    await Firebase.initializeApp(
      options: await DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instance;
    // Autenticación anónima: se entra a jugar sin registrarse.
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    // Intercambiable: Firestore normalmente; en memoria en el modo con bots.
    final backend = SwitchableBackend(
      FirestoreBackend(FirebaseFirestore.instance, auth),
    );
    runApp(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          backendProvider.overrideWithValue(backend),
        ],
        child: const AsesinoApp(),
      ),
    );
  } catch (e) {
    runApp(BootErrorApp(error: e.toString()));
  }
}
