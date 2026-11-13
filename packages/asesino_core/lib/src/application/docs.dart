import '../domain/actions.dart';
import '../domain/config.dart';
import '../domain/enums.dart';
import '../domain/game_state.dart';
import '../domain/narration.dart';
import '../domain/roles.dart';

/// Modelos de los documentos de Firestore, independientes del SDK.
/// Todas las marcas de tiempo son milisegundos desde epoch (UTC).

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<String> _strings(Object? v) =>
    v is List ? [for (final x in v) x as String] : <String>[];

class DawnReport {
  const DawnReport({required this.deaths, required this.saved});
  final List<Death> deaths;

  /// Alguien fue salvado (sólo se publica si `announceSaves`).
  final bool saved;

  Map<String, dynamic> toMap() => {
        'deaths': [for (final d in deaths) d.toMap()],
        'saved': saved,
      };
  factory DawnReport.fromMap(Map<String, dynamic> m) => DawnReport(
        deaths: [
          for (final d in (m['deaths'] as List? ?? const []))
            Death.fromMap(_map(d))
        ],
        saved: m['saved'] as bool? ?? false,
      );
}

class VoteResultDoc {
  const VoteResultDoc({
    required this.tally,
    required this.abstentions,
    required this.eliminated,
    required this.tied,
    required this.revote,
    required this.votes,
  });
  final Map<String, int> tally;
  final int abstentions;
  final String? eliminated;
  final List<String> tied;
  final bool revote;

  /// Votante -> objetivo. Vacío si el voto es secreto.
  final Map<String, String> votes;

  Map<String, dynamic> toMap() => {
        'tally': tally,
        'abstentions': abstentions,
        if (eliminated != null) 'eliminated': eliminated,
        'tied': tied,
        'revote': revote,
        'votes': votes,
      };
  factory VoteResultDoc.fromMap(Map<String, dynamic> m) => VoteResultDoc(
        tally: {
          for (final e in _map(m['tally']).entries) e.key: (e.value as num).toInt()
        },
        abstentions: (m['abstentions'] as num?)?.toInt() ?? 0,
        eliminated: m['eliminated'] as String?,
        tied: _strings(m['tied']),
        revote: m['revote'] as bool? ?? false,
        votes: {for (final e in _map(m['votes']).entries) e.key: e.value as String},
      );
}

/// `rooms/{code}` — información pública de la sala. No contiene secretos.
class RoomDoc {
  const RoomDoc({
    required this.code,
    required this.name,
    required this.hostUid,
    required this.narrator,
    required this.phase,
    required this.round,
    required this.version,
    required this.config,
    required this.createdAtMs,
    this.hostHeartbeatMs = 0,
    this.nightStep,
    this.nightStepIdx = 0,
    this.phaseDurationMs = 0,
    this.voteSeq = 0,
    this.voteCandidates = const [],
    this.dawn,
    this.voteResult,
    this.winner,
    this.finalRoles = const {},
    this.narration = const NarrationLine(''),
    this.rematchOf,
  });

  final String code;
  final String name;
  final String hostUid;
  final NarratorMode narrator;
  final Phase phase;
  final int round;

  /// Versión del estado (control de concurrencia optimista).
  final int version;
  final GameConfig config;
  final int createdAtMs;

  /// Último latido del anfitrión (hora del servidor).
  final int hostHeartbeatMs;
  final RoleId? nightStep;
  final int nightStepIdx;

  /// Duración (ms) de la fase/paso actual. Los clientes cuentan atrás desde
  /// que reciben esta versión: no dependen de relojes sincronizados.
  final int phaseDurationMs;
  final int voteSeq;
  final List<String> voteCandidates;
  final DawnReport? dawn;
  final VoteResultDoc? voteResult;
  final Winner? winner;

  /// Roles de todos (uid -> rol). Sólo se publica al terminar la partida.
  final Map<String, RoleId> finalRoles;
  final NarrationLine narration;
  final String? rematchOf;

