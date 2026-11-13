import 'package:asesino_core/asesino_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/services/settings.dart';

/// Backend de datos (Firestore). Se sobrescribe en `main()`.
final backendProvider = Provider<GameBackend>(
  (ref) =>
      throw UnimplementedError('backendProvider debe sobrescribirse en main()'),
);

final myUidProvider = Provider<String>((ref) => ref.watch(backendProvider).uid);

/// Música y vibración. Sigue los ajustes del usuario.
final audioProvider = Provider<AudioService>((ref) {
  final audio = AudioService();
  audio.applySettings(ref.read(settingsProvider));
  ref.listen<AppSettings>(settingsProvider, (_, s) => audio.applySettings(s));
  ref.onDispose(audio.dispose);
  return audio;
});

// Los listeners se cierran solos al salir de la sala (autoDispose): así se
// controla el consumo de lecturas en el plan Spark.
final roomProvider = StreamProvider.autoDispose.family<RoomDoc?, String>(
  (ref, code) => ref.watch(backendProvider).watchRoom(code),
);

final membersProvider = StreamProvider.autoDispose
    .family<List<MemberDoc>, String>(
      (ref, code) => ref.watch(backendProvider).watchMembers(code),
    );

final privateProvider = StreamProvider.autoDispose.family<PrivateDoc?, String>((
  ref,
  code,
) {
  final b = ref.watch(backendProvider);
  return b.watchPrivate(code, b.uid);
});
