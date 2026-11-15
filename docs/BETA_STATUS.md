# Estado de la beta (0.9.0 beta 1) — qué está verificado y qué no

## Verificado con ejecución real
| Área | Cómo | Resultado |
|---|---|---|
| Motor de reglas (`asesino_core`) | `dart analyze` + 63 pruebas unitarias | 0 avisos, 63/63 |
| Partidas completas multi-cliente | 47 simulaciones: 5/8/12/20 jugadores × 3 semillas, narrador automático y humano, reglas alternativas, privacidad de roles/acciones/votos, acciones duplicadas, votos inválidos, lobby, abandonos, caída y relevo de anfitrión, revancha, modo con bots y **chat** (permisos por fase y por estado) | 47/47 |
| Estrés | 60 partidas aleatorias (+220 extra con otras semillas, una sola vez) con reglas y tamaños aleatorios | todas terminan; invariantes OK |
| Código Flutter | análisis estático (`dart analyze`) contra el código fuente real de Flutter (main), Riverpod 2.6.1, FlutterFire (cloud_firestore 5.6.12) y audioplayers 6.8.1 | 0 errores y 0 avisos propios |

Las simulaciones usan un backend en memoria que **emula** las reglas de seguridad
(lecturas privadas, create-only, fase/turno, versión, caducidad del anfitrión).
Es un modelo fiel pero **no es** Firestore real.

## Fallo real encontrado y corregido por el estrés
Con *La Puta en el bando asesino + victoria con mayoría estricta*, podía quedar un duelo de 2 vivos
sin nadie que pudiera matar: empate de votos perpetuo (la partida de prueba llegó a la ronda 180).
Regla añadida: en un duelo de 2 vivos donde ninguno puede matar de noche, el empate (o que ambos se
abstengan) se resuelve al azar. No afecta al duelo normal con un asesino que sí mata.

## Funciones nuevas (esta versión)
Chat de sala, tutorial guiado, enlace directo `/#CODIGO`, avisos de turno (web), animaciones de
momentos clave, música por fase, caducidad TTL. Lógica probada con ejecución real (chat, roles
forzados del tutorial, bots que no atacan al jugador protegido). Pantallas e integración con el
navegador (`dart:js_interop`): análisis estático correcto, **sin ejecutar**.

## Modo con bots (pruebas)
Botón **«Partida con bots (pruebas)»** en el inicio: partida local, sin Firebase, tú como
anfitrión contra 4–19 bots que usan el mismo motor y las mismas pantallas. La lógica de los
bots (`BotPlayer`/`BotDriver`) está probada con partidas completas; la pantalla que la monta
(`lib/features/bots/`) pasa el análisis estático pero no se ha ejecutado.

## Música
`assets/audio/ambient.wav` se regenera con `python3 tool/gen_music.py` (pad armónico con
reverberación, bucle de 48 s sin cortes: salto de empalme medido 0,0027). No he podido
escucharla: si no te convence el timbre, se ajusta en ese script.

## NO verificado (no se pudo ejecutar en el entorno de desarrollo)
* `flutter build` / `flutter test` / ejecución real de la interfaz: el SDK de Flutter
  no se pudo instalar allí (descarga bloqueada). La app pasa el análisis estático,
  pero **no se ha ejecutado**. Es probable que aparezcan ajustes visuales
  (espaciados, desbordes en pantallas muy pequeñas) y de rendimiento.
* **Reglas de Firestore contra el emulador**: `rules_test/` está escrito pero no se
  ha ejecutado (el emulador no se pudo descargar). Revísalas con `npm test`.
* Integración real con Firebase (latencia, cuotas, reintentos de transacción).
* Música en navegadores concretos (el audio web exige un gesto previo) y **vibración**, que sólo se puede probar en un móvil con la app nativa (la web no vibra).
* Android e iOS: sólo está registrada la app web en Firebase.
* Pruebas de widgets: `test/widget/` es un humo básico, sin ejecutar.
* **Avisos de turno**: notificaciones del navegador y título de pestaña, sin probar en navegadores reales (Safari/iOS limita las notificaciones web).
* **Enlace directo**: lectura de `/#CODIGO` al abrir la web, sin probar con un despliegue real.
* **TTL**: hay que activar las políticas en la consola (ver `docs/TTL.md`); sin ellas las salas no caducan solas.
* **Música nueva** (menú, día, tensión): empalme de bucle medido, pero no escuchada.

## Cómo cerrar el hueco (≈ 30 min)
1. `./tool/setup.sh && flutter analyze && flutter test`
2. `cd rules_test && npm i && npm test`
3. Partida de prueba con 5 pestañas (ver README). Si algo falla, pásame la salida.

## Limitaciones conocidas del diseño
Ver `docs/SECURITY.md` (anfitrión no es un servidor seguro, presencia aproximada, etc.).
