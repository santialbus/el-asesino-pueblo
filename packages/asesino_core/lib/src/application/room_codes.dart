import 'dart:math';

/// Códigos de sala de 6 caracteres sin símbolos ambiguos (sin 0/O/1/I/L).
class RoomCodes {
  const RoomCodes._();

  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const length = 6;

  static String generate(Random rng) =>
      List.generate(length, (_) => alphabet[rng.nextInt(alphabet.length)]).join();

  /// Normaliza lo que escribe el usuario: mayúsculas y sin espacios/guiones.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValid(String code) =>
      code.length == length && code.split('').every(alphabet.contains);
}
