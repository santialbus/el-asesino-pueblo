import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/widgets/controls.dart';

String configSummary(GameConfig c, int players) {
  final civ = c.civilians(players);
  return '${c.assassins} ${c.assassins == 1 ? "asesino" : "asesinos"} · '
      '${c.police} ${c.police == 1 ? "policía" : "policías"} · '
      '${c.doctors} ${c.doctors == 1 ? "médico" : "médicos"}'
      '${c.cupid ? " · Cupido" : ""}${c.blocker ? " · La Puta" : ""} · '
      '${civ < 0 ? 0 : civ} ${civ == 1 ? "civil" : "civiles"}';
}

/// Abre el editor y devuelve la configuración elegida (o null si se cancela).
Future<GameConfig?> showConfigSheet(
  BuildContext context,
  GameConfig initial,
  int players,
) {
  return showModalBottomSheet<GameConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => _ConfigSheet(initial: initial, players: players),
  );
}

class _ConfigSheet extends StatefulWidget {
  const _ConfigSheet({required this.initial, required this.players});
  final GameConfig initial;
  final int players;

  @override
  State<_ConfigSheet> createState() => _ConfigSheetState();
}

class _ConfigSheetState extends State<_ConfigSheet> {
  late GameConfig c = widget.initial;

  void set(GameConfig n) => setState(() => c = n);

