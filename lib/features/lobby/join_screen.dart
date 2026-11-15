import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/settings.dart';
import '../../shared/widgets/backdrop.dart';
import '../../shared/widgets/controls.dart';
import '../../shared/widgets/page.dart';
import '../game/application/providers.dart';
import 'create_screen.dart' show friendlyError;

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.initialCode});

  /// Código recibido por enlace directo (`/#CODIGO`).
  final String? initialCode;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode ?? '',
  );
  late final TextEditingController _name = TextEditingController(
    text: ref.read(settingsProvider).playerName,
  );
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = RoomCodes.normalize(_code.text);
    final name = _name.text.trim();
    if (!RoomCodes.isValid(code)) {
      showMessage(context, 'El código tiene 6 caracteres (letras y números).');
      return;
    }
    if (name.isEmpty) {
      showMessage(context, 'Escribe tu nombre.');
      return;
    }
    setState(() => _busy = true);
    final backend = ref.read(backendProvider);
    try {
      await backend.joinRoom(
        code,
        MemberDoc(
          uid: backend.uid,
          name: name,
          joinedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      final s = ref.read(settingsProvider);
      ref.read(settingsProvider.notifier).update(s.copyWith(playerName: name));
      ref.read(sessionProvider.notifier).enter(code);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsesinoPage(
      title: 'Unirse a partida',
      scene: Scene.plain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 64),
          AsesinoField(
            controller: _code,
            label: 'Código de sala',
            maxLength: 6,
            caps: true,
            center: true,
            autofocus: true,
          ),
          const SizedBox(height: 14),
          AsesinoField(controller: _name, label: 'Tu nombre', maxLength: 20),
          const SizedBox(height: 28),
          GoldButton(
            label: _busy ? 'Entrando…' : 'Entrar',
            onPressed: _busy ? null : _join,
          ),
        ],
      ),
    );
  }
}
