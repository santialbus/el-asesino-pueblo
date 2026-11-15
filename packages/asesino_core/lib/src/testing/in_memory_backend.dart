import 'dart:async';

import '../application/backend.dart';
import '../application/docs.dart';
import '../domain/actions.dart';
import '../domain/enums.dart';

/// Reloj falso compartido por servidor, anfitrión y bots en las pruebas.
class FakeClock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 11, 10, 12);
  DateTime _now;
  DateTime now() => _now;
  int get ms => _now.millisecondsSinceEpoch;
  void advance(Duration d) => _now = _now.add(d);
}

/// Reloj de pared real con la misma interfaz que [FakeClock]. Se usa para
/// partidas locales (modo con bots) donde el tiempo sí transcurre.
class RealClock extends FakeClock {
  RealClock() : super(DateTime.now());
  @override
  DateTime now() => DateTime.now();
  @override
  int get ms => DateTime.now().millisecondsSinceEpoch;
  @override
  void advance(Duration d) {}
}

class _RoomData {
  _RoomData(this.doc, this.heartbeatMs);
  RoomDoc doc;
  int heartbeatMs;
  final Map<String, MemberDoc> members = {};
  final Map<String, PrivateDoc> privates = {};
  HostStateDoc? hostState;
  final Map<String, NightAction> actions = {};
  final Map<String, VoteDoc> votes = {};
  final Map<String, int> presence = {};
  final List<ChatMessage> chat = [];
  int chatSeq = 0;
  final StreamController<void> changes = StreamController.broadcast(sync: false);
}

/// "Servidor" compartido por varios [InMemoryBackend] (uno por jugador).
/// Emula las Security Rules: lecturas privadas, acciones create-only,
/// control de fase, versión y caducidad del anfitrión.
class InMemoryServer {
  InMemoryServer(this.clock);
  final FakeClock clock;
  final Map<String, _RoomData> _rooms = {};

  /// Segundos sin latido tras los cuales otro jugador puede tomar el control.
  static const hostStaleSeconds = 45;

  InMemoryBackend client(String uid) => InMemoryBackend._(this, uid);

  /// Acceso directo para aserciones de prueba.
  RoomDoc? roomDoc(String id) => _rooms[id]?.doc;
  Map<String, MemberDoc> membersOf(String id) => Map.of(_rooms[id]!.members);
  Map<String, PrivateDoc> privatesOf(String id) => Map.of(_rooms[id]!.privates);
  int actionCount(String id) => _rooms[id]!.actions.length;
  int chatCount(String id) => _rooms[id]!.chat.length;
  int voteCount(String id) => _rooms[id]!.votes.length;
  bool exists(String id) => _rooms.containsKey(id);
}

class InMemoryBackend implements GameBackend {
  InMemoryBackend._(this._server, this.uid);
  final InMemoryServer _server;
  @override
  final String uid;

  _RoomData _room(String id) {
    final r = _server._rooms[id];
    if (r == null) throw RoomNotFoundException();
    return r;
  }

  bool _isHost(_RoomData r) => r.doc.hostUid == uid;
  bool _isMember(_RoomData r) => r.members.containsKey(uid);
  void _changed(_RoomData r) => r.changes.add(null);

  Stream<T> _watch<T>(String roomId, T Function(_RoomData r) project) {
    final r = _server._rooms[roomId];
    if (r == null) return Stream.error(RoomNotFoundException());
    return Stream.multi((c) {
      String? last;
      void emit() {
        final v = project(r);
        final key = _key(v);
        if (key == last) return;
        last = key;
        c.add(v);
      }

      emit();
      final sub = r.changes.stream.listen((_) => emit());
      c.onCancel = sub.cancel;
    });
  }

  static String _key(Object? v) {
    if (v == null) return 'null';
    if (v is RoomDoc) return v.toMap().toString() + v.hostHeartbeatMs.toString();
    if (v is MemberDoc) return v.toMap().toString();
    if (v is ChatMessage) return '${v.id}${v.text}';
    if (v is PrivateDoc) return v.toMap().toString();
    if (v is List) return v.map(_key).join('|');
    if (v is Map) return v.toString();
    if (v is ActionDoc) return v.action.toMap().toString();
    if (v is VoteDoc) return v.toMap().toString();
    return v.toString();
  }

  // ------------------------------------------------------------- salas

  @override
  Future<RoomDoc?> getRoom(String roomId) async {
    final r = _server._rooms[roomId];
    return r == null ? null : _withBeat(r);
  }

