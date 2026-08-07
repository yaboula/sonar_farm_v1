# RUNBOOK — sonar_farm

Operaciones, despliegue y troubleshooting. Documentacion en espanol; el codigo/UI va en ingles.

---

## 1. Requisitos

- Servidor FiveM (artifacts recientes).
- Recursos iniciados **antes** de `sonar_farm`: `oxmysql`, `qb-core`, `ox_lib`, `ox_inventory`, `ox_target`.
- Base de datos MariaDB/MySQL accesible por `oxmysql`.

Orden recomendado en `server.cfg`:

```cfg
ensure oxmysql
ensure ox_lib
ensure qb-core
ensure ox_inventory
ensure ox_target
ensure sonar_farm
```

`oxmysql` necesita su connection string (ejemplo):

```cfg
set mysql_connection_string "mysql://user:password@localhost/database?charset=utf8mb4"
```

---

## 2. Base de datos (Etapa 2)

El esquema vive en [`database/install.sql`](../database/install.sql) y crea la tabla `farming_crops`.

Hay dos formas de instalar el esquema (ambas soportadas):

1. **Auto-creacion (por defecto):** con `Config.Database.AutoCreateSchema = true`, el recurso ejecuta el DDL al arrancar. Es idempotente (`CREATE TABLE IF NOT EXISTS`), asi que no daña datos existentes.
2. **Import manual:** pon `Config.Database.AutoCreateSchema = false` e importa `database/install.sql` en tu base de datos antes de iniciar el recurso.

Tuning relacionado en [`config/config.lua`](../config/config.lua):

- `Config.SaveInterval` (segundos): frecuencia del guardado por lotes. Default 60.
- `Config.Database.BatchChunkSize`: filas por transaccion en upsert/delete. Default 100.

---

## 3. Modelo de persistencia

- **Fuente de verdad:** estado en RAM (`State.crops`). La DB es respaldo asincrono.
- **Dirty-flags + batch:** los cambios se marcan y se vuelcan cada `SaveInterval` con un patron de **snapshot swap** (no se pierden escrituras durante la transaccion; si falla, los ids se re-encolan).
- **Chunking:** upserts/deletes en lotes de `BatchChunkSize`, siempre con parametros `?`.
- **Crecimiento sin ticks:** se calcula por diferencia de tiempo (`os.time() - planted_at`) solo al consultar (lazy). No hay bucles de crecimiento.

### Ventana de perdida en crash (importante)

El guardado periodico es la **red de seguridad principal**. En un reinicio ordenado (`stop`/`restart`/hot update de txAdmin) se dispara `State.FlushSync()` en `onResourceStop`. En un **crash duro** del servidor pueden perderse como maximo los cambios de la ultima ventana `SaveInterval` (por defecto <= 60s). Baja `SaveInterval` si necesitas menos ventana, a costa de mas escrituras a DB.

---

## 4. Pack de props de plantas (Etapa 4) — REQUISITO

Los cultivos se dibujan con **props custom** (`bzzz_plants_<crop>_01/02/03`), que
viven en su **propio recurso** de streaming. `sonar_farm` no los incluye.

1. Asegurate de que el recurso del pack de plantas esta iniciado en `server.cfg`.
   El orden no importa: los modelos se resuelven en runtime.
2. Los nombres se configuran en [`config/crops.lua`](../config/crops.lua), en `stages[].model`.

### Que pasa si un modelo no existe

Al arrancar, el cliente valida cada modelo con `IsModelValid` y avisa **por nombre**:

```
[sonar_farm] [WARN] Missing crop models: bzzz_plants_lettuce_02 (lettuce). They will render as "prop_plant_01a".
```

Ese aviso existe porque, sin el, un nombre de prop equivocado es invisible:
`CreateObject` falla en silencio y simplemente no aparece nada. El respaldo
(`Config.Render.FallbackModel`) mantiene el cultivo visible e interactuable, asi que
el juego sigue funcionando mientras se corrige el nombre en config.

