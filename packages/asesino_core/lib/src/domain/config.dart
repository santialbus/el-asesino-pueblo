import 'enums.dart';

/// Configuración completa de una partida. Inmutable y serializable.
class GameConfig {
  const GameConfig({
    this.assassins = 1,
    this.police = 1,
    this.doctors = 1,
    this.cupid = false,
    this.blocker = false,
    this.doctorSelfProtect = true,
    this.doctorRepeatProtect = false,
    this.cupidSelfPick = true,
    this.cupidTeam = Team.town,
    this.blockerTeam = Team.town,
    this.blockable = const [RoleId.police, RoleId.doctor, RoleId.assassin],
    this.nightOrder = defaultNightOrder,
    this.discussionSeconds = 180,
    this.votingSeconds = 60,
    this.nightStepSeconds = 20,
    this.secretVotes = true,
    this.allowAbstain = true,
    this.tieRule = TieRule.noElimination,
    this.loversSpecialWin = false,
    this.assassinsNeedStrictMajority = false,
    this.revealRoleOnDeath = true,
    this.announceSaves = false,
    this.narrator = NarratorMode.auto,
  });

  static const defaultNightOrder = [
    RoleId.cupid,
    RoleId.blocker,
    RoleId.police,
    RoleId.doctor,
    RoleId.assassin,
  ];

  static const int minPlayers = 5;
  static const int maxPlayers = 20;

  final int assassins;
  final int police;
  final int doctors;
  final bool cupid;
  final bool blocker;

  final bool doctorSelfProtect;
  final bool doctorRepeatProtect;
  final bool cupidSelfPick;

  /// Cupido: town o neutral. La Puta: town o assassins.
  final Team cupidTeam;
  final Team blockerTeam;

  /// Roles cuya habilidad puede bloquear La Puta.
  final List<RoleId> blockable;

  /// Orden de actuación nocturna.
  final List<RoleId> nightOrder;

  final int discussionSeconds;
  final int votingSeconds;
  final int nightStepSeconds;

  final bool secretVotes;
  final bool allowAbstain;
  final TieRule tieRule;

  /// Si quedan sólo los dos enamorados y son de equipos distintos, ganan solos.
  final bool loversSpecialWin;

  /// false: los asesinos ganan con paridad (asesinos >= resto).
  /// true: necesitan mayoría estricta (asesinos > resto).
  final bool assassinsNeedStrictMajority;

  final bool revealRoleOnDeath;
  final bool announceSaves;
  final NarratorMode narrator;

  int civilians(int players) =>
      players - assassins - police - doctors - (cupid ? 1 : 0) - (blocker ? 1 : 0);

  /// Preset recomendado para [players] jugadores (5–20).
  factory GameConfig.recommended(int players, {NarratorMode narrator = NarratorMode.auto}) {
    final n = players.clamp(minPlayers, maxPlayers);
    int assassins;
    int police = 1;
    int doctors = 1;
    bool special = true;
    if (n <= 7) {
      assassins = 1;
      special = false;
    } else if (n <= 9) {
      assassins = n == 8 ? 1 : 2;
    } else if (n <= 12) {
      assassins = 2;
    } else if (n <= 15) {
      assassins = 3;
    } else {
      assassins = 4;
      police = 2;
      doctors = 2;
    }
    return GameConfig(
      assassins: assassins,
      police: police,
      doctors: doctors,
      cupid: special,
      blocker: special,
      narrator: narrator,
    );
  }