  RoomDoc copyWith({
    String? name,
    String? hostUid,
    NarratorMode? narrator,
    Phase? phase,
    int? round,
    int? version,
    GameConfig? config,
    int? hostHeartbeatMs,
    RoleId? nightStep,
    bool clearNightStep = false,
    int? nightStepIdx,
    int? phaseDurationMs,
    int? voteSeq,
    List<String>? voteCandidates,
    DawnReport? dawn,
    bool clearDawn = false,
    VoteResultDoc? voteResult,
    bool clearVoteResult = false,
    Winner? winner,
    bool clearWinner = false,
    Map<String, RoleId>? finalRoles,
    NarrationLine? narration,
  }) =>
      RoomDoc(
        code: code,
        name: name ?? this.name,
        hostUid: hostUid ?? this.hostUid,
        narrator: narrator ?? this.narrator,
        phase: phase ?? this.phase,
        round: round ?? this.round,
        version: version ?? this.version,
        config: config ?? this.config,
        createdAtMs: createdAtMs,
        hostHeartbeatMs: hostHeartbeatMs ?? this.hostHeartbeatMs,
        nightStep: clearNightStep ? null : (nightStep ?? this.nightStep),
        nightStepIdx: nightStepIdx ?? this.nightStepIdx,
        phaseDurationMs: phaseDurationMs ?? this.phaseDurationMs,
        voteSeq: voteSeq ?? this.voteSeq,
        voteCandidates: voteCandidates ?? this.voteCandidates,
        dawn: clearDawn ? null : (dawn ?? this.dawn),
        voteResult: clearVoteResult ? null : (voteResult ?? this.voteResult),
        winner: clearWinner ? null : (winner ?? this.winner),
        finalRoles: finalRoles ?? this.finalRoles,
        narration: narration ?? this.narration,
        rematchOf: rematchOf,
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'hostUid': hostUid,
        'narrator': narrator.name,
        'phase': phase.name,
        'round': round,
        'version': version,
        'config': config.toMap(),
        'createdAtMs': createdAtMs,
        'nightStep': nightStep?.name,
        'nightStepIdx': nightStepIdx,
        'phaseDurationMs': phaseDurationMs,
        'voteSeq': voteSeq,
        'voteCandidates': voteCandidates,
        'dawn': dawn?.toMap(),
        'voteResult': voteResult?.toMap(),
        'winner': winner?.name,
        'finalRoles': {for (final e in finalRoles.entries) e.key: e.value.name},
        'narration': {'text': narration.text, 'cue': narration.cue.name},
      };

  /// [hostHeartbeatMs] llega aparte porque en Firestore es un `Timestamp`
  /// de servidor.
  factory RoomDoc.fromMap(Map<String, dynamic> m, {int hostHeartbeatMs = 0}) {
    final n = _map(m['narration']);
    return RoomDoc(
      code: m['code'] as String,
      name: m['name'] as String? ?? '',
      hostUid: m['hostUid'] as String,
      narrator: enumByName(NarratorMode.values, m['narrator'], NarratorMode.auto),
      phase: enumByName(Phase.values, m['phase'], Phase.lobby),
      round: (m['round'] as num?)?.toInt() ?? 0,
      version: (m['version'] as num?)?.toInt() ?? 1,
      config: GameConfig.fromMap(_map(m['config'])),
      createdAtMs: (m['createdAtMs'] as num?)?.toInt() ?? 0,
      hostHeartbeatMs: hostHeartbeatMs,
      nightStep: m['nightStep'] == null
          ? null
          : enumByName(RoleId.values, m['nightStep'], RoleId.civilian),
      nightStepIdx: (m['nightStepIdx'] as num?)?.toInt() ?? 0,
      phaseDurationMs: (m['phaseDurationMs'] as num?)?.toInt() ?? 0,
      voteSeq: (m['voteSeq'] as num?)?.toInt() ?? 0,
      voteCandidates: _strings(m['voteCandidates']),
      dawn: m['dawn'] == null ? null : DawnReport.fromMap(_map(m['dawn'])),
      voteResult:
          m['voteResult'] == null ? null : VoteResultDoc.fromMap(_map(m['voteResult'])),
      winner: m['winner'] == null
          ? null
          : enumByName(Winner.values, m['winner'], Winner.town),
      finalRoles: {
        for (final e in _map(m['finalRoles']).entries)
          e.key: enumByName(RoleId.values, e.value, RoleId.civilian)
      },
      narration: NarrationLine(
        n['text'] as String? ?? '',
        enumByName(Cue.values, n['cue'], Cue.none),
      ),
    );
  }
}

/// `rooms/{code}/members/{uid}` — jugador visible para todos los miembros.
class MemberDoc {
  const MemberDoc({
    required this.uid,
    required this.name,
    required this.joinedAtMs,
    this.alive = true,
    this.online = true,
    this.revealedRole,
    this.left = false,
    this.isNarrator = false,
  });
  final String uid;
  final String name;
  final int joinedAtMs;
  final bool alive;
  final bool online;

  /// Rol público (sólo se rellena al morir si `revealRoleOnDeath`, o al final).
  final RoleId? revealedRole;
  final bool left;

  /// Narrador humano que no juega.
  final bool isNarrator;

  MemberDoc copyWith({
    String? name,
    bool? alive,
    bool? online,
    RoleId? revealedRole,
    bool? left,
    bool? isNarrator,
  }) =>
      MemberDoc(
        uid: uid,
        name: name ?? this.name,
        joinedAtMs: joinedAtMs,
        alive: alive ?? this.alive,
        online: online ?? this.online,
        revealedRole: revealedRole ?? this.revealedRole,
        left: left ?? this.left,
        isNarrator: isNarrator ?? this.isNarrator,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'joinedAtMs': joinedAtMs,
        'alive': alive,
        'online': online,
        'revealedRole': revealedRole?.name,
        'left': left,
        'isNarrator': isNarrator,
      };

