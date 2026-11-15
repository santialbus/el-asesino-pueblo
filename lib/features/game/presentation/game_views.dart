import 'dart:math' as math;

import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/services/settings.dart';
import '../../../shared/widgets/controls.dart';
import '../../../shared/widgets/effects.dart';
import '../../../shared/widgets/game_widgets.dart';
import '../../../shared/widgets/role_card.dart';
import '../../lobby/create_screen.dart' show friendlyError;
import '../application/providers.dart';

MemberDoc? findMember(List<MemberDoc> ms, String uid) {
  for (final m in ms) {
    if (m.uid == uid) return m;
  }
  return null;
}

String nameOf(List<MemberDoc> ms, String uid) =>
    findMember(ms, uid)?.name ?? 'Alguien';

bool _amSpectator(List<MemberDoc> ms, String uid) {
  final m = findMember(ms, uid);
  return m == null || m.isNarrator || !m.alive;
}

/// Pistas privadas del jugador: investigaciones y pareja enamorada.
class CluesPanel extends StatelessWidget {
  const CluesPanel({
    super.key,
    required this.me,
    required this.members,
    this.onlyRound,
  });
  final PrivateDoc? me;
  final List<MemberDoc> members;
  final int? onlyRound;

  @override
  Widget build(BuildContext context) {
    final d = me;
    if (d == null) return const SizedBox.shrink();
    final lines = <Widget>[];
    if (d.partner != null) {
      lines.add(
        _line(
          Icons.favorite,
          AppColors.danger,
          'Estás enamorado/a de ${nameOf(members, d.partner!)}. Si uno muere, el otro también.',
        ),
      );
    }
    if (d.cupidPair.length == 2) {
      lines.add(
        _line(
          Icons.favorite_border,
          AppColors.gold,
          'Has unido a ${nameOf(members, d.cupidPair[0])} y ${nameOf(members, d.cupidPair[1])}.',
        ),
      );
    }
    for (final i in d.investigations) {
      if (onlyRound != null && i.round != onlyRound) continue;
      final who = nameOf(members, i.target);
      lines.add(
        i.blocked
            ? _line(
                Icons.block,
                AppColors.text2,
                'Noche ${i.round}: alguien te distrajo y no obtuviste resultado sobre $who.',
              )
            : _line(
                i.isAssassin
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                i.isAssassin ? AppColors.danger : AppColors.town,
                'Noche ${i.round}: $who ${i.isAssassin ? "ES un asesino" : "NO es un asesino"}.',
              ),
      );
    }
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TUS PISTAS (SECRETO)', style: AppText.label(11)),
          const SizedBox(height: 8),
          ...lines,
        ],
      ),
    );
  }

  Widget _line(IconData i, Color c, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(i, size: 18, color: c),
        const SizedBox(width: 10),
        Expanded(child: Text(t, style: AppText.body(14))),
      ],
    ),
  );
}

// ------------------------------------------------------------------ revelación

class RoleRevealView extends ConsumerStatefulWidget {
  const RoleRevealView({
    super.key,
    required this.room,
    required this.members,
    required this.me,
    required this.myUid,
  });
  final RoomDoc room;
  final List<MemberDoc> members;
  final PrivateDoc? me;
  final String myUid;

  @override
  ConsumerState<RoleRevealView> createState() => _RoleRevealViewState();
}

