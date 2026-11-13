import 'enums.dart';
import 'roles.dart';

/// Señal de audio asociada a una línea de narración.
enum Cue { none, reveal, nightStart, wake, sleep, dawn, death, vote, victory, defeat }

class NarrationLine {
  const NarrationLine(this.text, [this.cue = Cue.none]);
  final String text;
  final Cue cue;
}

/// Textos del narrador en español. Pura lógica de cadenas: no depende de la
/// interfaz y se puede leer en voz alta (TTS) o mostrar como texto.
class Narrator {
  const Narrator._();

  static NarrationLine roleReveal() => const NarrationLine(
      'Mira tu carta en secreto. Que nadie vea quién eres.', Cue.reveal);

  static NarrationLine nightStart(int round) => NarrationLine(
      round == 1
          ? 'Cae la primera noche sobre el pueblo. Todos cierran los ojos.'
          : 'Cae la noche sobre el pueblo. Todos cierran los ojos.',
      Cue.nightStart);

  static NarrationLine wake(RoleId role) =>
      NarrationLine(RoleInfo.of(role).wakeLine, Cue.wake);

  static NarrationLine sleep(RoleId role) =>
      NarrationLine(RoleInfo.of(role).sleepLine, Cue.sleep);

  static NarrationLine dawn(List<String> deadNames, {bool saved = false}) {
    if (deadNames.isEmpty) {
      return NarrationLine(
        saved
            ? 'Amanece. Alguien estuvo a punto de morir, pero el pueblo despierta al completo.'
            : 'Amanece. Esta noche no ha muerto nadie.',
        Cue.dawn,
      );
    }
    final who = _join(deadNames);
    return NarrationLine(
      deadNames.length == 1
          ? 'Amanece. Esta noche ha muerto $who.'
          : 'Amanece. Esta noche han muerto $who.',
      Cue.death,
    );
  }

  static NarrationLine discussion(int seconds) => NarrationLine(
      'El pueblo debate. Tenéis ${_minutes(seconds)} para encontrar a los asesinos.');

  static NarrationLine voting() => const NarrationLine(
      'Es hora de votar. ¿Quién debe ser expulsado del pueblo?', Cue.vote);

  static NarrationLine voteResult({
    required String? eliminatedName,
    required bool tie,
    required bool revote,
  }) {
    if (eliminatedName != null) {
      return NarrationLine('El pueblo ha decidido. $eliminatedName es expulsado.', Cue.death);
    }
    if (revote) {
      return const NarrationLine('Empate. Se repite la votación entre los empatados.', Cue.vote);
    }
    if (tie) {
      return const NarrationLine('Empate. Nadie es expulsado hoy.');
    }
    return const NarrationLine('Nadie ha sido expulsado hoy.');
  }

  static NarrationLine victory(Winner w) {
    switch (w) {
      case Winner.town:
        return const NarrationLine(
            'Los asesinos han sido descubiertos. ¡Gana el pueblo!', Cue.victory);
      case Winner.assassins:
        return const NarrationLine(
            'El pueblo ya no puede detenerlos. ¡Ganan los asesinos!', Cue.defeat);
      case Winner.lovers:
        return const NarrationLine(
            'Contra todo pronóstico, ¡ganan los enamorados!', Cue.victory);
    }
  }

  static String causeText(DeathCause c) {
    switch (c) {
      case DeathCause.assassin:
        return 'asesinado por la noche';
      case DeathCause.heartbreak:
        return 'muerto de amor';
      case DeathCause.vote:
        return 'expulsado por votación';
      case DeathCause.abandon:
        return 'abandonó la partida';
    }
  }

  static String _join(List<String> names) {
    if (names.length == 1) return names.first;
    return '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';
  }

  static String _minutes(int seconds) {
    if (seconds % 60 == 0) {
      final m = seconds ~/ 60;
      return m == 1 ? '1 minuto' : '$m minutos';
    }
    return '$seconds segundos';
  }
}
