import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/widgets/controls.dart';

/// Partida guiada: 7 jugadores (tú + 6 bots), tú de Policía y bots que no te
/// atacan ni te votan, con tiempos largos para dar tiempo a leer.
class TutorialPlan {
  const TutorialPlan({
    this.players = 7,
    this.forcedRoles = const {'tu': RoleId.police},
    this.spare = const {'tu'},
  });

  final int players;
  final Map<String, RoleId> forcedRoles;
  final Set<String> spare;

  GameConfig get config => GameConfig.recommended(players)
      .copyWith(discussionSeconds: 90, votingSeconds: 45, nightStepSeconds: 25);

  HostTimings get timings => const HostTimings(
    roleReveal: Duration(seconds: 90),
    dawn: Duration(seconds: 40),
    voteResult: Duration(seconds: 30),
  );
}

/// Tarjeta guía: explica la fase actual la primera vez que aparece.
class TutorialCoach extends StatefulWidget {
  const TutorialCoach({
    super.key,
    required this.room,
    required this.members,
    required this.me,
    required this.myUid,
    required this.onSkip,
  });

  final RoomDoc room;
  final List<MemberDoc> members;
  final PrivateDoc? me;
  final String myUid;
  final VoidCallback onSkip;

  @override
  State<TutorialCoach> createState() => _TutorialCoachState();
}

class _TutorialCoachState extends State<TutorialCoach> {
  final Set<String> _seen = {};

  /// (clave, título, texto) de lo que toca explicar ahora, o null.
  (String, String, String)? _current() {
    final room = widget.room;
    final me = widget.me;
    final self = widget.members.where((m) => m.uid == widget.myUid);
    final alive = self.isEmpty ? true : self.first.alive;
    if (!alive && room.phase != Phase.finished) {
      return (
        'dead',
        'Has sido eliminado',
        'Ahora puedes observar en silencio hasta el final de la partida.',
      );
    }
    switch (room.phase) {
      case Phase.lobby:
      case Phase.victoryCheck:
      case Phase.nextRound:
        return null;
      case Phase.roleReveal:
        final role = me == null ? 'tu personaje' : RoleInfo.of(me.role).name;
        return (
          'reveal',
          'Tu carta secreta',
          'Cada jugador recibe un personaje en secreto. En este tutorial eres $role. '
              'Toca la carta para verla y pulsa «Ocultar carta» para que nadie más la vea. '
              'Cuando acabe el tiempo (o pulses «Saltar fase») empieza la noche.',
        );
      case Phase.night:
        final p = NightPrompt.compute(
          room: room,
          members: widget.members,
          me: me,
          myUid: widget.myUid,
        );
        if (p.isActor && p.myTurn) {
          return ('night_turn', 'Es tu turno', _nightTurnText(p.role!));
        }
        return (
          'night_wait',
          'Cae la noche',
          'De noche todos cierran los ojos y los personajes despiertan por turnos. '
              'Los asesinos eligen a su víctima. Cuando sea tu turno, la pantalla cambiará. '
              'Mientras tanto, espera: nadie puede ver quién está actuando.',
        );
      case Phase.dawn:
        return (
          'dawn',
          'Amanece',
          'Se anuncia quién ha muerto esta noche. Si eres el Policía, mira «Tus pistas»: '
              'ahí aparece el resultado de tu investigación, solo para ti.',
        );
      case Phase.discussion:
        return (
          'talk',
          'Debate',
          'Ahora el pueblo discute para encontrar a los asesinos. En una partida real hablaríais en '
              'persona o por llamada; aquí también puedes usar el chat (botón de arriba a la derecha). '
              'Cuando acabe el tiempo, se vota.',
        );
      case Phase.voting:
        return (
          'vote',
          'Votación',
          'Elige a quién expulsar del pueblo y confirma. Usa tus pistas. '
              'Si no estás seguro, puedes abstenerte.',
        );
      case Phase.voteResult:
        return (
          'result',
          'Escrutinio',
          'Se expulsa al más votado y se revela su personaje. Si todavía quedan asesinos, '
              'vuelve la noche. El pueblo gana si los expulsa a todos; los asesinos ganan cuando '
              'igualan en número al resto.',
        );
      case Phase.finished:
        return (
          'end',
          '¡Has completado el tutorial!',
          'Ya has visto una partida entera. Pulsa «Volver al menú» para crear tu primera partida '
              'real e invitar a tus amigos con el código o el enlace.',
        );
    }
  }

  String _nightTurnText(RoleId r) => switch (r) {
    RoleId.police =>
      'Elige a un jugador para investigarlo y confirma. Al amanecer sabrás si es asesino. '
          'Pista: en este tutorial hay un solo asesino entre los otros seis.',
    RoleId.doctor => 'Elige a quién proteges esta noche: si los asesinos lo atacan, se salvará.',
    RoleId.assassin =>
      'Elige a tu víctima. Tus compañeros asesinos eligen contigo.',
    RoleId.cupid =>
      'Elige a los dos enamorados: si uno muere, el otro también.',
    RoleId.blocker =>
      'Elige a quién distraes: esa noche no podrá usar su habilidad.',
    RoleId.civilian => '',
  };

  @override
  Widget build(BuildContext context) {
    final c = _current();
    if (c == null || _seen.contains(c.$1)) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.bg2.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gold, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.school_outlined,
                  size: 16,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 8),
                Text(
                  'TUTORIAL · ${c.$2.toUpperCase()}',
                  style: AppText.label(11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(c.$3, style: AppText.body(14)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GhostButton(
                  label: 'Salir del tutorial',
                  onPressed: widget.onSkip,
                ),
                GoldButton(
                  label: 'Entendido',
                  compact: true,
                  onPressed: () => setState(() => _seen.add(c.$1)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