class _RoleRevealViewState extends ConsumerState<RoleRevealView> {
  bool _up = false;

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final w = math.min(260.0, MediaQuery.sizeOf(context).width * 0.62);
    final isNarrator =
        findMember(widget.members, widget.myUid)?.isNarrator ?? false;
    return Column(
      children: [
        const SizedBox(height: 8),
        PhaseHeader(
          label: 'Revelación',
          title: 'Tu personaje',
          trailing: Countdown(
            durationMs: widget.room.phaseDurationMs,
            resetKey: widget.room.version,
          ),
        ),
        const SizedBox(height: 18),
        NarrationText(widget.room.narration.text, size: 16),
        const SizedBox(height: 22),
        if (me == null)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              isNarrator
                  ? 'Los jugadores están mirando sus cartas en secreto.'
                  : 'Recibiendo tu carta…',
              textAlign: TextAlign.center,
              style: AppText.body(16, color: AppColors.text2),
            ),
          )
        else ...[
          GestureDetector(
            onTap: () {
              ref.read(audioProvider).haptic('card');
              setState(() => _up = !_up);
            },
            child: RoleCard(
              role: me.role,
              team: me.team,
              faceUp: _up,
              width: w,
            ),
          ),
          const SizedBox(height: 18),
          if (!_up)
            Text(
              'Toca la carta para verla. Que nadie más mire tu pantalla.',
              textAlign: TextAlign.center,
              style: AppText.body(15, color: AppColors.text2),
            )
          else ...[
            Text(
              RoleInfo.of(me.role).summary,
              textAlign: TextAlign.center,
              style: AppText.body(16),
            ),
            const SizedBox(height: 6),
            Text(
              RoleInfo.of(me.role).ability,
              textAlign: TextAlign.center,
              style: AppText.body(14, color: AppColors.text2),
            ),
            if (me.teammates.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Tus compañeros: ${me.teammates.map((u) => nameOf(widget.members, u)).join(", ")}',
                textAlign: TextAlign.center,
                style: AppText.body(15, color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 10),
            GhostButton(
              label: 'Ocultar carta',
              icon: Icons.visibility_off_outlined,
              onPressed: () => setState(() => _up = false),
            ),
          ],
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------------ noche

class NightView extends ConsumerStatefulWidget {
  const NightView({
    super.key,
    required this.room,
    required this.members,
    required this.me,
    required this.myUid,
  });
  final RoomDoc room;
  final List<MemberDoc> members;
  final PrivateDoc? me;
  final String myUid;

  @override
  ConsumerState<NightView> createState() => _NightViewState();
}

class _NightViewState extends ConsumerState<NightView> {
  final Set<String> _picked = {};
  String? _stepKey;
  String? _sentKey;
  bool _busy = false;

  String get _key => '${widget.room.round}_${widget.room.nightStep?.name}';

  Future<void> _send(NightPrompt p, List<String> targets) async {
    setState(() => _busy = true);
    try {
      await PlayerActions(
        ref.read(backendProvider),
        widget.room.code,
      ).submitNight(widget.room, p.role!, targets);
      ref.read(audioProvider).haptic('confirm');
      if (mounted) setState(() => _sentKey = _key);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    if (_stepKey != _key) {
      _stepKey = _key;
      _picked.clear();
    }
    final p = NightPrompt.compute(
      room: room,
      members: widget.members,
      me: widget.me,
      myUid: widget.myUid,
    );
    final spectator = _amSpectator(widget.members, widget.myUid);
    final myTurn = p.isActor && p.myTurn && _sentKey != _key;
    if (!myTurn) {
      return _Sleeping(
        text: spectator
            ? (findMember(widget.members, widget.myUid)?.isNarrator ?? false
                  ? 'Dirige la noche desde el panel de moderación.'
                  : 'Observas la noche desde las sombras.')
            : (_sentKey == _key
                  ? 'Hecho. Vuelve a cerrar los ojos.'
                  : 'Cierra los ojos. El pueblo duerme…'),
        room: room,
      );
    }

    final info = RoleInfo.of(p.role!);
    final prompt = switch (p.role!) {
      RoleId.assassin => 'Elige a tu víctima.',
      RoleId.police => '¿De quién sospechas?',
      RoleId.doctor => '¿A quién proteges esta noche?',
      RoleId.cupid => 'Elige a los dos enamorados.',
      RoleId.blocker => '¿A quién distraes esta noche?',
      RoleId.civilian => '',
    };
    return Column(
      children: [
        const SizedBox(height: 8),
        PhaseHeader(
          label: 'Noche ${room.round}',
          title:
              'Despierta, ${info.name.replaceFirst("El ", "").replaceFirst("La ", "")}',
          trailing: Countdown(
            durationMs: room.phaseDurationMs,
            resetKey: room.version,
          ),
        ),
        const SizedBox(height: 12),
        RoleArt(role: p.role!, size: 72),
        const SizedBox(height: 8),
        Text(prompt, style: AppText.body(17)),
        if ((widget.me?.teammates ?? const []).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Compañeros: ${widget.me!.teammates.map((u) => nameOf(widget.members, u)).join(", ")}',
              style: AppText.body(13, color: AppColors.danger),
            ),
          ),
        const SizedBox(height: 14),
        if (p.validTargets.isEmpty)
          Text(
            'No hay objetivos posibles.',
            style: AppText.body(15, color: AppColors.text2),
          )
        else
          for (final u in p.validTargets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PlayerTile(
                member: findMember(widget.members, u)!,
                selected: _picked.contains(u),
                isMe: u == widget.myUid,
                onTap: () => setState(() {
                  if (_picked.contains(u)) {
                    _picked.remove(u);
                  } else if (_picked.length < p.picks) {
                    _picked.add(u);
                  } else if (p.picks == 1) {
                    _picked
                      ..clear()
                      ..add(u);
                  }
                }),
              ),
            ),
        const SizedBox(height: 12),
        GoldButton(
          label: p.picks == 2
              ? 'Unir a los enamorados (${_picked.length}/2)'
              : 'Confirmar',
          onPressed: (!_busy && _picked.length == p.picks)
              ? () => _send(p, _picked.toList())
              : null,
        ),
        GhostButton(
          label: 'Pasar sin actuar',
          onPressed: _busy ? null : () => _send(p, const []),
        ),
      ],
    );
  }
}

class _Sleeping extends StatelessWidget {
  const _Sleeping({required this.text, required this.room});
  final String text;
  final RoomDoc room;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 70),
      Text('NOCHE ${room.round}', style: AppText.label(13)),
      const SizedBox(height: 28),
      const Icon(Icons.nightlight_round, size: 64, color: AppColors.gold),
      const SizedBox(height: 28),
      Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.title(20, spacing: 1),
      ),
      const SizedBox(height: 30),
      NarrationText(room.narration.text, size: 15),
    ],
  );
}