  RoomDoc _withBeat(_RoomData r) => r.doc.copyWith(hostHeartbeatMs: r.heartbeatMs);

  @override
  Future<void> createRoom(RoomDoc room, MemberDoc host) async {
    if (_server._rooms.containsKey(room.code)) throw RoomExistsException();
    if (room.hostUid != uid || host.uid != uid) throw PermissionDeniedException('create');
    if (room.phase != Phase.lobby || room.version != 1) {
      throw PermissionDeniedException('Estado inicial inválido.');
    }
    final r = _RoomData(room, _server.clock.ms);
    r.members[uid] = host;
    _server._rooms[room.code] = r;
  }

  @override
  Future<void> joinRoom(String roomId, MemberDoc me) async {
    final r = _room(roomId);
    if (r.members.containsKey(uid)) return; // reentrada
    if (r.doc.phase != Phase.lobby) {
      throw RoomNotJoinableException('La partida ya ha empezado.');
    }
    if (me.uid != uid || !me.alive) throw PermissionDeniedException('join');
    r.members[uid] = me;
    _changed(r);
  }

  @override
  Future<void> leaveRoom(String roomId, {required bool inGame}) async {
    final r = _room(roomId);
    if (!_isMember(r)) return;
    if (inGame) {
      r.members[uid] = r.members[uid]!.copyWith(left: true);
    } else {
      r.members.remove(uid);
    }
    _changed(r);
  }

  // ----------------------------------------------------------- lecturas

  @override
  Stream<RoomDoc?> watchRoom(String roomId) => _watch(roomId, _withBeat);

  @override
  Stream<List<ChatMessage>> watchChat(String roomId) {
    final r = _server._rooms[roomId];
    if (r == null) return Stream.error(RoomNotFoundException());
    if (!_isMember(r) && !_isHost(r)) {
      return Stream.error(PermissionDeniedException('chat'));
    }
    return _watch(roomId, (r) {
      final all = r.chat;
      return all.length > 60 ? all.sublist(all.length - 60) : List<ChatMessage>.of(all);
    });
  }

  @override
  Future<void> sendChat(String roomId, String text) async {
    final r = _room(roomId);
    final m = r.members[uid];
    if (m == null) throw PermissionDeniedException('no eres miembro');
    if (ChatMessage.validateText(text) != null) throw PermissionDeniedException('mensaje no válido');
    if (!ChatMessage.canWrite(r.doc.phase, alive: m.alive)) {
      throw PermissionDeniedException('chat cerrado para ti en esta fase');
    }
    r.chat.add(ChatMessage(
      id: 'm${++r.chatSeq}',
      uid: uid,
      name: m.name,
      text: text.trim(),
      tsMs: _server.clock.ms,
    ));
    _changed(r);
  }

  @override
  Stream<List<MemberDoc>> watchMembers(String roomId) {
    final r = _server._rooms[roomId];
    if (r == null) return Stream.error(RoomNotFoundException());
    if (!_isMember(r) && !_isHost(r)) {
      return Stream.error(PermissionDeniedException('members'));
    }
    return _watch(roomId, (r) => r.members.values.toList());
  }

  @override
  Stream<PrivateDoc?> watchPrivate(String roomId, String target) {
    final r = _server._rooms[roomId];
    if (r == null) return Stream.error(RoomNotFoundException());
    if (target != uid && !_isHost(r)) {
      return Stream.error(PermissionDeniedException('private'));
    }
    return _watch(roomId, (r) => r.privates[target]);
  }

  @override
  Stream<List<ActionDoc>> watchActions(String roomId, int round) {
    final r = _server._rooms[roomId];
    if (r == null) return Stream.error(RoomNotFoundException());
    if (!_isHost(r)) return Stream.error(PermissionDeniedException('actions'));
    return _watch(roomId, (r) => [
          for (final a in r.actions.values)
            if (a.round == round) ActionDoc(a)
        ]);
  }

  @override
  Stream<List<VoteDoc>> watchVotes(String roomId, int seq) {
    final r = _server._rooms[roomId];
    if (r == null) return Stream.error(RoomNotFoundException());
    if (!_isHost(r)) return Stream.error(PermissionDeniedException('votes'));
    return _watch(roomId, (r) => [
          for (final v in r.votes.values)
            if (v.seq == seq) v
        ]);
  }

  @override
  Stream<Map<String, int>> watchPresence(String roomId) {
    final r = _server._rooms[roomId];
    if (r == null) return Stream.error(RoomNotFoundException());
    if (!_isHost(r)) return Stream.error(PermissionDeniedException('presence'));
    return _watch(roomId, (r) => Map<String, int>.of(r.presence));
  }

