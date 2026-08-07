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

## 4. Comandos de debug (solo con `Config.Debug = true`)

Sirven para verificar el motor de estado sin gameplay real. Se registran solo si el debug esta activo.

| Comando | Descripcion |
| --- | --- |
| `/farm_debug_plant [cropType] [growthTime]` | Crea un cultivo de prueba en tus coordenadas (o Grapeseed si es consola). |
| `/farm_debug_dump` | Imprime totales: crops, dirty, deleted, cells, loaded. |
| `/farm_debug_grow [id]` | Evalua el crecimiento por timestamp de un cultivo. |
| `/farm_debug_save` | Fuerza un `State.Flush()` inmediato. |
| `/farm_debug_clear` | Elimina todos los cultivos (los encola para borrado). |

### Prueba de round-trip de persistencia

1. `/farm_debug_plant carrot 60`
2. `/farm_debug_dump` -> deberia mostrar `crops=1 dirty=1`.
3. `/farm_debug_save` -> `Flush OK` (o espera al guardado periodico).
4. `restart sonar_farm`
5. En consola deberia verse `State engine ready (1 crops loaded)`.
6. `/farm_debug_grow <id>` -> el progreso aumenta con el tiempo.

---

## 5. Troubleshooting

| Sintoma | Causa probable | Solucion |
| --- | --- | --- |
| `attempt to index a nil value (field 'Crops')` | Los ficheros de `config/` no estan declarados en `fxmanifest.lua` | Asegurate de que `config/config.lua`, `config/crops.lua`, `config/zones.lua` y `config/minigames.lua` estan en `shared_scripts`, y **antes** del resto. |
| `oxmysql is not started. Persistence is unavailable.` | oxmysql no arranco antes | Revisa orden en `server.cfg` y connection string. |
| `Schema creation failed: ...` | Permisos DB o connection string | Verifica credenciales/permisos `CREATE`. |
| `Corrupt data JSON for crop <id>` | Edicion manual del campo `data` | El registro se carga con `data={}`; corrige el JSON en DB si procede. |
| No aparecen los comandos `/farm_debug_*` | `Config.Debug = false` | Activa debug en `config/config.lua`. |
| Cambios no persisten tras crash | Ventana `SaveInterval` | Es esperado en crash duro; baja `SaveInterval`. |

---

## 6. Lecciones aprendidas

- `luac -p` es un smoke test rapido de sintaxis Lua antes de commitear: valida sintaxis, pero **no** detecta ficheros que faltan en `fxmanifest.lua`. Tras anadir un fichero nuevo, verifica siempre que esta declarado en el manifiesto.
- El snapshot swap en `Flush` es imprescindible para no perder escrituras concurrentes durante el `await` de la DB.
- En oxmysql, un array de parametros con un `nil` en medio rompe el binding (Lua no distingue hueco de fin de array). Para columnas nullable, enviar `''` y usar `NULLIF(?, '')` en el SQL.
