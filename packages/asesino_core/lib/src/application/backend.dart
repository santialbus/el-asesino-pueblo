import 'docs.dart';
import '../domain/actions.dart';

class RoomExistsException implements Exception {
  @override
  String toString() => 'La sala ya existe.';
}

class RoomNotFoundException implements Exception {
  @override
  String toString() => 'No existe ninguna sala con ese código.';
}

class RoomNotJoinableException implements Exception {
  RoomNotJoinableException(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

/// Otro dispositivo modificó el estado (p. ej. nuevo anfitrión).
class VersionConflictException implements Exception {
  @override
  String toString() => 'El estado de la sala cambió en otro dispositivo.';
}

class PermissionDeniedException implements Exception {
  PermissionDeniedException([this.detail = '']);
  final String detail;
  @override
  String toString() => 'Permiso denegado. $detail';
}

class QuotaExceededException implements Exception {
  @override
  String toString() =>
      'Se ha alcanzado el límite gratuito de Firebase. Inténtalo de nuevo más tarde.';
}

/// Escritura atómica del anfitrión: una transición completa de la partida.
class Commit {
  const Commit({
    required this.expectedVersion,
    required this.room,
    this.privates = const {},
    this.memberPatches = const {},
    this.deleteMembers = const [],
    this.hostState,
    this.deleteActions = const [],
    this.deleteVotes = const [],
  });

  /// Versión que el anfitrión cree vigente. Si no coincide => conflicto.
  final int expectedVersion;

  /// Documento de sala resultante. El backend fija `version = expected + 1`.
  final RoomDoc room;

  /// Documentos privados a escribir (uid -> doc).
  final Map<String, PrivateDoc> privates;

  /// Parches de campos sobre documentos de miembros (uid -> campos).
  final Map<String, Map<String, dynamic>> memberPatches;
  final List<String> deleteMembers;
  final HostStateDoc? hostState;
  final List<String> deleteActions;
  final List<String> deleteVotes;
}

/// Contrato con el almacén de datos. Implementaciones: Firestore (app) y
/// memoria (pruebas).
abstract class GameBackend {
  /// UID del usuario autenticado en este dispositivo.
  String get uid;

  Future<RoomDoc?> getRoom(String roomId);

  /// Crea la sala y al anfitrión como miembro. Lanza [RoomExistsException].
  Future<void> createRoom(RoomDoc room, MemberDoc host);

  /// Une al usuario a una sala en el lobby.
  Future<void> joinRoom(String roomId, MemberDoc me);

  /// Sale de la sala: en el lobby borra el miembro; en partida marca `left`.
  Future<void> leaveRoom(String roomId, {required bool inGame});

  Stream<RoomDoc?> watchRoom(String roomId);

  /// Últimos mensajes del chat (orden cronológico).
  Stream<List<ChatMessage>> watchChat(String roomId);

  /// Envía un mensaje al chat de la sala (lanza si no está permitido).
  Future<void> sendChat(String roomId, String text);

  Stream<List<MemberDoc>> watchMembers(String roomId);
  Stream<PrivateDoc?> watchPrivate(String roomId, String uid);

  /// Sólo anfitrión.
  Stream<List<ActionDoc>> watchActions(String roomId, int round);
  Stream<List<VoteDoc>> watchVotes(String roomId, int seq);
  Stream<Map<String, int>> watchPresence(String roomId);
  Future<HostStateDoc?> readHostState(String roomId);

  /// Escritura atómica del anfitrión. Devuelve la nueva versión.
  Future<int> commit(String roomId, Commit commit);

  /// Actualiza `online` en miembros (sin cambio de versión).
  Future<void> setOnline(String roomId, Map<String, bool> online);

  Future<void> submitAction(String roomId, NightAction action);
  Future<void> submitVote(String roomId, VoteDoc vote);

  /// Latido de presencia; el anfitrión además actualiza `hostHeartbeat`.
  Future<void> heartbeat(String roomId, {required bool asHost});

  /// Intenta tomar el rol de anfitrión si el actual lleva tiempo sin latir.
  /// Devuelve true si lo logra.
  Future<bool> claimHost(String roomId);

  Future<void> deleteRoom(String roomId);
}