  @override
  Widget build(BuildContext context) {
    final errors = c.validate(widget.players);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scroll) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('CONFIGURACIÓN', style: AppText.label(14)),
                  ),
                  GhostButton(
                    label: 'Preset recomendado',
                    onPressed: () => set(
                      GameConfig.recommended(
                        widget.players,
                        narrator: c.narrator,
                      ).copyWith(
                        discussionSeconds: c.discussionSeconds,
                        votingSeconds: c.votingSeconds,
                        nightStepSeconds: c.nightStepSeconds,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Text(
                    '${widget.players} jugadores · ${configSummary(c, widget.players)}',
                    style: AppText.body(13, color: AppColors.text2),
                  ),
                  const SectionLabel('Reparto de roles'),
                  _Stepper(
                    'Asesinos',
                    c.assassins,
                    1,
                    8,
                    (v) => set(c.copyWith(assassins: v)),
                  ),
                  _Stepper(
                    'Policías',
                    c.police,
                    0,
                    4,
                    (v) => set(c.copyWith(police: v)),
                  ),
                  _Stepper(
                    'Médicos',
                    c.doctors,
                    0,
                    4,
                    (v) => set(c.copyWith(doctors: v)),
                  ),
                  _Switch('Cupido', c.cupid, (v) => set(c.copyWith(cupid: v))),
                  _Switch(
                    'La Puta',
                    c.blocker,
                    (v) => set(c.copyWith(blocker: v)),
                  ),
                  const SectionLabel('Habilidades'),
                  _Switch(
                    'El médico puede protegerse a sí mismo',
                    c.doctorSelfProtect,
                    (v) => set(c.copyWith(doctorSelfProtect: v)),
                  ),
                  _Switch(
                    'Puede repetir objetivo en noches seguidas',
                    c.doctorRepeatProtect,
                    (v) => set(c.copyWith(doctorRepeatProtect: v)),
                  ),
                  _Switch(
                    'Cupido puede elegirse a sí mismo',
                    c.cupidSelfPick,
                    (v) => set(c.copyWith(cupidSelfPick: v)),
                  ),
                  _Choice<Team>('Equipo de Cupido', c.cupidTeam, const {
                    Team.town: 'Pueblo',
                    Team.neutral: 'Neutral',
                  }, (v) => set(c.copyWith(cupidTeam: v))),
                  _Choice<Team>('Equipo de La Puta', c.blockerTeam, const {
                    Team.town: 'Pueblo',
                    Team.assassins: 'Asesinos',
                  }, (v) => set(c.copyWith(blockerTeam: v))),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      'Habilidades que La Puta puede bloquear',
                      style: AppText.body(14, color: AppColors.text2),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in [
                        RoleId.police,
                        RoleId.doctor,
                        RoleId.assassin,
                        RoleId.cupid,
                      ])
                        FilterChip(
                          label: Text(RoleInfo.of(r).name),
                          selected: c.blockable.contains(r),
                          onSelected: (on) => set(
                            c.copyWith(
                              blockable:
                                  on ? [...c.blockable, r] : [...c.blockable]
                                    ..remove(r),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SectionLabel('Orden de actuación nocturna'),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (a, b) {
                      final list = [...c.nightOrder];
                      if (b > a) b -= 1;
                      list.insert(b, list.removeAt(a));
                      set(c.copyWith(nightOrder: list));
                    },
                    children: [
                      for (final r in c.nightOrder)
                        ListTile(
                          key: ValueKey(r),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            RoleInfo.of(r).name,
                            style: AppText.body(15),
                          ),
                          trailing: const Icon(
                            Icons.drag_handle,
                            color: AppColors.text2,
                          ),
                        ),
                    ],
                  ),
                  const SectionLabel('Tiempos'),
                  _Slide(
                    'Debate',
                    c.discussionSeconds,
                    30,
                    600,
                    30,
                    (v) => set(c.copyWith(discussionSeconds: v)),
                  ),
                  _Slide(
                    'Votación',
                    c.votingSeconds,
                    15,
                    180,
                    15,
                    (v) => set(c.copyWith(votingSeconds: v)),
                  ),
                  _Slide(
                    'Cada turno de noche',
                    c.nightStepSeconds,
                    10,
                    60,
                    5,
                    (v) => set(c.copyWith(nightStepSeconds: v)),
                  ),
                  const SectionLabel('Votación y victoria'),
                  _Switch(
                    'Voto secreto',
                    c.secretVotes,
                    (v) => set(c.copyWith(secretVotes: v)),
                  ),
                  _Switch(
                    'Permitir abstención',
                    c.allowAbstain,
                    (v) => set(c.copyWith(allowAbstain: v)),
                  ),
                  _Choice<TieRule>('En caso de empate', c.tieRule, const {
                    TieRule.noElimination: 'Nadie',
                    TieRule.revote: 'Repetir',
                    TieRule.random: 'Al azar',
                  }, (v) => set(c.copyWith(tieRule: v))),
                  _Switch(
                    'Asesinos ganan sólo con mayoría estricta',
                    c.assassinsNeedStrictMajority,
                    (v) => set(c.copyWith(assassinsNeedStrictMajority: v)),
                  ),
                  _Switch(
                    'Los enamorados pueden ganar solos',
                    c.loversSpecialWin,
                    (v) => set(c.copyWith(loversSpecialWin: v)),
                  ),
                  _Switch(
                    'Revelar el rol de los eliminados',
                    c.revealRoleOnDeath,
                    (v) => set(c.copyWith(revealRoleOnDeath: v)),
                  ),
                  _Switch(
                    'Anunciar si el médico salva a alguien',
                    c.announceSaves,
                    (v) => set(c.copyWith(announceSaves: v)),
                  ),
                  const SizedBox(height: 16),
                  for (final e in errors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e,
                              style: AppText.body(13, color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: 'Cancelar',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GoldButton(
                      label: 'Guardar',
                      onPressed: errors.isEmpty
                          ? () => Navigator.pop(context, c)
                          : null,
                    ),
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

class _Stepper extends StatelessWidget {
  const _Stepper(this.label, this.value, this.min, this.max, this.onChanged);
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: AppText.body(16))),
      IconButton(
        tooltip: 'Menos $label',
        onPressed: value > min ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline),
        color: AppColors.gold,
      ),
      SizedBox(
        width: 28,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: AppText.title(18),
        ),
      ),
      IconButton(
        tooltip: 'Más $label',
        onPressed: value < max ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add_circle_outline),
        color: AppColors.gold,
      ),
    ],
  );
}

class _Switch extends StatelessWidget {
  const _Switch(this.label, this.value, this.onChanged);
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(label, style: AppText.body(15)),
    value: value,
    onChanged: onChanged,
  );
}

class _Choice<T> extends StatelessWidget {
  const _Choice(this.label, this.value, this.options, this.onChanged);
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.body(15)),
        const SizedBox(height: 6),
        SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final e in options.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    ),
  );
}

class _Slide extends StatelessWidget {
  const _Slide(
    this.label,
    this.value,
    this.min,
    this.max,
    this.step,
    this.onChanged,
  );
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  String get _fmt =>
      value >= 60 && value % 60 == 0 ? '${value ~/ 60} min' : '$value s';

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 120, child: Text(label, style: AppText.body(15))),
      Expanded(
        child: Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: ((max - min) / step).round(),
          label: _fmt,
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
      SizedBox(
        width: 56,
        child: Text(
          _fmt,
          textAlign: TextAlign.end,
          style: AppText.body(13, color: AppColors.text2),
        ),
      ),
    ],
  );
}
