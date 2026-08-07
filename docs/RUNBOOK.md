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

## 4. Items de ox_inventory (Etapa 3)

`ox_inventory` **no permite registrar items en runtime**, asi que hay que copiarlos a mano una vez.

1. Abre [`data/ox_inventory_items.lua`](../data/ox_inventory_items.lua).
2. Copia las entradas de dentro de la tabla a `ox_inventory/data/items.lua`, dentro de la tabla que ese fichero retorna.
3. `restart ox_inventory`.

Items necesarios: `carrot_seed`, `potato_seed`, `lettuce_seed`, `tomato_seed`, `carrot`, `potato`, `lettuce`, `tomato`, `watering_can`.

Sin imagenes en `ox_inventory/web/images/` los items salen con un placeholder: es suficiente para probar.

Para darte material de prueba:

```
/giveitem <id> carrot_seed 10
/giveitem <id> watering_can 1
```

---

## 5. Comandos de debug (solo con `Config.Debug = true`)

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
| `/farm_near [radio]` | Lista cultivos cercanos con estado, agua y salud (imprime en F8). |

`/farm_water` y `/farm_harvest` resuelven el cultivo mas cercano si no pasas id, para no tener que copiar UUIDs a mano.

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

## 6. Troubleshooting

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

---

## 7. Lecciones aprendidas

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
