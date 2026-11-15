import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/settings.dart';
import '../features/game/presentation/room_screen.dart';
import '../features/home/home_screen.dart';
import '../features/lobby/join_screen.dart';
import 'theme.dart';

class AsesinoApp extends ConsumerStatefulWidget {
  const AsesinoApp({super.key, this.joinCode});

  /// Código leído del enlace directo (`https://…/#ABC234`), si lo había.
  final String? joinCode;

  @override
  ConsumerState<AsesinoApp> createState() => _AsesinoAppState();
}

class _AsesinoAppState extends ConsumerState<AsesinoApp> {
  final GlobalKey<NavigatorState> _nav = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    final code = widget.joinCode;
    if (code != null) {
      // Tras el primer frame, abre «Unirse» con el código ya escrito. Si ya
      // estabas en esa sala (sesión guardada) no hace falta.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(sessionProvider) == code) return;
        _nav.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => JoinScreen(initialCode: code),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si hay una sala guardada, se intenta recuperar la sesión al abrir la app.
    final saved = ref.watch(sessionProvider);
    return MaterialApp(
      title: 'El Asesino — El Pueblo Duerme',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: _nav,
      // Ruta fija: evita que Flutter interprete el `#CODIGO` de la URL como ruta.
      initialRoute: '/',
      home: saved == null ? const HomeScreen() : RoomScreen(code: saved),
    );
  }
}

/// Pantalla de error de arranque (p. ej. Firebase no configurado).
class BootErrorApp extends StatelessWidget {
  const BootErrorApp({super.key, required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NO SE PUDO INICIAR',
                    style: AppText.title(20, color: AppColors.danger),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Comprueba tu conexión y que en Firebase estén activados '
                    'Authentication (acceso anónimo) y Cloud Firestore.',
                    textAlign: TextAlign.center,
                    style: AppText.body(15),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    error,
                    style: AppText.body(12, color: AppColors.text2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
