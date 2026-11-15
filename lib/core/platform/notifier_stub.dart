// Implementación vacía para plataformas sin navegador (Android, iOS, escritorio).
// Los avisos de turno en segundo plano en móvil requieren notificaciones push
// (FCM + registrar las apps en Firebase); queda para cuando se publique en móvil.

bool get notificationsSupported => false;
String get notificationPermission => 'unsupported';
Future<String> requestNotificationPermission() async => 'unsupported';
void notifyTurn(String title, String body) {}
void setTabTitle(String title) {}
bool get tabHidden => false;
