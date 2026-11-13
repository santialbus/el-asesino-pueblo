# Estado de la beta (0.9.0 beta 1) — qué está verificado y qué no

## Verificado con ejecución real
| Área | Cómo | Resultado |
|---|---|---|
| Motor de reglas (`asesino_core`) | `dart analyze` + 56 pruebas unitarias | 0 avisos, 56/56 |
| Partidas completas multi-cliente | 41 simulaciones: 5/8/12/20 jugadores × 3 semillas, narrador automático y humano, reglas alternativas, privacidad de roles/acciones/votos, acciones duplicadas, votos inválidos, lobby, abandonos, caída y relevo de anfitrión, revancha | 37/37 |
| Estrés | 60 partidas aleatorias (5–20 jugadores, reglas y semillas aleatorias) | todas terminan; invariantes OK |
| Código Flutter | análisis estático (`dart analyze`) contra el código fuente real de Flutter (main), Riverpod 2.6.1, FlutterFire (cloud_firestore 5.6.12) y audioplayers 6.8.1 | 0 errores y 0 avisos propios |

Las simulaciones usan un backend en memoria que **emula** las reglas de seguridad
(lecturas privadas, create-only, fase/turno, versión, caducidad del anfitrión).
Es un modelo fiel pero **no es** Firestore real.

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

## Cómo cerrar el hueco (≈ 30 min)
1. `./tool/setup.sh && flutter analyze && flutter test`
2. `cd rules_test && npm i && npm test`
3. Partida de prueba con 5 pestañas (ver README). Si algo falla, pásame la salida.

## Limitaciones conocidas del diseño
Ver `docs/SECURITY.md` (anfitrión no es un servidor seguro, presencia aproximada, etc.).