Si el pack usa otra convencion para algun cultivo, el aviso te dice exactamente que
modelo cambiar. Solo se toca config, nunca codigo.

---

## 5. Items de ox_inventory (Etapa 3)

`ox_inventory` **no permite registrar items en runtime**, asi que hay que copiarlos a mano una vez.

1. Abre [`data/ox_inventory_items.lua`](../data/ox_inventory_items.lua).
2. Copia las entradas de dentro de la tabla a `ox_inventory/data/items.lua`, dentro de la tabla que ese fichero retorna.
3. `restart ox_inventory`.

Items necesarios: `carrot_seed`, `potato_seed`, `lettuce_seed`, `tomato_seed`, `carrot`, `potato`, `lettuce`, `tomato`, `watering_can`.

**Importante (Etapa 4):** las semillas llevan `client.export = 'sonar_farm.useSeed'`.
Eso es lo que permite plantar **usando el item**, que es el gesto que el jugador
intenta primero. Si omites esas lineas no se rompe nada, pero plantar solo sera
posible desde el menu del campo.

Sin imagenes en `ox_inventory/web/images/` los items salen con un placeholder: es suficiente para probar.

Para darte material de prueba:

```
/giveitem <id> carrot_seed 10
/giveitem <id> watering_can 1
```

---

## 6. Comandos de debug (solo con `Config.Debug = true`)

Se registran solo si el debug esta activo.

### Estado y persistencia (servidor, Etapa 2)

Verifican el motor de estado **sin pasar por validaciones** de gameplay.

| Comando | Descripcion |
| --- | --- |
| `/farm_debug_plant [cropType] [growthTime]` | Crea un cultivo de prueba en tus coordenadas (o Grapeseed si es consola). |
| `/farm_debug_dump` | Imprime totales: crops, dirty, deleted, cells, loaded. |
| `/farm_debug_grow [id]` | Evalua el crecimiento por timestamp de un cultivo. |
| `/farm_debug_save` | Fuerza un `State.Flush()` inmediato. |
| `/farm_debug_clear` | Elimina todos los cultivos (los encola para borrado). |

### Bucle de gameplay (cliente, Etapa 3)

Pasan por **toda** la cadena autoritativa: rate limit, cooldown, anti-teleport, zona, inventario y permisos. Es lo que hay que usar para validar la Etapa 3.

| Comando | Descripcion |
| --- | --- |
| `/farm_plant [cropType]` | Planta en tu posicion real (default `carrot`). |
| `/farm_water [cropId]` | Riega. Sin id, coge el cultivo mas cercano. |
| `/farm_harvest [cropId]` | Cosecha. Sin id, coge el cultivo mas cercano. |
| `/farm_near [radio]` | Lista cultivos cercanos segun el servidor (imprime en F8). |

`/farm_water` y `/farm_harvest` resuelven el cultivo mas cercano si no pasas id, para no tener que copiar UUIDs a mano. Todos pasan por la misma capa `Actions` que usa ox_target: no hay logica especial de debug.

### Motor visual (cliente, Etapa 4)

| Comando | Descripcion |
| --- | --- |
| `/farm_render` | Estado del motor visual: cultivos en cache, props dibujados, desfase de reloj, interior si/no, y detalle por prop en F8. |
| `/farm_resync` | Fuerza una resuscripcion inmediata. Util tras editar zonas o cultivos en caliente. |

`/farm_render` es **el comando al que acudir cuando algo se ve raro**: separa los dos
fallos que se confunden entre si. Si `cache=0`, el servidor nunca te hablo de ese
cultivo (problema de suscripcion o de celda). Si `cache>0` pero `props=0`, lo sabes
pero no lo dibujas (problema de modelo, radio, tope o interior).

### Prueba de round-trip de persistencia

1. `/farm_debug_plant carrot 60`
2. `/farm_debug_dump` -> deberia mostrar `crops=1 dirty=1`.
3. `/farm_debug_save` -> `Flush OK` (o espera al guardado periodico).
4. `restart sonar_farm`
5. En consola deberia verse `State engine ready (1 crops loaded)`.
6. `/farm_debug_grow <id>` -> el progreso aumenta con el tiempo.

