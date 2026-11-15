# Arquitectura

```
packages/asesino_core/        Dart puro (sin Flutter ni Firebase): TODA la lógica
  lib/src/domain/             reglas: config, roles, noche, votos, victoria, fases
  lib/src/application/        modelos de documentos, contrato GameBackend,
                              HostCoordinator (anfitrión), vistas de jugador
  lib/src/testing/            backend en memoria con reglas emuladas, relojes (falso/real)
                              y bots (BotPlayer/BotDriver, usados también por el modo local)
  test/                       63 pruebas de dominio, 47 de simulación, 1 de estrés
lib/                          app Flutter
  app/                        tema (paleta) y raíz
  core/services/              ajustes, sesión, música y vibración
  features/game/data/         FirestoreBackend (implementa GameBackend)
  features/game/application/  providers de Riverpod
  features/game/presentation/ sala, fases, barra del anfitrión
  features/lobby|home|settings
  shared/widgets/             fondo pintado, cartas, controles
firestore.rules               seguridad
```

## Flujo de una partida

`LOBBY → ROLE_REVEAL → NIGHT (un paso por rol) → DAWN → DISCUSSION → VOTING →
VOTE_RESULT → (VICTORY_CHECK) → NEXT_ROUND/NIGHT … → FINISHED`

* El anfitrión ejecuta `HostCoordinator`: recibe acciones/votos, los valida con
  `ActionValidator`/`VoteResolver`, resuelve con `NightResolver`, y publica cada
  transición con **una sola transacción** (`Commit`): sala + documentos privados
  + miembros + `hostState` + limpieza de acciones y votos.
* `version` en `rooms/{code}` da control de concurrencia optimista: si otro
  dispositivo toma el relevo, el anfitrión antiguo recibe un conflicto y se detiene.
* Los temporizadores son **locales**: la sala guarda `phaseDurationMs` y cada
  cliente cuenta atrás desde que recibe la versión; no hay escrituras por segundo.
* Los pasos de la noche son secuenciales; un rol sin jugadores vivos igualmente
  "despierta" (turno señuelo) para no delatar quién ha muerto.

## Coste en Firebase Spark (orientativo)

* Escrituras: 1 por jugador y minuto (presencia) + 1 transacción del anfitrión por
  transición (≈ 8–12 por ronda) + 1 acción/voto por jugador y fase.
* Lecturas: listeners sobre sala y miembros (sólo se descargan los documentos que
  cambian), `private/{uid}` propio; el anfitrión además escucha acciones, votos
  y presencia. Los listeners se cierran al salir (`autoDispose`).
* Cuotas diarias del plan Spark (consúltalas, pueden cambiar): lecturas, escrituras
  y borrados por día. Una partida de 8 personas y ~1 h consume una fracción
  pequeña; decenas de partidas simultáneas diarias podrían acercarse al límite.
  Si se alcanza, la app muestra un error comprensible.
