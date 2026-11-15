import 'package:asesino_core/asesino_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Código de sala contenido en una URL del tipo `https://…/#ABC234`.
/// Devuelve null si no hay un código válido.
String? roomCodeFromUri(Uri uri) {
  final code = RoomCodes.normalize(uri.fragment);
  return RoomCodes.isValid(code) ? code : null;
}

/// Enlace directo para unirse a [code] (sólo en web; null en otras plataformas).
String? inviteLink(String code) {
  if (!kIsWeb) return null;
  try {
    final base = Uri.base;
    return '${base.origin}${base.path}#$code';
  } catch (_) {
    return null;
  }
}
