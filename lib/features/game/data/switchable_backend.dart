import 'package:asesino_core/asesino_core.dart';

/// Backend intercambiable en caliente.
///
/// Normalmente delega en Firestore. Durante una partida local con bots
/// ([useLocal]) delega en el backend en memoria, de modo que **las mismas
/// pantallas y proveedores** funcionan sin tocar Firebase. Al terminar se
/// vuelve a Firestore con [useRemote].
class SwitchableBackend implements GameBackend {
  SwitchableBackend(this._remote) : _current = _remote;

  final GameBackend _remote;
  GameBackend _current;

  bool get isLocal => !identical(_current, _remote);

  void useLocal(GameBackend local) => _current = local;
  void useRemote() => _current = _remote;

  @override
  String get uid => _current.uid;

  @override
  Future<RoomDoc?> getRoom(String roomId) => _current.getRoom(roomId);

  @override
  Future<void> createRoom(RoomDoc room, MemberDoc host) =>
      _current.createRoom(room, host);

  @override
  Future<void> joinRoom(String roomId, MemberDoc me) =>
      _current.joinRoom(roomId, me);

  @override
  Future<void> leaveRoom(String roomId, {required bool inGame}) =>
      _current.leaveRoom(roomId, inGame: inGame);

  @override
  Stream<RoomDoc?> watchRoom(String roomId) => _current.watchRoom(roomId);

  @override
  Stream<List<MemberDoc>> watchMembers(String roomId) =>
      _current.watchMembers(roomId);

  @override
  Stream<PrivateDoc?> watchPrivate(String roomId, String uid) =>
      _current.watchPrivate(roomId, uid);

  @override
  Stream<List<ActionDoc>> watchActions(String roomId, int round) =>
      _current.watchActions(roomId, round);

  @override
  Stream<List<VoteDoc>> watchVotes(String roomId, int seq) =>
      _current.watchVotes(roomId, seq);

  @override
  Stream<Map<String, int>> watchPresence(String roomId) =>
      _current.watchPresence(roomId);

  @override
  Future<HostStateDoc?> readHostState(String roomId) =>
      _current.readHostState(roomId);

  @override
  Future<int> commit(String roomId, Commit commit) =>
      _current.commit(roomId, commit);

  @override
  Future<void> setOnline(String roomId, Map<String, bool> online) =>
      _current.setOnline(roomId, online);

  @override
  Future<void> submitAction(String roomId, NightAction action) =>
      _current.submitAction(roomId, action);

  @override
  Future<void> submitVote(String roomId, VoteDoc vote) =>
      _current.submitVote(roomId, vote);

  @override
  Future<void> heartbeat(String roomId, {required bool asHost}) =>
      _current.heartbeat(roomId, asHost: asHost);

  @override
  Future<bool> claimHost(String roomId) => _current.claimHost(roomId);

  @override
  Future<void> deleteRoom(String roomId) => _current.deleteRoom(roomId);
}
