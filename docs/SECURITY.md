# Modelo de confianza y limitaciones

EL ASESINO funciona **sin Cloud Functions ni servidor propio** (Firebase Spark).
La lógica de juego se ejecuta en el dispositivo del **anfitrión**, que actúa como
*moderador*. Esto condiciona qué se puede garantizar.

## Qué protegen las reglas de Firestore (`firestore.rules`)

| Dato | Quién lo lee | Quién lo escribe |
|---|---|---|
| `rooms/{code}` (fase, ronda, config, narración) | cualquiera que conozca el código (`get`); no hay `list` | anfitrión (transiciones válidas, versión +1) |
| `members/{uid}` | miembros de la sala | el propio jugador al unirse; el anfitrión gestiona estado |
| `private/{uid}` (rol secreto) | **sólo su dueño y el anfitrión** | sólo el anfitrión |
| `hostState/state` (estado completo) | sólo el anfitrión | sólo el anfitrión |
| `actions/{ronda}_{uid}` | anfitrión y su autor | autor, **una sola vez**, fase y turno correctos, rol coincidente |
| `votes/{seq}_{uid}` | anfitrión y su autor (voto secreto real) | autor, una sola vez, fase correcta |
| `presence/{uid}` | sólo el anfitrión | el propio jugador |

Además:
* Los roles **no se envían** a quien no puede leerlos; no hay ocultación sólo visual.
* Un jugador eliminado no puede actuar ni votar (regla `isAliveMember`).
* El anfitrión no puede saltarse fases (`validNext`) ni retroceder de ronda.
* Si el anfitrión deja de latir >45 s, cualquier miembro puede tomar el relevo
  (la regla compara con la hora del **servidor**).

## Chat
`rooms/{code}/chat/*`: lo leen los miembros; escribe cualquier miembro **con su propio nombre**
(la regla lo comprueba contra su documento), con 1–200 caracteres. De noche está cerrado y los
eliminados sólo pueden hablar en el lobby y al terminar. La frecuencia (anti-spam) sólo se limita
en el cliente: un cliente modificado podría saltársela.

## Si el anfitrión también juega
En la interfaz, el anfitrión **no ve** los roles ajenos (sólo su carta y sus pistas). A nivel de
datos sí puede leerlos (es quien resuelve la noche), así que sólo los vería manipulando su cliente.
Para una moderación sin ventaja, usa narrador humano que **no juega**.

## Regla extra del motor
Duelo de 2 vivos donde ninguno puede matar de noche: el empate se resuelve al azar (evita partidas
infinitas).

## Qué NO se puede garantizar

1. **El anfitrión ve todos los roles.** Necesita leerlos para resolver la noche.
   Un anfitrión con el cliente modificado puede ver roles, alterar resultados,
   falsear escrutinios o expulsar a quien quiera. **No es antitrampas.**
2. **El reparto de roles no es verificable** por los demás jugadores.
3. **Un cliente modificado** (cualquier jugador) puede intentar enviar datos
   arbitrarios; las reglas limitan *qué* y *cuándo*, pero no pueden recalcular
   la lógica del juego como haría un servidor.
4. **Sin anfitrión no hay partida.** Si todos los clientes se desconectan, no se
   ejecuta nada. El estado se conserva en `hostState` y se reanuda al volver.
5. **Recuperación imperfecta tras el relevo:** el nuevo anfitrión reconstruye el
   estado desde `hostState` (último punto guardado, atómico con cada transición).
   Pasa a ver todos los roles. Si el anfitrión anterior era un narrador humano
   que no jugaba, el nuevo anfitrión pasa a modo automático.
6. **La presencia es aproximada** (latidos cada 60 s); no hay detección nativa de
   conexión en Firestore.
7. **El nombre de la sala y los jugadores se pueden leer** conociendo el código
   (6 caracteres, ~887 millones de combinaciones). Evita compartirlo en público.
8. **Las reglas no sustituyen a Cloud Functions.** Es una arquitectura pensada
   para jugar entre amigos, no para torneos con desconocidos.

## Buenas prácticas

* Activa **Firebase App Check** (reCAPTCHA v3 en web) para limitar abusos desde
  fuera de tu app. Es gratuito, pero requiere configurarlo en la consola.
* Restringe la clave de API web por dominio en Google Cloud Console.
* No uses el modo de prueba de Firestore: publica `firestore.rules`.
* No incluyas claves de administración ni el SDK Admin en la app.