### Prueba del bucle completo (Etapa 3)

Requiere estar dentro de una zona de `config/zones.lua` (por defecto, campos de Grapeseed) y tener los items.

1. `/giveitem <id> carrot_seed 5` y `/giveitem <id> watering_can 1`.
2. Colocate en la zona -> `/farm_plant carrot`. Debe notificar `Planted Carrot in grapeseed_east`.
3. `/farm_near` -> aparece el cultivo con `growth`, `water` y `health`.
4. `/farm_water` -> `Watered. Water 100%, health ...%`.
5. Riega otra vez de inmediato -> debe rechazar con "does not need water yet" (comprueba `WaterRefillThreshold`).
6. `/farm_harvest` antes de madurar -> "not ready to harvest".
7. Espera `growthTime` (900s para carrot; baja `growthTime` en `config/crops.lua` para probar rapido) -> `/farm_harvest` entrega producto con calidad y tier.

### Prueba del motor visual (Etapa 4)

1. Entra en una zona de cultivo. Debe aparecer el **blip** en el mapa.
2. Apunta al suelo dentro de la zona -> opcion **Plant seeds** de ox_target. El menu muestra tus semillas y desactiva las que no tienes.
3. Alternativa: **usa la semilla** desde el inventario. Debe plantar igual.
4. Tras plantar, el prop debe aparecer **de inmediato** (no al cambiar de celda).
5. `/farm_render` -> `cache` y `props` deben coincidir para los cultivos cercanos.
6. Apunta al cultivo -> **Inspect** muestra crecimiento, agua y salud. **Water** solo aparece si tiene sed; **Harvest** solo si esta maduro o muerto.
7. Alejate mas de 30m -> el prop se destruye. Vuelve -> se recrea.
8. Espera a que cambie de fase (`ratio` en `config/crops.lua`) -> el modelo cambia.
9. Entra en un interior -> los props desaparecen. Sal -> vuelven.
10. Con dos jugadores: A planta y B (cerca) debe ver el prop aparecer sin recargar nada. A cosecha y el prop desaparece para B.
11. `restart sonar_farm` -> **no** deben quedar props huerfanos en el campo.

### Prueba de rendimiento

Con `/farm_render` confirma que los props no pasan de `Config.Render.MaxProps`.
En reposo fuera de zona el recurso debe marcar `0.00 ms` (un solo hilo con espera
de `TickFar`). Dentro de zona, con props dibujados, deberia mantenerse por debajo
de `0.05 ms`.

### Pruebas de seguridad que deberian fallar

| Prueba | Resultado esperado |
| --- | --- |
| `/farm_plant carrot` fuera de toda zona | `You are not inside a farming zone.` |
| `/farm_plant tomato` en `grapeseed_south` | `That crop cannot be planted in this zone.` |
| `/farm_plant carrot` sin semillas | `You do not have the required seeds.` |
| `/farm_water` sin regadera | `You need a watering can.` |
| Repetir `/farm_plant` muy rapido | `Slow down.` (token bucket) |
| Alejarse y `/farm_harvest <id>` | `You are too far away.` |
| Cosechar cultivo ajeno con `OwnerOnlyHarvest = true` | `This crop belongs to someone else.` |
| Plantar mas de `MaxCropsPerPlayer` | `You have reached your active crop limit.` |

---

## 7. Troubleshooting