  /// Devuelve la lista de errores (en español) para [players] participantes.
  /// Vacía = configuración válida.
  List<String> validate(int players) {
    final e = <String>[];
    if (players < minPlayers) {
      e.add('Hacen falta al menos $minPlayers jugadores (hay $players).');
    }
    if (players > maxPlayers) {
      e.add('El máximo es $maxPlayers jugadores (hay $players).');
    }
    if (assassins < 1) e.add('Debe haber al menos un asesino.');
    if (police < 0 || doctors < 0) e.add('Los recuentos no pueden ser negativos.');
    if (assassins >= 1 && players >= 1 && assassins * 2 >= players) {
      e.add('Hay demasiados asesinos: la partida acabaría nada más empezar.');
    }
    if (civilians(players) < 0) {
      e.add('Hay más roles especiales que jugadores.');
    }
    if (discussionSeconds < 10 || votingSeconds < 10 || nightStepSeconds < 5) {
      e.add('Los tiempos configurados son demasiado cortos.');
    }
    final acting = <RoleId>{
      RoleId.assassin,
      if (police > 0) RoleId.police,
      if (doctors > 0) RoleId.doctor,
      if (cupid) RoleId.cupid,
      if (blocker) RoleId.blocker,
    };
    final order = nightOrder.toSet();
    if (nightOrder.length != order.length || !order.containsAll(acting)) {
      e.add('El orden de actuación nocturna debe incluir cada rol activo una vez.');
    }
    if (cupidTeam == Team.assassins) {
      e.add('Cupido sólo puede ser del pueblo o neutral.');
    }
    if (blockerTeam == Team.neutral) {
      e.add('La Puta sólo puede ser del pueblo o de los asesinos.');
    }
    if (blockerTeam == Team.assassins && blocker && (assassins + 1) * 2 >= players) {
      e.add('Con La Puta en el bando asesino hay demasiados asesinos.');
    }
    return e;
  }

  /// Roles que actúan de noche en esta partida, en orden.
  List<RoleId> activeNightRoles() {
    final active = <RoleId>{
      RoleId.assassin,
      if (police > 0) RoleId.police,
      if (doctors > 0) RoleId.doctor,
      if (cupid) RoleId.cupid,
      if (blocker) RoleId.blocker,
    };
    return [for (final r in nightOrder) if (active.contains(r)) r];
  }

  /// Pasos de la noche [round] (Cupido sólo en la primera).
  List<RoleId> nightSteps(int round) => [
        for (final r in activeNightRoles())
          if (r != RoleId.cupid || round == 1) r,
      ];

  GameConfig copyWith({
    int? assassins,
    int? police,
    int? doctors,
    bool? cupid,
    bool? blocker,
    bool? doctorSelfProtect,
    bool? doctorRepeatProtect,
    bool? cupidSelfPick,
    Team? cupidTeam,
    Team? blockerTeam,
    List<RoleId>? blockable,
    List<RoleId>? nightOrder,
    int? discussionSeconds,
    int? votingSeconds,
    int? nightStepSeconds,
    bool? secretVotes,
    bool? allowAbstain,
    TieRule? tieRule,
    bool? loversSpecialWin,
    bool? assassinsNeedStrictMajority,
    bool? revealRoleOnDeath,
    bool? announceSaves,
    NarratorMode? narrator,
  }) =>
      GameConfig(
        assassins: assassins ?? this.assassins,
        police: police ?? this.police,
        doctors: doctors ?? this.doctors,
        cupid: cupid ?? this.cupid,
        blocker: blocker ?? this.blocker,
        doctorSelfProtect: doctorSelfProtect ?? this.doctorSelfProtect,
        doctorRepeatProtect: doctorRepeatProtect ?? this.doctorRepeatProtect,
        cupidSelfPick: cupidSelfPick ?? this.cupidSelfPick,
        cupidTeam: cupidTeam ?? this.cupidTeam,
        blockerTeam: blockerTeam ?? this.blockerTeam,
        blockable: blockable ?? this.blockable,
        nightOrder: nightOrder ?? this.nightOrder,
        discussionSeconds: discussionSeconds ?? this.discussionSeconds,
        votingSeconds: votingSeconds ?? this.votingSeconds,
        nightStepSeconds: nightStepSeconds ?? this.nightStepSeconds,
        secretVotes: secretVotes ?? this.secretVotes,
        allowAbstain: allowAbstain ?? this.allowAbstain,
        tieRule: tieRule ?? this.tieRule,
        loversSpecialWin: loversSpecialWin ?? this.loversSpecialWin,
        assassinsNeedStrictMajority:
            assassinsNeedStrictMajority ?? this.assassinsNeedStrictMajority,
        revealRoleOnDeath: revealRoleOnDeath ?? this.revealRoleOnDeath,
        announceSaves: announceSaves ?? this.announceSaves,
        narrator: narrator ?? this.narrator,
      );

