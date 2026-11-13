/// Motor de reglas y coordinación de EL ASESINO — EL PUEBLO DUERME.
///
/// Dart puro: no depende de Flutter ni de Firebase, de modo que toda la
/// lógica de juego se puede probar con `dart test`.
library asesino_core;

export 'src/domain/enums.dart';
export 'src/domain/roles.dart';
export 'src/domain/config.dart';
export 'src/domain/game_state.dart';
export 'src/domain/role_assigner.dart';
export 'src/domain/actions.dart';
export 'src/domain/night_resolver.dart';
export 'src/domain/vote_resolver.dart';
export 'src/domain/victory.dart';
export 'src/domain/narration.dart';
export 'src/application/docs.dart';
export 'src/application/backend.dart';
export 'src/application/host_coordinator.dart';
export 'src/application/player_view.dart';
export 'src/application/room_codes.dart';