| Sintoma | Causa probable | Solucion |
| --- | --- | --- |
| `attempt to index a nil value (field 'Crops')` | Los ficheros de `config/` no estan declarados en `fxmanifest.lua` | Asegurate de que `config/config.lua`, `config/crops.lua`, `config/zones.lua` y `config/minigames.lua` estan en `shared_scripts`, y **antes** del resto. |
| `oxmysql is not started. Persistence is unavailable.` | oxmysql no arranco antes | Revisa orden en `server.cfg` y connection string. |
| `Schema creation failed: ...` | Permisos DB o connection string | Verifica credenciales/permisos `CREATE`. |
| `Corrupt data JSON for crop <id>` | Edicion manual del campo `data` | El registro se carga con `data={}`; corrige el JSON en DB si procede. |
| No aparecen los comandos `/farm_debug_*` o `/farm_*` | `Config.Debug = false` | Activa debug en `config/config.lua`. |
| Cambios no persisten tras crash | Ventana `SaveInterval` | Es esperado en crash duro; baja `SaveInterval`. |
| `You do not have the required seeds` teniendolas | Items no instalados en ox_inventory | Copia `data/ox_inventory_items.lua` (seccion 4) y reinicia ox_inventory. |
| `You are not inside a farming zone` en pleno campo | Las coordenadas de `config/zones.lua` no coinciden con tu mapa | Ajusta `center`/`radius`; usa `/farm_near` para ver donde estas respecto a los cultivos. |
| `Movement validation failed` justo al conectar | Falso positivo del anti-teleport | No deberia ocurrir: hay grace period al conectar, TTL de muestra y descarte de coords invalidas. Si pasa, sube `ConnectGracePeriod` y reporta el caso. |
| Cultivos que mueren demasiado rapido | `water.decayPerHour` alto para el ritmo del servidor | Ajusta por cultivo en `config/crops.lua`; `droughtTolerance` amortigua la perdida de salud. |
| Calidad siempre 75 | Es lo esperado en Etapa 3 | El proveedor stub devuelve `Config.Quality.DefaultScore`; los minijuegos llegan en la Etapa 5. |
| `Someone is already working on this crop` sin nadie mas | Doble peticion del mismo cliente | Es el lock anti-duplicacion haciendo su trabajo; reintenta. |
| No aparece ningun prop, pero `/farm_render` dice `cache>0` | Modelos no validos o pack de plantas sin iniciar | Mira el aviso `Missing crop models` al arrancar y la seccion 4. |
| No aparece ningun prop y `cache=0` | El servidor no te ha suscrito | `/farm_resync`. Si sigue en 0, revisa que el cultivo este en tu celda o adyacente (`Config.Sync.CellRadius`). |
| Props flotando o medio enterrados | Terreno en pendiente | `Config.Render.GroundSnap = true` (por defecto). Si persiste, el raycast no encontro suelo y se usa la z guardada. |
| Faltan props en un campo muy poblado | Tope `Config.Render.MaxProps` alcanzado | Es intencionado: se priorizan los mas cercanos. Sube el tope solo si mides el coste. |
| Props visibles dentro de un interior | `Config.Render.SkipInInteriors = false` | Actívalo. Los routing buckets no son legibles desde el cliente, asi que se usa la deteccion de interior. |
| Las plantas se ven en fase equivocada | Reloj del sistema del jugador desfasado | Se corrige solo: el servidor manda `serverTime` y el cliente ajusta el offset. Comprueba `clockOffset` en `/farm_render`. |
| Props huerfanos tras varios `restart` | Version antigua sin limpieza | Ya se destruyen en `onResourceStop`. Los huerfanos previos desaparecen al reconectar. |
| `Plant seeds` no aparece en el campo | Fuera de la zona, o `Config.Zones` mal ubicado | La opcion cubre todo el radio de la zona; si no sale, no estas dentro. |
| Usar la semilla no hace nada | Falta `client.export` en ox_inventory | Ver seccion 5. |

---

## 8. Lecciones aprendidas