  Map<String, dynamic> toMap() => {
        'assassins': assassins,
        'police': police,
        'doctors': doctors,
        'cupid': cupid,
        'blocker': blocker,
        'doctorSelfProtect': doctorSelfProtect,
        'doctorRepeatProtect': doctorRepeatProtect,
        'cupidSelfPick': cupidSelfPick,
        'cupidTeam': cupidTeam.name,
        'blockerTeam': blockerTeam.name,
        'blockable': [for (final r in blockable) r.name],
        'nightOrder': [for (final r in nightOrder) r.name],
        'discussionSeconds': discussionSeconds,
        'votingSeconds': votingSeconds,
        'nightStepSeconds': nightStepSeconds,
        'secretVotes': secretVotes,
        'allowAbstain': allowAbstain,
        'tieRule': tieRule.name,
        'loversSpecialWin': loversSpecialWin,
        'assassinsNeedStrictMajority': assassinsNeedStrictMajority,
        'revealRoleOnDeath': revealRoleOnDeath,
        'announceSaves': announceSaves,
        'narrator': narrator.name,
      };

  factory GameConfig.fromMap(Map<String, dynamic> m) {
    const d = GameConfig();
    List<RoleId> roles(Object? v, List<RoleId> fallback) => v is List
        ? [for (final x in v) enumByName(RoleId.values, x, RoleId.civilian)]
        : fallback;
    return GameConfig(
      assassins: (m['assassins'] as num?)?.toInt() ?? d.assassins,
      police: (m['police'] as num?)?.toInt() ?? d.police,
      doctors: (m['doctors'] as num?)?.toInt() ?? d.doctors,
      cupid: m['cupid'] as bool? ?? d.cupid,
      blocker: m['blocker'] as bool? ?? d.blocker,
      doctorSelfProtect: m['doctorSelfProtect'] as bool? ?? d.doctorSelfProtect,
      doctorRepeatProtect: m['doctorRepeatProtect'] as bool? ?? d.doctorRepeatProtect,
      cupidSelfPick: m['cupidSelfPick'] as bool? ?? d.cupidSelfPick,
      cupidTeam: enumByName(Team.values, m['cupidTeam'], d.cupidTeam),
      blockerTeam: enumByName(Team.values, m['blockerTeam'], d.blockerTeam),
      blockable: roles(m['blockable'], d.blockable),
      nightOrder: roles(m['nightOrder'], d.nightOrder),
      discussionSeconds: (m['discussionSeconds'] as num?)?.toInt() ?? d.discussionSeconds,
      votingSeconds: (m['votingSeconds'] as num?)?.toInt() ?? d.votingSeconds,
      nightStepSeconds: (m['nightStepSeconds'] as num?)?.toInt() ?? d.nightStepSeconds,
      secretVotes: m['secretVotes'] as bool? ?? d.secretVotes,
      allowAbstain: m['allowAbstain'] as bool? ?? d.allowAbstain,
      tieRule: enumByName(TieRule.values, m['tieRule'], d.tieRule),
      loversSpecialWin: m['loversSpecialWin'] as bool? ?? d.loversSpecialWin,
      assassinsNeedStrictMajority:
          m['assassinsNeedStrictMajority'] as bool? ?? d.assassinsNeedStrictMajority,
      revealRoleOnDeath: m['revealRoleOnDeath'] as bool? ?? d.revealRoleOnDeath,
      announceSaves: m['announceSaves'] as bool? ?? d.announceSaves,
      narrator: enumByName(NarratorMode.values, m['narrator'], d.narrator),
    );
  }
}
