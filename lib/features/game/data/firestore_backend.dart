import 'dart:async';

import 'package:asesino_core/asesino_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Implementación de [GameBackend] sobre Cloud Firestore (plan Spark).
///
/// Estructura:
/// ```
/// rooms/{code}                      público (sin secretos)
/// rooms/{code}/members/{uid}        jugadores
/// rooms/{code}/presence/{uid}       latidos (sólo lee el anfitrión)
/// rooms/{code}/private/{uid}        rol secreto (dueño y anfitrión)
/// rooms/{code}/hostState/state      copia para recuperación (anfitrión)
/// rooms/{code}/actions/{round_uid}  acciones nocturnas (create-only)
/// rooms/{code}/votes/{seq_uid}      votos (create-only)
/// rooms/{code}/chat/{id}            mensajes de chat
/// ```
///
/// Todos los documentos llevan `expireAt` (Timestamp) para la política TTL de
/// Firestore, que borra las salas abandonadas (ver docs/TTL.md).
class FirestoreBackend implements GameBackend {
  FirestoreBackend(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Caducidad de la sala (se renueva en cada transición del anfitrión) y de
  /// sus documentos auxiliares.
  static const Duration _roomTtl = Duration(hours: 24);
  static const Duration _subTtl = Duration(hours: 48);
  static Timestamp _expire(Duration d) =>
      Timestamp.fromDate(DateTime.now().add(d));

  @override
  String get uid {
    final u = _auth.currentUser;
    if (u == null)
      throw StateError('Sin sesión: la autenticación anónima no está lista.');
    return u.uid;
  }

  DocumentReference<Map<String, dynamic>> _room(String id) =>
      _db.collection('rooms').doc(id);
  CollectionReference<Map<String, dynamic>> _col(String id, String name) =>
      _room(id).collection(name);

  static int _ms(Object? ts) => ts is Timestamp ? ts.millisecondsSinceEpoch : 0;

  RoomDoc _parseRoom(Map<String, dynamic> data) =>
      RoomDoc.fromMap(data, hostHeartbeatMs: _ms(data['hostHeartbeat']));

  /// Traduce errores de Firebase a excepciones comprensibles.
  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          throw PermissionDeniedException(e.message ?? '');
        case 'resource-exhausted':
          throw QuotaExceededException();
        case 'aborted':
          throw VersionConflictException();
        default:
          rethrow;
      }
    }
  }

  Stream<T> _guardStream<T>(Stream<T> s) => s.handleError((Object e) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied')
        throw PermissionDeniedException(e.message ?? '');
      if (e.code == 'resource-exhausted') throw QuotaExceededException();
    }
    throw e;
  });

  // ------------------------------------------------------------------ salas

  @override
  Future<RoomDoc?> getRoom(String roomId) => _guard(() async {
    final s = await _room(roomId).get();
    final d = s.data();
    return d == null ? null : _parseRoom(d);
  });

  @override
  Future<void> createRoom(RoomDoc room, MemberDoc host) => _guard(() async {
    final ref = _room(room.code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) throw RoomExistsException();
      tx.set(ref, {
        ...room.toMap(),
        'hostHeartbeat': FieldValue.serverTimestamp(),
        'expireAt': _expire(_roomTtl),
      });
    });
    // El miembro se crea aparte: las reglas exigen que la sala ya exista.
    await _col(
      room.code,
      'members',
    ).doc(host.uid).set({...host.toMap(), 'expireAt': _expire(_subTtl)});
  });

  @override
  Future<void> joinRoom(String roomId, MemberDoc me) => _guard(() async {
    final room = await getRoom(roomId);
    if (room == null) throw RoomNotFoundException();
    final mine = await _col(roomId, 'members').doc(uid).get();
    if (mine.exists) return; // reentrada
    if (room.phase != Phase.lobby) {
      throw RoomNotJoinableException('La partida ya ha empezado.');
    }
    await _col(
      roomId,
      'members',
    ).doc(uid).set({...me.toMap(), 'expireAt': _expire(_subTtl)});
  });

  @override
  Future<void> leaveRoom(String roomId, {required bool inGame}) =>
      _guard(() async {
        final ref = _col(roomId, 'members').doc(uid);
        if (inGame) {
          await ref.update({'left': true});
        } else {
          await ref.delete();
        }
      });

  // --------------------------------------------------------------- lecturas

  @override
  Stream<RoomDoc?> watchRoom(String roomId) => _guardStream(
    _room(roomId).snapshots().map((s) {
      final d = s.data();
      return d == null ? null : _parseRoom(d);
    }),
  );

  @override
  Stream<List<ChatMessage>> watchChat(String roomId) => _guardStream(
    _col(
      roomId,
      'chat',
    ).orderBy('ts', descending: true).limit(60).snapshots().map((q) {
      final list = [
        for (final d in q.docs)
          ChatMessage(
            id: d.id,
            uid: d.data()['uid'] as String? ?? '',
            name: d.data()['name'] as String? ?? '?',
            text: d.data()['text'] as String? ?? '',
            // `ts` es null un instante mientras el servidor no lo ha fijado.
            tsMs: d.data()['ts'] is Timestamp
                ? (d.data()['ts'] as Timestamp).millisecondsSinceEpoch
                : DateTime.now().millisecondsSinceEpoch,
          ),
      ];
      return list.reversed.toList();
    }),
  );

  @override
  Future<void> sendChat(String roomId, String text) => _guard(() async {
    final err = ChatMessage.validateText(text);
    if (err != null) throw PermissionDeniedException(err);
    final me = await _col(roomId, 'members').doc(uid).get();
    final name = me.data()?['name'] as String? ?? '?';
    await _col(roomId, 'chat').add({
      'uid': uid,
      'name': name,
      'text': text.trim(),
      'ts': FieldValue.serverTimestamp(),
      'expireAt': _expire(_roomTtl),
    });
  });

  @override
  Stream<List<MemberDoc>> watchMembers(String roomId) => _guardStream(
    _col(roomId, 'members').snapshots().map(
      (q) => [for (final d in q.docs) MemberDoc.fromMap(d.data())],
    ),
  );

  @override
  Stream<PrivateDoc?> watchPrivate(String roomId, String target) =>
      _guardStream(
        _col(roomId, 'private').doc(target).snapshots().map((s) {
          final d = s.data();
          return d == null ? null : PrivateDoc.fromMap(d);
        }),
      );

  @override
  Stream<List<ActionDoc>> watchActions(String roomId, int round) =>
      _guardStream(
        _col(roomId, 'actions')
            .where('round', isEqualTo: round)
            .snapshots()
            .map(
              (q) => [
                for (final d in q.docs)
                  ActionDoc(NightAction.fromMap(d.data())),
              ],
            ),
      );

  @override
  Stream<List<VoteDoc>> watchVotes(String roomId, int seq) => _guardStream(
    _col(roomId, 'votes')
        .where('seq', isEqualTo: seq)
        .snapshots()
        .map((q) => [for (final d in q.docs) VoteDoc.fromMap(d.data())]),
  );

  @override
  Stream<Map<String, int>> watchPresence(String roomId) => _guardStream(
    _col(roomId, 'presence').snapshots().map(
      (q) => {for (final d in q.docs) d.id: _ms(d.data()['ts'])},
    ),
  );

  @override
  Future<HostStateDoc?> readHostState(String roomId) => _guard(() async {
    final s = await _col(roomId, 'hostState').doc('state').get();
    final d = s.data();
    return d == null ? null : HostStateDoc.fromMap(d);
  });

  // ------------------------------------------------------------- escrituras

  @override
  Future<int> commit(String roomId, Commit c) => _guard(() async {
    final roomRef = _room(roomId);
    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(roomRef);
      final cur = snap.data();
      if (cur == null ||
          cur['hostUid'] != uid ||
          (cur['version'] as num?)?.toInt() != c.expectedVersion) {
        throw VersionConflictException();
      }
      final newVersion = c.expectedVersion + 1;
      final map = c.room.toMap()
        ..['version'] = newVersion
        ..['hostUid'] = cur['hostUid']
        ..['expireAt'] = _expire(
          _roomTtl,
        ); // cada transición renueva la caducidad
      tx.update(roomRef, map);

      c.privates.forEach(
        (u, p) => tx.set(_col(roomId, 'private').doc(u), {
          ...p.toMap(),
          'expireAt': _expire(_subTtl),
        }),
      );
      c.memberPatches.forEach(
        (u, patch) => tx.update(_col(roomId, 'members').doc(u), patch),
      );
      for (final u in c.deleteMembers) {
        tx.delete(_col(roomId, 'members').doc(u));
      }
      if (c.hostState != null) {
        tx.set(_col(roomId, 'hostState').doc('state'), {
          ...c.hostState!.toMap(),
          'expireAt': _expire(_subTtl),
        });
      }
      for (final id in c.deleteActions) {
        tx.delete(_col(roomId, 'actions').doc(id));
      }
      for (final id in c.deleteVotes) {
        tx.delete(_col(roomId, 'votes').doc(id));
      }
      return newVersion;
    });
  });

  @override
  Future<void> setOnline(String roomId, Map<String, bool> online) =>
      _guard(() async {
        final batch = _db.batch();
        online.forEach(
          (u, v) => batch.update(_col(roomId, 'members').doc(u), {'online': v}),
        );
        await batch.commit();
      });

  @override
  Future<void> submitAction(String roomId, NightAction a) => _guard(() async {
    await _col(roomId, 'actions').doc('${a.round}_${a.uid}').set({
      ...a.toMap(),
      'expireAt': _expire(_subTtl),
    });
  });

  @override
  Future<void> submitVote(String roomId, VoteDoc v) => _guard(() async {
    await _col(
      roomId,
      'votes',
    ).doc(v.id).set({...v.toMap(), 'expireAt': _expire(_subTtl)});
  });

  @override
  Future<void> heartbeat(String roomId, {required bool asHost}) =>
      _guard(() async {
        final batch = _db.batch();
        batch.set(_col(roomId, 'presence').doc(uid), {
          'ts': FieldValue.serverTimestamp(),
          'expireAt': _expire(_subTtl),
        });
        if (asHost) {
          batch.update(_room(roomId), {
            'hostHeartbeat': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      });

  @override
  Future<bool> claimHost(String roomId) async {
    try {
      return await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(_room(roomId));
        final cur = snap.data();
        if (cur == null) return false;
        if (cur['hostUid'] == uid) return true;
        final beat = cur['hostHeartbeat'];
        if (beat is Timestamp &&
            DateTime.now().difference(beat.toDate()) <
                const Duration(seconds: 45)) {
          return false;
        }
        tx.update(_room(roomId), {
          'hostUid': uid,
          'hostHeartbeat': FieldValue.serverTimestamp(),
          'version': ((cur['version'] as num?)?.toInt() ?? 1) + 1,
        });
        return true;
      });
    } on FirebaseException catch (e) {
      // Las reglas rechazan el relevo si el anfitrión aún late (hora de servidor).
      if (e.code == 'permission-denied' || e.code == 'aborted') return false;
      rethrow;
    }
  }

  @override
  Future<void> deleteRoom(String roomId) => _guard(() async {
    for (final name in [
      'actions',
      'votes',
      'chat',
      'private',
      'hostState',
      'presence',
      'members',
    ]) {
      final q = await _col(roomId, name).get();
      if (q.docs.isEmpty) continue;
      final batch = _db.batch();
      for (final d in q.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await _room(roomId).delete();
  });
}