  factory MemberDoc.fromMap(Map<String, dynamic> m) => MemberDoc(
        uid: m['uid'] as String,
        name: m['name'] as String? ?? '?',
        joinedAtMs: (m['joinedAtMs'] as num?)?.toInt() ?? 0,
        alive: m['alive'] as bool? ?? true,
        online: m['online'] as bool? ?? true,
        revealedRole: m['revealedRole'] == null
            ? null
            : enumByName(RoleId.values, m['revealedRole'], RoleId.civilian),
        left: m['left'] as bool? ?? false,
        isNarrator: m['isNarrator'] as bool? ?? false,
      );
}

/// `rooms/{code}/private/{uid}` — secretos de un jugador. Sólo lo leen su
/// dueño y el anfitrión.
class PrivateDoc {
  const PrivateDoc({
    required this.role,
    required this.team,
    this.teammates = const [],
    this.partner,
    this.cupidPair = const [],
    this.investigations = const [],
    this.lastProtected,
  });
  final RoleId role;
  final Team team;

  /// Otros asesinos (sólo para asesinos).
  final List<String> teammates;

  /// Pareja enamorada (sólo para enamorados).
  final String? partner;

  /// Los dos enamorados (sólo para Cupido).
  final List<String> cupidPair;
  final List<Investigation> investigations;

  /// Último objetivo protegido (sólo médicos).
  final String? lastProtected;

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'team': team.name,
        'teammates': teammates,
        'partner': partner,
        'cupidPair': cupidPair,
        'investigations': [for (final i in investigations) i.toMap()],
        'lastProtected': lastProtected,
      };

  factory PrivateDoc.fromMap(Map<String, dynamic> m) => PrivateDoc(
        role: enumByName(RoleId.values, m['role'], RoleId.civilian),
        team: enumByName(Team.values, m['team'], Team.town),
        teammates: _strings(m['teammates']),
        partner: m['partner'] as String?,
        cupidPair: _strings(m['cupidPair']),
        investigations: [
          for (final i in (m['investigations'] as List? ?? const []))
            Investigation.fromMap(_map(i))
        ],
        lastProtected: m['lastProtected'] as String?,
      );

  /// Construye el documento privado de [uid] a partir del estado completo.
  static PrivateDoc forPlayer(GameState s, String uid) {
    final p = s.player(uid)!;
    final team = s.teamOf(uid);
    return PrivateDoc(
      role: p.role,
      team: team,
      teammates: team == Team.assassins
          ? [
              for (final q in s.players)
                if (q.uid != uid && s.teamOf(q.uid) == Team.assassins) q.uid
            ]
          : const [],
      partner: s.lovers.contains(uid) ? s.lovers.firstWhere((u) => u != uid) : null,
      cupidPair: p.role == RoleId.cupid && s.cupidUid == uid ? s.lovers : const [],
      investigations: [for (final i in s.investigations) if (i.police == uid) i],
      lastProtected: s.lastProtected[uid],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PrivateDoc && _deepEq(toMap(), other.toMap());
  @override
  int get hashCode => toMap().toString().hashCode;
}

bool _deepEq(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_deepEq(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEq(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// `rooms/{code}/hostState/state` — copia autoritativa para recuperación.
class HostStateDoc {
  const HostStateDoc({required this.state, required this.version});
  final GameState state;
  final int version;

  Map<String, dynamic> toMap() => {'state': state.toMap(), 'version': version};
  factory HostStateDoc.fromMap(Map<String, dynamic> m) => HostStateDoc(
        state: GameState.fromMap(_map(m['state'])),
        version: (m['version'] as num?)?.toInt() ?? 0,
      );
}

/// `rooms/{code}/actions/{round}_{uid}`
class ActionDoc {
  const ActionDoc(this.action);
  final NightAction action;
  String get id => '${action.round}_${action.uid}';
}

/// `rooms/{code}/votes/{seq}_{uid}`
class VoteDoc {
  const VoteDoc({required this.uid, required this.seq, required this.target});
  final String uid;
  final int seq;
  final String target;
  String get id => '${seq}_$uid';

  Map<String, dynamic> toMap() => {'uid': uid, 'seq': seq, 'target': target};
  factory VoteDoc.fromMap(Map<String, dynamic> m) => VoteDoc(
        uid: m['uid'] as String,
        seq: (m['seq'] as num).toInt(),
        target: m['target'] as String,
      );
}

/// Texto de utilidad: nombre del rol.
String roleName(RoleId r) => RoleInfo.of(r).name;
