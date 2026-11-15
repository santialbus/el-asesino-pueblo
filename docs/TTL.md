# Limpieza automática de salas (TTL de Firestore)

Cada documento que escribe la app lleva un campo `expireAt` (Timestamp):

| Documento | Caduca |
|---|---|
| `rooms/{code}`, `chat/*` | 24 h tras la **última transición** del anfitrión (se renueva en cada fase) |
| `members`, `private`, `hostState`, `presence`, `actions`, `votes` | 48 h tras escribirse (presencia se renueva con cada latido) |

Una sala abandonada (nadie la cierra) desaparece sola. Si el anfitrión pulsa
«Cerrar la sala» o sale del lobby, se borra al momento.

## Activarlo (una sola vez, hay que hacerlo en cada grupo de colecciones)

La TTL borra **sólo el documento que caduca**, no sus subcolecciones; por eso hay
una política por cada colección. Consola de Firebase → Firestore → pestaña
**Time-to-live (TTL)** → «Crear política», campo `expireAt`, para estos grupos:

`rooms` · `members` · `private` · `hostState` · `presence` · `actions` · `votes` · `chat`

O con la CLI de Google Cloud (proyecto `el-asesino-f0e55`):

```bash
for g in rooms members private hostState presence actions votes chat; do
  gcloud firestore fields ttls update expireAt \
    --collection-group=$g --enable-ttl --project=el-asesino-f0e55
done
```

Notas:
* El borrado no es instantáneo: Firestore lo hace en segundo plano, normalmente
  en las 24 h siguientes a la caducidad.
* Comprueba en la documentación vigente de Firebase cómo cuentan los borrados por
  TTL en la cuota gratuita del plan Spark (puede cambiar).
* Si cambias los plazos, edita `_roomTtl` y `_subTtl` en `firestore_backend.dart`.
