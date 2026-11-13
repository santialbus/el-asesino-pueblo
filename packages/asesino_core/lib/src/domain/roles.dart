import 'enums.dart';

/// Descripción estática de un rol. Añadir un rol nuevo = añadir una entrada
/// aquí, su caso en `NightResolver` y su ilustración en la app.
class RoleInfo {
  const RoleInfo({
    required this.id,
    required this.name,
    required this.defaultTeam,
    required this.summary,
    required this.ability,
    required this.hasNightAbility,
    required this.wakeLine,
    required this.sleepLine,
  });

  final RoleId id;
  final String name;
  final Team defaultTeam;

  /// Descripción corta del personaje.
  final String summary;

  /// Texto de la habilidad.
  final String ability;
  final bool hasNightAbility;

  /// Frase del narrador al despertar al rol / al dormirlo.
  final String wakeLine;
  final String sleepLine;

  static const Map<RoleId, RoleInfo> all = {
    RoleId.assassin: RoleInfo(
      id: RoleId.assassin,
      name: 'El Asesino',
      defaultTeam: Team.assassins,
      summary: 'Vive entre el pueblo y mata en la sombra.',
      ability: 'Cada noche, junto a los demás asesinos, elige a una víctima.',
      hasNightAbility: true,
      wakeLine: 'Los asesinos despiertan y eligen a su víctima.',
      sleepLine: 'Los asesinos vuelven a dormir.',
    ),
    RoleId.police: RoleInfo(
      id: RoleId.police,
      name: 'El Policía',
      defaultTeam: Team.town,
      summary: 'Sospecha de todos y busca pruebas.',
      ability: 'Cada noche investiga a un jugador y descubre si es asesino.',
      hasNightAbility: true,
      wakeLine: 'El policía despierta e investiga a un sospechoso.',
      sleepLine: 'El policía vuelve a dormir.',
    ),
    RoleId.doctor: RoleInfo(
      id: RoleId.doctor,
      name: 'El Médico',
      defaultTeam: Team.town,
      summary: 'Sólo quiere que nadie muera esta noche.',
      ability: 'Cada noche protege a un jugador de un ataque.',
      hasNightAbility: true,
      wakeLine: 'El médico despierta y elige a quién proteger.',
      sleepLine: 'El médico vuelve a dormir.',
    ),
    RoleId.cupid: RoleInfo(
      id: RoleId.cupid,
      name: 'Cupido',
      defaultTeam: Team.town,
      summary: 'Une destinos con una sola flecha.',
      ability:
          'La primera noche elige a dos enamorados. Si uno muere, el otro también.',
      hasNightAbility: true,
      wakeLine: 'Cupido despierta y elige a los enamorados.',
      sleepLine: 'Cupido vuelve a dormir.',
    ),
    RoleId.blocker: RoleInfo(
      id: RoleId.blocker,
      name: 'La Puta',
      defaultTeam: Team.town,
      summary: 'Distrae a quien no debe.',
      ability: 'Cada noche impide que otro jugador use su habilidad.',
      hasNightAbility: true,
      wakeLine: 'La Puta despierta y elige a quién distraer.',
      sleepLine: 'La Puta vuelve a dormir.',
    ),
    RoleId.civilian: RoleInfo(
      id: RoleId.civilian,
      name: 'Civil',
      defaultTeam: Team.town,
      summary: 'Un vecino más, con su voz y su voto.',
      ability: 'No tiene habilidad nocturna. Debate y vota durante el día.',
      hasNightAbility: false,
      wakeLine: '',
      sleepLine: '',
    ),
  };

  static RoleInfo of(RoleId id) => all[id]!;
}

String teamName(Team t) {
  switch (t) {
    case Team.town:
      return 'Pueblo';
    case Team.assassins:
      return 'Asesinos';
    case Team.neutral:
      return 'Neutral';
  }
}
