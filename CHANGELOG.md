# Changelog

Todos los cambios relevantes de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y el proyecto se adhiere a [Versionado Semantico](https://semver.org/lang/es/).

## [Unreleased]

### Changed

- `Growth.Evaluate` y la evaluacion pura de `Physiology` se mueven a `shared/` (`shared/growth.lua`, `shared/physiology.lua`). El cliente predice el crecimiento para renderizar, y con dos copias de la formula la divergencia seria cuestion de tiempo. Los mutadores (`Physiology.Apply`, `Physiology.Water`) siguen siendo exclusivos del servidor.
- `Validation.CropLimit` ya no recorre todo el estado: `State` mantiene un indice por propietario (`State.owners`, `State.CountByOwner`) actualizado en `Add`, `Remove`, `Update` y `LoadAll`. Era la deuda declarada al cerrar la Etapa 3.

### Fixed

- `Utils.Uuid` generaba 23 caracteres en lugar de un UUID4 completo de 36. Los ids de cultivo eran ambiguos y se habrian vuelto colisionables al crecer el volumen.
- Los ficheros de `config/` no estaban declarados en `fxmanifest.lua`, por lo que `Config.Crops`, `Config.Zones` y `Config.Minigames` nunca se cargaban. Provocaba `attempt to index a nil value (field 'Crops')` al plantar. Ahora `config/` se carga primero en `shared_scripts`.
- Accesos a `Config.Crops` blindados en `state.lua` y `growth.lua` (no asumen que la tabla exista).
- `serializeRow` ya no puede generar huecos `nil` en el array de parametros (rompia el binding de oxmysql cuando `owner`/`zone`/`data` eran nulos). Las columnas nullable se envian como `''` y se convierten a `NULL` con `NULLIF(?, '')`.

### Added

- **Etapa 4 — Motor Visual y Optimizacion (Stream & Culling):**
  - Suscripcion por celdas espaciales (`server/modules/sync/subscriptions.lua`): snapshot al cambiar de celda y deltas dirigidos solo a los suscriptores de la celda afectada. Un campo lleno de cultivos creciendo no genera trafico de red.
  - Las celdas suscritas se derivan de la posicion real en el servidor y el callback `sonar_farm:subscribe` no acepta argumentos, para que un cliente modificado no pueda volcar los cultivos de todo el mapa.
  - Prediccion en cliente: el payload lleva timestamps en lugar de estado calculado y el cliente deriva crecimiento y condicion con las formulas compartidas.
  - Reloj compartido (`shared/time.lua`): el servidor envia `serverTime` y el cliente corrige su offset, para que una hora de sistema desfasada no altere las fases que se dibujan.
  - `isMine` por destinatario en lugar del `citizenid`: el identificador de otro jugador nunca llega a un cliente.
  - Pool generico de entidades (`client/modules/render/pool.lua`): props no networkeados (cero NetIDs, cero trafico de fisica), agnostico al contenido y reutilizable por la maquinaria de la Etapa 9.
  - Renderizado de cultivos (`client/modules/render/crops.lua`): fases por ratio, snap al suelo por raycast, rotacion determinista derivada del `cropId`, radio de 30m y tope duro de props priorizando los mas cercanos.
  - Validacion de modelos al arrancar con aviso por nombre y respaldo en runtime, porque un nombre de prop equivocado no produce ningun error visible.
  - Interaccion anclada al prop con `ox_target` (`client/modules/render/target.lua`): opciones filtradas con `canInteract`, `Inspect` con estado real y distancia por debajo del umbral del servidor para que un rechazo por distancia sea imposible en juego legitimo.
  - Hilo unico de intervalo adaptativo (`client/modules/sync/client.lua`) con buffer de deltas durante la suscripcion, para no perder cultivos plantados en la ventana de ida y vuelta.
  - Capa unica de acciones (`client/modules/interaction/actions.lua`) con traduccion de rechazos y **autocorreccion**: un rechazo por cache obsoleta fuerza resuscripcion.
  - Plantar usando el item de semilla (`client.export` en ox_inventory) y menu de campo por zona como alternativa descubrible.
  - Blips de zona configurables (`client/modules/zones/blips.lua`).
  - Comandos de diagnostico `/farm_render` y `/farm_resync`.
  - Configuracion nueva: `Config.Sync` y `Config.Render`; sub-tabla `blip` por zona; modelos custom `bzzz_plants_*` en `config/crops.lua`.
  - Wrapper `Bridge.Target.AddSphereZone`, que encaja con zonas definidas por centro y radio.

- **Etapa 3 — Logica Autoritativa, Anti-Exploit y Fisiologia Vegetal:**
  - Bucle de gameplay completo como callbacks de `ox_lib` con respuesta uniforme `{ ok, reason, data }`: `sonar_farm:plant`, `sonar_farm:water`, `sonar_farm:harvest` y la consulta de solo lectura `sonar_farm:nearby`.
  - Posicion validada siempre en servidor con `GetEntityCoords(GetPlayerPed(source))`; las coordenadas del cliente se ignoran, lo que elimina noclip e interaccion a distancia.
  - Rate limiting por token bucket sin ticks (`server/modules/security/ratelimit.lua`), con recarga perezosa por tiempo transcurrido.
  - Validacion multinivel (`server/modules/security/validation.lua`): cooldown por accion, distancia real, anti-teleport, zona y cultivo permitido, herramienta, estado del cultivo, permisos y limite de cultivos por jugador.
  - Anti-teleport con tres guardas para no castigar a jugadores legitimos: la primera muestra solo inicializa la cache, las muestras obsoletas se descartan (cambio de routing bucket o interior) y hay grace period tras conectar.
  - Fisiologia vegetal sin ticks (`server/modules/farming/physiology.lua`): agua, salud y merma derivadas de timestamps con `Evaluate` puro y `Apply` como unico mutador.
  - Abstraccion de calidad (`server/modules/farming/quality.lua`): registro de proveedores con stub por defecto, formula de calidad final (puntuacion + cuidado, penalizada por merma, robo y techo mecanizado) y rendimiento interpolado por calidad.
  - Lock por cultivo en vuelo (`server/modules/farming/lock.lua`) que impide que dos cosechas simultaneas entreguen producto dos veces.
  - Permisos separados de cuidado y cosecha: `AllowPublicCare` permite salvar el cultivo de otro sin derecho sobre el producto, `OwnerOnlyHarvest` protege la cosecha, y el robo (cuando se habilita) penaliza la calidad y se registra.
  - Eventos publicos para integraciones: `sonar_farm:cropPlanted`, `sonar_farm:cropWatered`, `sonar_farm:cropHarvested`.
  - Contenido: 4 verduras con fisiologia diferenciada (carrot, potato, lettuce, tomato), 2 zonas de Grapeseed (una con cultivos restringidos) e items de ox_inventory en `data/ox_inventory_items.lua`.
  - Configuracion nueva: `Config.Security`, `Config.Cooldowns`, `Config.Farming` y `Config.Quality`.
  - Comandos de cliente para probar el bucle real (`/farm_plant`, `/farm_water`, `/farm_harvest`, `/farm_near`), con traduccion de codigos de rechazo en el cliente.
  - Documentacion: `docs/API.md` (callbacks, codigos de rechazo, eventos y punto de extension de calidad).

- **Etapa 2 — Motor de Estado en Memoria y Persistencia Asincrona:**
  - Esquema `farming_crops` (`database/install.sql`) con clave UUID generada en servidor, indice espacial `cell` y columna JSON `data`.
  - Capa de base de datos (`server/modules/database/database.lua`): init con espera de oxmysql, auto-creacion de esquema opcional por flag, y wrappers `LoadAllCrops`/`UpsertCrops`/`DeleteCrops` parametrizados y troceados en chunks.
  - Motor de estado en RAM (`server/modules/state/state.lua`): hot-state como fuente de verdad, indice espacial por celdas, dirty/deleted flags, y `Flush` con patron snapshot swap + re-encolado en fallo. Carga con decodificacion JSON segura (`pcall`).
  - Evaluador de crecimiento por timestamp (`server/modules/state/growth.lua`): funcion pura sin ticks (lazy evaluation).
  - Guardado por lotes cada `SaveInterval` y guardado de emergencia en `onResourceStop`.
  - Comandos de debug server-side (`server/modules/debug/commands.lua`) gated por `Config.Debug`.
  - Configuracion `Config.Database` (auto-creacion + tamano de chunk) y constante `SPATIAL_CELL_SIZE`.
  - Documentacion operativa: `docs/RUNBOOK.md`.

- **Etapa 1 — Bootstrap y Bridge Layer:**
  - Estructura de carpetas de nivel empresarial (`config/`, `shared/`, `bridge/`, `server/`, `client/`, `web/`).
  - `fxmanifest.lua` con dependencias ox, `lua54` y orden de carga controlado.
  - Configuracion base (`config/config.lua`) con override de framework, debug, intervalo de guardado y feature flags. Placeholders data-driven para `crops`, `zones` y `minigames`.
  - Constantes y utilidades compartidas (`shared/constants.lua`, `shared/utils.lua`).
  - Capa de abstraccion (Bridge Layer): deteccion automatica de framework via `GetResourceState`, interfaz publica y adaptador completo de QB-Core con stubs desacoplados para ESX y Qbox.
  - Wrappers de inventario (ox_inventory) y target (ox_target).
  - Logger de servidor con niveles `INFO`/`WARN`/`EXPLOIT` y conectores desacoplados (consola; Discord/DB como stubs).
  - Smoke test de arranque ("Bridge ready") en servidor y cliente.