  @override
  Future<HostStateDoc?> readHostState(String roomId) async {
    final r = _room(roomId);
    if (!_isHost(r)) throw PermissionDeniedException('hostState');
    return r.hostState;
  }

  // ---------------------------------------------------------- escrituras

  @override
  Future<int> commit(String roomId, Commit c) async {
    final r = _room(roomId);
    if (!_isHost(r)) throw VersionConflictException(); // ya no es anfitrión
    if (r.doc.version != c.expectedVersion) throw VersionConflictException();
    final newVersion = c.expectedVersion + 1;
    r.doc = c.room.copyWith(hostUid: r.doc.hostUid, version: newVersion);
    c.privates.forEach((u, p) => r.privates[u] = p);
    c.memberPatches.forEach((u, patch) {
      final m = r.members[u];
      if (m == null) return;
      r.members[u] = MemberDoc.fromMap({...m.toMap(), ...patch});
    });
    for (final u in c.deleteMembers) {
      r.members.remove(u);
    }
    if (c.hostState != null) r.hostState = c.hostState;
    for (final id in c.deleteActions) {
      r.actions.removeWhere((k, a) => '${a.round}_${a.uid}' == id);
    }
    for (final id in c.deleteVotes) {
      r.votes.removeWhere((k, v) => v.id == id);
    }
    _changed(r);
    return newVersion;
  }

  @override
  Future<void> setOnline(String roomId, Map<String, bool> online) async {
    final r = _room(roomId);
    if (!_isHost(r)) throw PermissionDeniedException('setOnline');
    online.forEach((u, v) {
      final m = r.members[u];
      if (m != null) r.members[u] = m.copyWith(online: v);
    });
    _changed(r);
  }

  @override
  Future<void> submitAction(String roomId, NightAction a) async {
    final r = _room(roomId);
    final m = r.members[uid];
    final id = '${a.round}_${a.uid}';
    if (m == null || !m.alive) throw PermissionDeniedException('no eres miembro vivo');
    if (a.uid != uid) throw PermissionDeniedException('uid');
    if (r.doc.phase != Phase.night || a.round != r.doc.round) {
      throw PermissionDeniedException('fase');
    }
    if (a.role != r.doc.nightStep) throw PermissionDeniedException('no es tu turno');
    if (r.privates[uid]?.role != a.role) throw PermissionDeniedException('rol');
    if (a.targets.length > 2) throw PermissionDeniedException('objetivos');
    if (r.actions.values.any((x) => '${x.round}_${x.uid}' == id)) {
      throw PermissionDeniedException('acción duplicada');
    }
    r.actions[id] = a;
    _changed(r);
  }

  @override
  Future<void> submitVote(String roomId, VoteDoc v) async {
    final r = _room(roomId);
    final m = r.members[uid];
    if (m == null || !m.alive) throw PermissionDeniedException('no eres miembro vivo');
    if (v.uid != uid) throw PermissionDeniedException('uid');
    if (r.doc.phase != Phase.voting || v.seq != r.doc.voteSeq) {
      throw PermissionDeniedException('fase');
    }
    if (r.votes.containsKey(v.id)) throw PermissionDeniedException('voto duplicado');
    r.votes[v.id] = v;
    _changed(r);
  }

  @override
  Future<void> heartbeat(String roomId, {required bool asHost}) async {
    final r = _room(roomId);
    if (!_isMember(r)) throw PermissionDeniedException('heartbeat');
    r.presence[uid] = _server.clock.ms;
    if (asHost) {
      if (!_isHost(r)) throw PermissionDeniedException('heartbeat host');
      r.heartbeatMs = _server.clock.ms;
    }
    _changed(r);
  }

  @override
  Future<bool> claimHost(String roomId) async {
    final r = _room(roomId);
    if (!_isMember(r)) return false;
    if (_isHost(r)) return true;
    final stale = _server.clock.ms - r.heartbeatMs > InMemoryServer.hostStaleSeconds * 1000;
    if (!stale) return false;
    r.doc = r.doc.copyWith(hostUid: uid, version: r.doc.version + 1);
    r.heartbeatMs = _server.clock.ms;
    _changed(r);
    return true;
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    final r = _room(roomId);
    if (!_isHost(r)) throw PermissionDeniedException('delete');
    _server._rooms.remove(roomId);
    await r.changes.close();
  }
}
