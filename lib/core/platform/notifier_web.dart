// Avisos de turno en el navegador: título de la pestaña y Notification API.
// Usa sólo dart:js_interop (sin paquetes adicionales).
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject? get _document {
  final d = globalContext['document'];
  return d == null ? null : d as JSObject;
}

JSObject? get _notification {
  final n = globalContext['Notification'];
  return n == null ? null : n as JSObject;
}

bool get notificationsSupported => _notification != null;

/// 'granted', 'denied', 'default' o 'unsupported'.
String get notificationPermission {
  final n = _notification;
  if (n == null) return 'unsupported';
  final p = n['permission'];
  return p == null ? 'default' : (p as JSString).toDart;
}

Future<String> requestNotificationPermission() async {
  final n = _notification;
  if (n == null) return 'unsupported';
  try {
    final result = await n
        .callMethod<JSPromise<JSAny?>>('requestPermission'.toJS)
        .toDart;
    return result == null
        ? notificationPermission
        : (result as JSString).toDart;
  } catch (_) {
    return notificationPermission;
  }
}

/// Muestra una notificación del sistema (sólo si hay permiso).
void notifyTurn(String title, String body) {
  if (notificationPermission != 'granted') return;
  try {
    final ctor = _notification as JSFunction;
    final opts = JSObject();
    opts['body'] = body.toJS;
    opts['tag'] = 'asesino-turno'.toJS; // una sola notificación a la vez
    ctor.callAsConstructor<JSObject>(title.toJS, opts);
  } catch (_) {
    // Algunos navegadores móviles exigen un service worker: se ignora.
  }
}

void setTabTitle(String title) {
  try {
    _document?['title'] = title.toJS;
  } catch (_) {}
}

bool get tabHidden {
  try {
    final h = _document?['hidden'];
    return h != null && (h as JSBoolean).toDart;
  } catch (_) {
    return false;
  }
}
