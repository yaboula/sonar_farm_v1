# Changelog

Todos los cambios relevantes de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y el proyecto se adhiere a [Versionado Semantico](https://semver.org/lang/es/).

## [0.4.0] - 2026-08-10

### Added — Company Fields, Work y Land Runtime

- Catálogo versionado de Fields importado idempotentemente a MySQL, con IDs
  estables para Field, Row y Slot, checksums, revisiones draft y activación segura.
- Propiedad permanente de Fields, Starter Field atómico durante el bootstrap,
  preparación de compra por Manager y confirmación física por Owner.
- Crop Plans con reservas exclusivas de Rows, Assignments y Public Contracts con
  requisitos estructurados, escrow, progreso por evento y revisión pagada.
- Company Cargo recuperable, lotes agrícolas del Warehouse y Buyer Orders con
  reserva exacta por calidad, vencimiento y crédito único a Treasury.
- Suscripción NUI por Field y streaming espacial de topologías cercanas sin
  registrar todos los targets del mapa permanentemente.

### Security and rollout

- Worker y Contractor reciben solamente los Fields, Rows y acciones cubiertos
  por Work activo; Route, plantación, cuidado, cosecha y depósito se revalidan
  en servidor.
- `Fields` y `Land & Fields` se activan inicialmente en modo read-only. Work,
  Company authority, Cargo, Public Contracts y Buyer Orders mantienen flags
  independientes y apagados por defecto.

### Added — Simulación Agrícola Proporcional al Ciclo V2

- Añadido `Sonar.CropClock` como autoridad del tiempo biológico normalizado.
- Las nuevas plantaciones persisten `simulationVersion = 2` y
  `growthAdjustmentRatio`; los registros V1 conservan exactamente su modelo.
- Añadidas tasas por ciclo, bandas Green/Watch/Critical, protecciones relativas,
  historial/diagnóstico proporcional y calibración determinista de muerte.
- Añadidas regresiones para ciclos de 20 minutos, 40 minutos y 6 horas, ventanas
  de abandono, madurez Green/Watch y catálogo generado.

### Changed — Simulación Agrícola Proporcional al Ciclo V2

- Cambiar `growthTime` escala toda la biología sin alterar cooldowns, minijuegos,
  Supplies, Warehouse, delivery, restock ni refrescos UI.
- Supplies muestra cobertura en porcentaje de ciclo y el menú de cuidado añade
  la duración real resuelta para el cultivo seleccionado.
- Las curvas de inspección conservan únicamente historial hasta `NOW`; el
  horizonte diagnóstico equivale al 10 % del ciclo.
- Optimizada la ruta caliente de `ox_target`: todas las acciones de un cultivo
  reutilizan una snapshot agronómica breve y booleans precomputados.
- `Growth` y `Physiology` comparten una única trayectoria V2; la madurez histórica
  se memoiza, persiste y sincroniza para no repetir búsquedas binarias.
- El render conserva la etapa visual durante cinco segundos y dispersa por crop
  las reevaluaciones, sin modificar la autoridad fresca de las acciones servidor.

### Added — Crop Inspection Pulse Rail

- Añadido un HUD agronómico transparente y sin foco que sustituye la
  notificación genérica de Inspect.
- Añadido `Sonar.Inspection.Build`, evaluador compartido de historial, forecast,
  ETA, protecciones, estados especiales y diagnóstico causal.
- Añadido el callback autoritativo `sonar_farm:inspect` con validación de runtime,
  instancia, distancia, existencia y rate limit.
- Añadida una tercera superficie React/Vite al shell NUI único, con actualización
  local, cierre exhaustivo y adaptación al minimapa/safe-zone.
- Añadidas pruebas Lua, frontend, shell, CI, packaging y QA visual a 720p, 1080p
  y ultrawide.

### Changed — Crop Inspection Pulse Rail visual pass

- Reforzada la jerarquía de Growth, Health, condiciones y referencias de tiempo
  con valores grandes y peso 700, incluido el breakpoint de 1280×720.
- Ajustadas transparencia, curvas monotónicas, escala adaptativa basada en datos,
  glow, área real y forecast discontinuo para acercar el HUD a la referencia.
- El frontend de producción ahora arranca vacío y el build rechaza cualquier
  fixture compilado; solo `inspection:open` autoritativo puede mostrar datos.
- Sustituido el diagnóstico dominante y eliminada la acción recomendada por una
  Field Guide pasiva de seis lecciones agronómicas que rota sin tráfico adicional.
- Las curvas ahora comunican el estado autoritativo mediante tonos semánticos:
  riesgo, vigilancia, correcto y un gris neutro para condiciones no afectadas.
- El chart de inspección queda definido como historial autoritativo hasta NOW,
  sin proyección visual; conserva la evaluación futura únicamente para diagnóstico.
- Corregidos el bonus Green Zone, la retención hídrica, los timers de protección,
  los umbrales por cultivo y la estimación de calidad con planting score real.

## [0.3.0] - 2026-08-09

### Added — Supplies Runtime, Warehouse e Items V2

- Añadido un catálogo canónico de 21 objetos que genera las definiciones de
  `ox_inventory` y gobierna precios, peso, tier, efectos y durabilidad.
- Añadido el núcleo autoritativo de Company: membresías, roles, permisos,
  Treasury, presupuesto mensual, stock del proveedor, pedidos, receipts,
  entregas, Warehouse, custodia, ledger inmutable y outbox de reconciliación.
- Añadidas sesiones NUI con nonce y presencia validada por servidor. Tablet
  prepara pedidos; Office confirma; Warehouse físico retira y devuelve.
- Añadida entrega diferida e idempotente, consumo por slot exacto, desgaste de
  herramientas y protección residual de nutrientes y plagas.
- Añadido un shell NUI único que aísla Business Hub y minijuego, junto con el
  adaptador FiveM real. Los fixtures quedan limitados a navegador y Sites.
- Regenerados los 21 assets RGBA transparentes en estilo 3D clay/cartoon, con
  previews y validación automática de dimensiones, alfa, safe area y hashes.

### Changed

- `Config.Features.Supplies` se distribuye desactivado por defecto para rollout
  controlado. Company Treasury es el único pagador de suministros.

## [0.2.0] - 2026-08-09

### Added — Advanced Crop Care

- Añadido un modelo causal opcional y autoritativo de nutrientes, malas hierbas
  y plagas, con gating global y por cultivo, trayectorias compartidas y
  acumuladores persistentes dentro de `record.data`.
- El déficit sostenido de agua/nutrientes puede ralentizar el crecimiento; la
  ventana crítica de cada cultivo amplifica el impacto histórico.
- Añadidas las acciones `fertilize`, `weed` y `treatPest`, nuevos objetos de
  inventario, targets condicionados, sincronización e inspección del estado.
- Separadas producción y calidad en cosecha, incluyendo `productionScore` y un
  defecto dominante visible en metadata cuando Advanced Care está habilitado.
- El sistema se distribuye con `Config.Features.AdvancedCare = false`; apagado
  conserva el comportamiento y los payloads anteriores.
- La penalización de crecimiento puede detener, pero nunca invertir, el
  progreso; la ventana crítica sigue el progreso biológico efectivo de los
  cultivos retrasados. La configuración operativa se valida antes de aceptar
  herramientas o consumir tratamientos.

### Added — Releases

- La versión del recurso se centraliza en `VERSION` y se valida contra
  `fxmanifest.lua` y `CHANGELOG.md` desde CI.
- Nuevo workflow por tags `vX.Y.Z` que verifica, prueba, construye la NUI,
  empaqueta el recurso limpio y publica la GitHub Release.
- Documentado que el contrato frontend `1.0.0` tiene versionado independiente
  del recurso FiveM.

### Fixed — Persistencia

- Los lotes de `State.Flush` ya no se consideran guardados cuando
  `MySQL.transaction.await` devuelve `false`; el estado dirty se conserva para
  reintento y una regresión cubre explícitamente ese contrato de `oxmysql`.

### Closed — Farm Business Hub Frontend V1

- Congelado el contrato frontend `1.0.0`: canvas 1440×810, 35 rutas, siete
  roles, dos superficies, cuatro presencias, estados compartidos y los 11
  flujos esenciales del producto.
- Centralizado el catálogo de rutas en `web/src/frontendV1Contract.ts` para que
  React y el futuro adapter FiveM compartan una única fuente de verdad.
- Añadida la puerta de release con límites de autoridad, deuda aceptada y
  condiciones de entrada a integración en
  `docs/FARM_BUSINESS_HUB_FRONTEND_V1_RELEASE.md`.
- Cierre validado con 80 tests frontend, build/Sites, 51 archivos Lua parseados,
  18 regresiones Lua, revisión de secretos y QA visual Office/Tablet.

### Added — Etapa 5.1 · Tomato Initial Planting

- NUI independiente en `minigames-ui/` con React, TypeScript y Canvas 2D; no
  comparte build ni rutas con el Business Hub en `web/`.
- Flujo jugable de cuatro pasos: preparar el hoyo, colocar el trasplante,
  cubrir raíces y regar. El feedback durante el trabajo es cualitativo.
- Contrato de trazas normalizadas a 20 Hz, payload limitado y checkpoints
  ordenados. El servidor valida geometría/duración y recalcula profundidad,
  alineación, aireación e hidratación.
- Sesiones autoritativas con reserva de slot, pausa por cancelación/daño,
  reanudación, expiración y limpieza explícita de plantados incompletos.
- Consumo transaccional de `tomato_seedling` al commit final. Un intento
  abandonado no crea un cultivo plantado ni consume material.
- Estados persistentes `planting` y `planting_failed`; ambos ocupan el slot pero
  no crecen, no se riegan y no generan un prop de cultivo.
- La calidad validada de plantación se conserva en `record.data` e influye en la
  calidad final de cosecha junto con habilidad de cosecha y cuidado.
- Assets runtime verificados y aislados del golden source de `temp/`, contrato
  versionado, pruebas TypeScript y regresiones Lua para scoring determinista.

### Stabilized — Puerta obligatoria de Etapas 1–4

- Runtime fail-closed con estados explícitos `BOOTING`, `READY`, `FAILED` y
  `STOPPING`. Las acciones y suscripciones se rechazan hasta completar Bridge,
  migraciones y carga de estado; un error SQL ya no se interpreta como tabla
  vacía.
- Validación de configuración al arranque para frameworks, ACE, cultivos,
  modelos, zonas, slots, límites, sincronización, render y routing buckets.
- QB-Core es el único adaptador operativo. La autodetección es determinista y
  ESX/Qbox fallan con un error claro mientras sigan siendo stubs.
- `Config.Debug = false` por defecto. Todos los comandos de diagnóstico,
  operaciones destructivas y constructores requieren además el ACE
  `sonar_farm.admin`; debug nunca concede privilegios por sí mismo.
- Farming público limitado por defecto al routing bucket `0`, con cancelación
  de suscripción y limpieza del cliente al cambiar de instancia.
- Eliminado el callback legado `sonar_farm:nearby`, que exponía identificadores.
  Las suscripciones tienen ahora un token bucket separado y logs de flood
  amortiguados.
- Estado endurecido: UUID con semilla de entropía, comprobación de colisión,
  índices de celda/propietario/slot verificados al cargar, detección de slots
  huérfanos, cultivos desconocidos, duplicados y reparación de celdas obsoletas.
- La persistencia nullable usa arrays densos: strings mediante `''` y
  `NULLIF(?, '')`; slots mediante `0` y `NULLIF(?, 0)`.
- Resuscripción forzada tras hot restart y buffer de deltas durante snapshots.
  El pool administra cultivos y props de slots por tags independientes.
- Restaurados tiempos de crecimiento de producción para los cuatro cultivos.
- Suite Lua ejecutable fuera de FiveM y CI para parseo, regresiones, whitespace
  y detección básica de secretos. Esta puerta cerró las Etapas 1–4 antes de
  habilitar el primer corte de minijuegos.

### Added

- **Zone Builder premium (`/farm_builder`):** Herramienta de administración in-game para diseñar zonas de cuadrícula en tiempo real.
  - Ground snapping por raycast individual por slot: los marcadores se adaptan al relieve del terreno durante la previsualización.
  - Modo `Nudge` / `Walk` intercambiable con `TAB`: en Nudge el personaje se congela y `WASD` desplaza el grid relativo a su propia rotación (0.02m normal, 0.1m con `SHIFT`); en Walk se libera el movimiento para evaluar el campo.
  - Reposicionamiento rápido del origen con `LEFT CLICK` sin perder la configuración de filas/columnas.
  - Input manual exacto con `G`: dialog `lib.inputDialog` con filas, columnas, spacing X, spacing Y y heading tecleables directamente.
  - Spacing independiente por eje: rueda del ratón = spacing X; `ALT` + rueda = spacing Y.
  - Multiplicador `SHIFT` x5 en todos los controles (flechas, espaciado y rotación).
  - Finalización con diálogo de tres campos (Zone Key, Label, Allowed Crops) y selector múltiple generado dinámicamente desde `Config.Crops`.
  - Output copiado al portapapeles con `lib.setClipboard` en formato listo para pegar en `config/zones.lua`.
  - UI con `lib.showTextUI` actualizada en tiempo real con los valores actuales.
  - `BACKSPACE`/`ESC` cancelan limpiamente en cualquier estado (`lib.hideTextUI` garantizado).

- **Slot Builder (`/farm_slots`):** Herramienta de administración para zonas punto a punto, complementaria al Zone Builder para campos irregulares que un grid no puede capturar.
  - `LEFT CLICK` coloca un slot en el suelo (ground snap + heading de cámara bakeado).
  - Preview hover verde en tiempo real; rojo si el punto está a menos de 0.5m de otro existente (protección anti-solapamiento).
  - `RIGHT CLICK` elimina el slot más cercano al cursor (dentro de 5m) con feedback de índice exacto.
  - `H` bloquea el heading actual de la cámara para los siguientes slots (útil para campos en diagonal).
  - `G` permite teclear coordenadas exactas (X, Y, Z, Heading) con el `lib.inputDialog`, pre-rellenado con la posición del jugador.
  - `C` limpia todos los slots con `lib.alertDialog` de confirmación (evita borrados accidentales).
  - `TAB` alterna Walk / Place exactamente como en el Zone Builder.
  - Visualización premium: cilindro ámbar + espiga vertical por slot, número flotante de índice (`World3dToScreen2d`), y línea naranja conectando los slots en orden de colocación.
  - Centroide calculado automáticamente para el campo `center` del output.
  - Output en formato `slots = { {x, y, z, heading}, ... }`, 100% compatible con `shared/zones.lua`.
  - Registrado en `fxmanifest.lua` tras `zone_builder.lua`.

- **`zone1` (local test):** Primera zona de slots explícitos añadida a `config/zones.lua`. 24 slots dispuestos en dos filas diagonales, restringida a `tomato`, con headings individuales por slot y centroide calculado exacto.


### Fixed

- **Corrección de incompatibilidad en `shared/time.lua`:** `os.time()` provocaba `attempt to index a nil value (global 'os')` en el cliente FiveM debido a que el runtime cliente de Lua no expone la librería `os`. Reemplazado por comprobación `type(os) == 'table'` que utiliza `GetNetworkTimeAccurate() / 1000` en cliente y `os.time()` en servidor.
- **Corrección de bind SQL en `server/modules/database/database.lua`:** `NULLIF(slot, '')` provocaba `Truncated incorrect DECIMAL value` en MySQL al intentar comparar una columna numérica (`INT`) con una cadena vacía (`''`). Se separaron las columnas nulas por tipo: strings con `NULLIF(?, '')` y `slot` con el sentinel denso `0` convertido mediante `NULLIF(?, 0)`.
- **Refresco visual inmediato tras sync (`client/modules/sync/client.lua`):** Al recibir los eventos de red `CROP_SYNC` o `CROP_REMOVE`, se invoca inmediatamente `Crops.Refresh()` para crear/destruir el prop en la misma trama, eliminando la espera de hasta 2000ms del bucle de sincronización.
- **Unificación de targets en esferas permanentes (`client/modules/zones/slots.lua`):** Elimina la pérdida del indicador azul de `ox_target` y las opciones tras plantar. Todas las interacciones de surco (`Plant seeds`, `Inspect`, `Water`, `Harvest`) conviven de forma permanente en la esfera `addSphereZone` de cada slot con filtrado por `canInteract`, eliminando raycasts fallidos sobre modelos de prop sin colisión física.
- `Growth.Evaluate` y la evaluacion pura de `Physiology` se mueven a `shared/` (`shared/growth.lua`, `shared/physiology.lua`). El cliente predice el crecimiento para renderizar, y con dos copias de la formula la divergencia seria cuestion de tiempo. Los mutadores (`Physiology.Apply`, `Physiology.Water`) siguen siendo exclusivos del servidor.
- `Validation.CropLimit` ya no recorre todo el estado: `State` mantiene un indice por propietario (`State.owners`, `State.CountByOwner`) actualizado en `Add`, `Remove`, `Update` y `LoadAll`. Era la deuda declarada al cerrar la Etapa 3.

### Added

- Resolver compartido de zonas/slots (`shared/zones.lua`), indice de ocupacion en `State`, columna `slot` + UNIQUE `(zone, slot)` en DB (con migraciones idempotentes), targets por surco vacio (`client/modules/zones/slots.lua`) y lock por slot al plantar.
- Grapeseed East: 40 slots (5x8). Grapeseed South: 24 slots (4x6), solo carrot/potato.

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
  - Bucle de gameplay completo como callbacks de `ox_lib` con respuesta uniforme `{ ok, reason, data }`: `sonar_farm:plant`, `sonar_farm:water` y `sonar_farm:harvest`.
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
  - Comandos de cliente para probar el bucle real (`/farm_plant`, `/farm_water`, `/farm_harvest`), con traduccion de codigos de rechazo en el cliente.
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
