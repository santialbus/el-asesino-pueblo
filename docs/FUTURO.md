# Hoja de ruta (acordada)

## Hecho en esta versión
Chat de sala · tutorial guiado contra bots · enlace directo `/#CODIGO` · avisos de turno (web) ·
animaciones de amanecer, muertes, escrutinio y final · música por fase (menú, lobby/noche, día,
votación) · limpieza automática de salas (TTL).

## Para más adelante
| Tema | Notas |
|---|---|
| **Nuevos roles** | La arquitectura lo permite: una entrada en `RoleInfo`, su caso en `NightResolver`/`ActionValidator`, su ilustración y sus pruebas. Candidatos: cazador, vidente, bruja, alguacil. |
| **Ilustraciones definitivas** | Sustituir los emblemas dibujados por código por cartas ilustradas (assets locales). Sólo cambia `role_card.dart`. |
| **App Check** | Hacerlo al desplegar. Ver `docs/APPCHECK.md`. |
| **Desplegar la web y PWA instalable** | Primero se despliega; después se añade el manifiesto/iconos y se comprueba la instalación. |
| **Android e iOS** | Una vez lista la PWA: registrar las apps en Firebase (`flutterfire configure`), generar APK/AAB/IPA. Entonces tendrá sentido la vibración real y los avisos push (FCM). |
| **Cloud Functions / servidor autoritativo** | Única vía para una partida antitrampas. Exige el plan Blaze (pago por uso; conserva la cuota gratuita pero cobra el exceso en lugar de cortar). Se decidirá más adelante. |

## Descartado por ahora
Estadísticas e historial (es un juego casual de una sola partida) · voz del narrador ·
bots que razonan (los bots sólo sirven para probar la app).