- `luac -p` es un smoke test rapido de sintaxis Lua antes de commitear: valida sintaxis, pero **no** detecta ficheros que faltan en `fxmanifest.lua`. Tras anadir un fichero nuevo, verifica siempre que esta declarado en el manifiesto.
- El snapshot swap en `Flush` es imprescindible para no perder escrituras concurrentes durante el `await` de la DB.
- En oxmysql, un array de parametros con un `nil` en medio rompe el binding (Lua no distingue hueco de fin de array). Para columnas nullable, enviar `''` y usar `NULLIF(?, '')` en el SQL.
- Validar la posicion con `GetEntityCoords(GetPlayerPed(source))` en el servidor, no con el `vector3` que envia el cliente. Es la diferencia entre un anti-cheat real y uno decorativo.
- El anti-teleport necesita tolerancia o castiga a jugadores legitimos: al conectar y al cambiar de routing bucket o interior, las coordenadas del servidor son poco fiables (a veces el origen del mapa). Tres guardas lo cubren: la primera muestra solo inicializa la cache, las muestras viejas se descartan y hay grace period al conectar.
- Cada modulo libera en `playerDropped` lo que el mismo reserva (buckets en `ratelimit`, cache de posicion y cooldowns en `validation`). Centralizar la limpieza en un modulo ajeno acopla y se olvida una tabla; los cooldowns eran justo esa tercera tabla facil de olvidar.
- En cosecha, el orden importa: comprobar `CanCarry`, entregar el item y **solo entonces** borrar el cultivo. Al reves, un inventario lleno destruye la cosecha.
- Un lock por `cropId` durante la accion evita que dos cosechas simultaneas entreguen producto dos veces. Es barato y cubre el caso que no aparece en pruebas manuales pero si el dia que dos jugadores pulsan a la vez.
- El servidor devuelve codigos (`too_far`), no frases. El cliente traduce. Asi el servidor queda agnostico al idioma y no hay textos duplicados.
- `data/ox_inventory_items.lua` se envuelve en `return { ... }` para que sea Lua valido y pase `luac -p`, aunque su uso real sea copiar y pegar en ox_inventory.
- Si el cliente va a predecir crecimiento, la formula tiene que estar en **un solo fichero** compartido, no duplicada. Con dos copias la divergencia es cuestion de tiempo, y se manifiesta como "la planta se ve madura pero el servidor no me deja cosechar".
- Predecir desde timestamps solo es seguro si ambos lados comparten el mismo "ahora". Un jugador con la hora del sistema mal veria fases equivocadas, asi que el servidor manda `serverTime` en cada sincronizacion y el cliente guarda el offset.
- Un snapshot que reemplaza la cache puede tragarse los deltas que llegan durante el viaje de ida y vuelta. Hay que **bufferearlos** mientras la suscripcion esta en vuelo y reaplicarlos despues, o un cultivo plantado en esa ventana queda invisible hasta el siguiente cambio de celda.
- Las celdas suscritas se derivan de la posicion real en el servidor y el callback **no acepta argumentos**. Si el cliente pudiera nombrar sus celdas, podria volcar todos los cultivos del mapa y sus propietarios.
- Al cliente se le manda `isMine`, nunca el `citizenid` ajeno. No hay ninguna funcionalidad que lo necesite y filtrarlo alimenta metagaming.
- `canInteract` de ox_target se ejecuta mientras el jugador apunta, asi que no puede contener busquedas. Capturar el `cropId` en el closure de la opcion (los props se recrean en cada cambio de fase, asi que siempre esta ligado al cultivo correcto) sale gratis; buscar el id recorriendo el pool costaria por frame.
- La distancia de ox_target debe quedar **por debajo** de `MaxInteractDistance`. Igualarlas hace que el jugador vea rechazos `too_far` apuntando a algo que el target le dejaba pulsar.
- Sin `onResourceStop` que destruya los props, cada `restart` en desarrollo deja objetos huerfanos que nadie puede borrar. Se sufre veinte veces al dia.
- No existe un native fiable para escalar props, asi que la variacion visual es solo rotacion. Derivarla del `cropId` (y no de `math.random`) es lo que garantiza que dos jugadores vean la misma planta igual.
- La validacion de modelos al arrancar no es un lujo: sin ella, un nombre de prop equivocado no da ningun error, simplemente no aparece nada, y se pierde una tarde depurando el streaming.