// --------------------------------------------------------------------- amanecer

class DawnView extends StatelessWidget {
  const DawnView({
    super.key,
    required this.room,
    required this.members,
    required this.me,
  });
  final RoomDoc room;
  final List<MemberDoc> members;
  final PrivateDoc? me;

  @override
  Widget build(BuildContext context) {
    final deaths = room.dawn?.deaths ?? const <Death>[];
    return Column(
      children: [
        const SunriseGlow(),
        const SizedBox(height: 8),
        PhaseHeader(
          label: 'Amanecer · día ${room.round}',
          title: 'Amanece',
          trailing: Countdown(
            durationMs: room.phaseDurationMs,
            resetKey: room.version,
          ),
        ),
        const SizedBox(height: 22),
        NarrationText(room.narration.text, size: 19),
        const SizedBox(height: 24),
        if (deaths.isEmpty)
          Staggered(
            index: 2,
            stepMs: 500,
            child: Text(
              room.dawn?.saved == true
                  ? 'Alguien se salvó por poco.'
                  : 'Nadie ha muerto esta noche.',
              style: AppText.title(18, color: AppColors.town),
            ),
          ),
        // Las muertes se revelan una a una, con suspense.
        for (var i = 0; i < deaths.length; i++)
          Staggered(
            index: i + 2,
            stepMs: 650,
            child: _DeathCard(
              death: deaths[i],
              members: members,
              reveal: room.config.revealRoleOnDeath,
            ),
          ),
        CluesPanel(me: me, members: members, onlyRound: room.round),
      ],
    );
  }
}

class _DeathCard extends StatelessWidget {
  const _DeathCard({
    required this.death,
    required this.members,
    required this.reveal,
  });
  final Death death;
  final List<MemberDoc> members;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    final m = findMember(members, death.uid);
    final role = m?.revealedRole;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          if (reveal && role != null)
            RoleArt(role: role, size: 44, color: AppColors.danger)
          else
            const Icon(
              Icons.dark_mode_outlined,
              color: AppColors.danger,
              size: 40,
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m?.name ?? 'Alguien',
                  style: AppText.title(17, spacing: 1),
                ),
                Text(
                  '${Narrator.causeText(death.cause)}${reveal && role != null ? " · era ${RoleInfo.of(role).name}" : ""}',
                  style: AppText.body(13, color: AppColors.text2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------- debate

class DiscussionView extends StatelessWidget {
  const DiscussionView({
    super.key,
    required this.room,
    required this.members,
    required this.me,
    required this.myUid,
  });
  final RoomDoc room;
  final List<MemberDoc> members;
  final PrivateDoc? me;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final alive = [
      for (final m in members)
        if (m.alive && !m.isNarrator && !m.left) m,
    ];
    final dead = [
      for (final m in members)
        if (!m.alive && !m.isNarrator) m,
    ];
    final spectator = _amSpectator(members, myUid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        PhaseHeader(
          label: 'Día ${room.round}',
          title: 'Debate',
          trailing: Countdown(
            durationMs: room.phaseDurationMs,
            resetKey: room.version,
          ),
        ),
        const SizedBox(height: 10),
        NarrationText(room.narration.text, size: 15),
        if (spectator && !(findMember(members, myUid)?.isNarrator ?? false))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Estás eliminado: observa en silencio.',
              textAlign: TextAlign.center,
              style: AppText.body(14, color: AppColors.danger),
            ),
          ),
        CluesPanel(me: spectator ? null : me, members: members),
        const SectionLabel('Vecinos vivos'),
        for (final m in alive)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PlayerTile(member: m, isMe: m.uid == myUid),
          ),
        if (dead.isNotEmpty) ...[
          const SectionLabel('En el cementerio'),
          for (final m in dead)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PlayerTile(member: m, isMe: m.uid == myUid),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          'Debatid en persona o por llamada externa. No hay voz integrada en la app.',
          textAlign: TextAlign.center,
          style: AppText.body(12, color: AppColors.text2),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- votación

class VotingView extends ConsumerStatefulWidget {
  const VotingView({
    super.key,
    required this.room,
    required this.members,
    required this.myUid,
  });
  final RoomDoc room;
  final List<MemberDoc> members;
  final String myUid;

  @override
  ConsumerState<VotingView> createState() => _VotingViewState();
}

class _VotingViewState extends ConsumerState<VotingView> {
  String? _selected;
  int? _sentSeq;
  int? _seqSeen;
  bool _busy = false;

  Future<void> _vote(String target) async {
    setState(() => _busy = true);
    try {
      await PlayerActions(
        ref.read(backendProvider),
        widget.room.code,
      ).submitVote(widget.room, target);
      ref.read(audioProvider).haptic('vote');
      if (mounted) setState(() => _sentSeq = widget.room.voteSeq);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    if (_seqSeen != room.voteSeq) {
      _seqSeen = room.voteSeq;
      _selected = null;
    }
    final spectator = _amSpectator(widget.members, widget.myUid);
    final revote = room.voteCandidates.isNotEmpty;
    final candidates = revote
        ? [
            for (final u in room.voteCandidates)
              if (u != widget.myUid) findMember(widget.members, u),
          ].whereType<MemberDoc>().toList()
        : [
            for (final m in widget.members)
              if (m.alive && !m.isNarrator && !m.left && m.uid != widget.myUid)
                m,
          ];
    final sent = _sentSeq == room.voteSeq;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        PhaseHeader(
          label: revote ? 'Segunda votación' : 'Votación',
          title: '¿Quién se va?',
          trailing: Countdown(
            durationMs: room.phaseDurationMs,
            resetKey: room.version,
          ),
        ),
        const SizedBox(height: 10),
        NarrationText(room.narration.text, size: 15),
        const SizedBox(height: 14),
        if (spectator)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              (findMember(widget.members, widget.myUid)?.isNarrator ?? false)
                  ? 'El pueblo está votando.'
                  : 'Estás eliminado: no puedes votar.',
              textAlign: TextAlign.center,
              style: AppText.body(16, color: AppColors.text2),
            ),
          )
        else if (sent)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                const Icon(
                  Icons.how_to_vote_outlined,
                  color: AppColors.gold,
                  size: 48,
                ),
                const SizedBox(height: 14),
                Text('Voto emitido.', style: AppText.title(20)),
                const SizedBox(height: 6),
                Text(
                  'Esperando al resto del pueblo…',
                  style: AppText.body(14, color: AppColors.text2),
                ),
              ],
            ),
          )
        else ...[
          for (final m in candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PlayerTile(
                member: m,
                selected: _selected == m.uid,
                onTap: () => setState(() => _selected = m.uid),
              ),
            ),
          const SizedBox(height: 10),
          GoldButton(
            label: _selected == null
                ? 'Elige a un sospechoso'
                : 'Votar a ${nameOf(widget.members, _selected!)}',
            onPressed: (!_busy && _selected != null)
                ? () => _vote(_selected!)
                : null,
          ),
          if (room.config.allowAbstain)
            GhostButton(
              label: 'Abstenerme',
              onPressed: _busy ? null : () => _vote(kAbstain),
            ),
          Text(
            room.config.secretVotes
                ? 'El voto es secreto.'
                : 'El voto será público.',
            textAlign: TextAlign.center,
            style: AppText.body(12, color: AppColors.text2),
          ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------ resultado de voto

class VoteResultView extends StatelessWidget {
  const VoteResultView({super.key, required this.room, required this.members});
  final RoomDoc room;
  final List<MemberDoc> members;

  @override
  Widget build(BuildContext context) {
    final r = room.voteResult;
    final tally = r == null
        ? <MapEntry<String, int>>[]
        : (r.tally.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)));
    final maxVotes = tally.isEmpty ? 1 : tally.first.value;
    final out = r?.eliminated == null
        ? null
        : findMember(members, r!.eliminated!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        PhaseHeader(
          label: 'Escrutinio',
          title: 'Resultado',
          trailing: Countdown(
            durationMs: room.phaseDurationMs,
            resetKey: room.version,
          ),
        ),
        const SizedBox(height: 14),
        NarrationText(room.narration.text, size: 18),
        const SizedBox(height: 18),
        if (out != null)
          Staggered(
            index: 2,
            stepMs: 500,
            child: _DeathCard(
              death: Death(out.uid, DeathCause.vote),
              members: members,
              reveal: room.config.revealRoleOnDeath,
            ),
          ),
        const SectionLabel('Votos'),
        if (tally.isEmpty)
          Text(
            'Nadie recibió votos.',
            style: AppText.body(14, color: AppColors.text2),
          ),
        for (final e in tally)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    nameOf(members, e.key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(15),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(height: 14, color: AppColors.bg2),
                      FractionallySizedBox(
                        widthFactor: e.value / maxVotes,
                        child: Container(height: 14, color: AppColors.burgundy),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${e.value}',
                    textAlign: TextAlign.end,
                    style: AppText.title(16),
                  ),
                ),
              ],
            ),
          ),
        if ((r?.abstentions ?? 0) > 0)
          Text(
            'Abstenciones: ${r!.abstentions}',
            style: AppText.body(13, color: AppColors.text2),
          ),
        if (r != null && r.votes.isNotEmpty) ...[
          const SectionLabel('Quién votó a quién'),
          for (final e in r.votes.entries)
            Text(
              '${nameOf(members, e.key)} → ${e.value == kAbstain ? "abstención" : nameOf(members, e.value)}',
              style: AppText.body(14, color: AppColors.text2),
            ),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------------ final

class FinalView extends ConsumerStatefulWidget {
  const FinalView({
    super.key,
    required this.room,
    required this.members,
    required this.me,
    required this.myUid,
    required this.host,
    required this.onLeave,
    required this.onClose,
  });
  final RoomDoc room;
  final List<MemberDoc> members;
  final PrivateDoc? me;
  final String myUid;
  final HostCoordinator? host;
  final VoidCallback onLeave;
  final Future<void> Function() onClose;

  @override
  ConsumerState<FinalView> createState() => _FinalViewState();
}

class _FinalViewState extends ConsumerState<FinalView> {
  bool? get _won {
    final w = widget.room.winner;
    final me = widget.me;
    if (w == null || me == null) return null;
    return switch (w) {
      Winner.town => me.team == Team.town,
      Winner.assassins => me.team == Team.assassins,
      Winner.lovers => me.partner != null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final w = room.winner;
    final title = switch (w) {
      Winner.town => 'Gana el pueblo',
      Winner.assassins => 'Ganan los asesinos',
      Winner.lovers => 'Ganan los enamorados',
      null => 'Fin de la partida',
    };
    final color = w == Winner.assassins
        ? AppColors.danger
        : (w == Winner.lovers ? AppColors.gold : AppColors.town);
    final won = _won;
    final isHost = widget.host != null && room.hostUid == widget.myUid;
    final players = [
      for (final m in widget.members)
        if (!m.isNarrator) m,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Text('FIN', textAlign: TextAlign.center, style: AppText.label(13)),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: ref.watch(settingsProvider).reduceMotion ? 1 : 0,
            end: 1,
          ),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeOutCubic,
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.88 + 0.12 * t, child: child),
          ),
          child: Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppText.title(30, color: color, spacing: 3),
          ),
        ),
        const SizedBox(height: 10),
        const Center(child: OrnamentDivider(width: 220)),
        const SizedBox(height: 14),
        NarrationText(room.narration.text, size: 16),
        if (won != null) ...[
          const SizedBox(height: 14),
          Text(
            won ? '¡Has ganado!' : 'Has perdido esta vez.',
            textAlign: TextAlign.center,
            style: AppText.title(
              20,
              color: won ? AppColors.gold : AppColors.text2,
            ),
          ),
        ],
        const SectionLabel('Quién era quién'),
        for (final m in players)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            // Los personajes se desvelan de uno en uno.
            child: Staggered(
              index: players.indexOf(m),
              stepMs: 170,
              baseMs: 900,
              child: _FinalRow(
                member: m,
                role: room.finalRoles[m.uid],
                isMe: m.uid == widget.myUid,
              ),
            ),
          ),
        const SizedBox(height: 18),
        if (isHost) ...[
          GoldButton(
            label: 'Revancha',
            icon: Icons.replay,
            onPressed: () async {
              try {
                await widget.host!.rematch();
              } catch (e) {
                if (context.mounted) showMessage(context, friendlyError(e));
              }
            },
          ),
          GhostButton(
            label: 'Cerrar la sala',
            icon: Icons.delete_outline,
            onPressed: widget.onClose,
          ),
        ] else
          Center(
            child: Text(
              'Esperando a que el anfitrión proponga la revancha…',
              textAlign: TextAlign.center,
              style: AppText.body(14, color: AppColors.text2),
            ),
          ),
        Center(
          child: GhostButton(
            label: 'Volver al menú',
            icon: Icons.home_outlined,
            onPressed: widget.onLeave,
          ),
        ),
      ],
    );
  }
}

class _FinalRow extends StatelessWidget {
  const _FinalRow({
    required this.member,
    required this.role,
    required this.isMe,
  });
  final MemberDoc member;
  final RoleId? role;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final team = role == null ? Team.town : RoleInfo.of(role!).defaultTeam;
    final c = role == RoleId.assassin ? AppColors.danger : teamColor(team);
    return Opacity(
      opacity: member.alive ? 1 : 0.65,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bg2.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            if (role != null)
              RoleArt(role: role!, size: 38, color: c)
            else
              const SizedBox(width: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name + (isMe ? '  (tú)' : ''),
                    style: AppText.body(15, bold: true),
                  ),
                  Text(
                    '${role == null ? "?" : RoleInfo.of(role!).name}${member.alive ? "" : " · eliminado"}',
                    style: AppText.body(12, color: AppColors.text2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
