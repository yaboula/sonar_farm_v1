# API — sonar_farm

Referencia de la superficie pública del recurso: callbacks cliente→servidor,
eventos públicos y puntos de extensión.

> Recordatorio de idioma: la documentación está en español, pero **todo el
> código, identificadores, textos de UI y logs están en inglés**.

---

## 1. Modelo de transporte

Toda acción del jugador viaja como **callback de `ox_lib`**, no como evento
`fire-and-forget`. El cliente envía intención, el servidor decide y responde.

Ventajas frente a eventos sueltos:

- El cliente sabe si la acción funcionó sin inventar timeouts.
- No hay estado a medias: o el servidor confirma, o no pasó nada.
- Un solo punto de entrada por acción, fácil de auditar.

### Forma de respuesta (uniforme)

Todos los callbacks devuelven exactamente esta estructura:

```lua
-- Éxito
{ ok = true, data = { ... } }

-- Rechazo
{ ok = false, reason = 'too_far' }
```

`reason` es siempre un **código legible por máquina** (`Sonar.Constants.REJECT`).
El servidor nunca genera texto para el jugador; el cliente traduce el código.
Esto mantiene el servidor agnóstico al idioma y evita duplicar textos.

Todos los callbacks de jugador pueden rechazar con `service_unavailable`,
`player_not_ready` o `wrong_instance` antes de evaluar la acción. Así no se
expone ni muta estado durante el arranque, sin personaje válido o fuera del
routing bucket público.

### Coordenadas: nunca las del cliente

El servidor obtiene la posición del jugador con
`GetEntityCoords(GetPlayerPed(source))`. Las coordenadas que envíe el cliente se
ignoran por completo. Sin esto, noclip y duplicación a distancia serían
triviales.

---

## 2. Callbacks

### Business Hub y Fields `0.4.0`

El shell utiliza cuatro callbacks genéricos. Todos exigen un nonce ligado a
`source`, superficie, presencia y TTL:

- `sonar_farm:hub:open`: abre Office, Warehouse o Tablet y devuelve capacidades.
- `sonar_farm:hub:load`: carga Fields, Field Detail, Land, Work, Cargo o Buyer Orders.
- `sonar_farm:hub:dispatch`: envía una intención; nunca acepta efectos agronómicos ni
  coordenadas decididas por el cliente.
- `sonar_farm:hub:close`: invalida sesión y suscripción.

Field Detail activa una sola suscripción mediante
`sonar_farm:hub:subscribeField`. Los
deltas contienen `fieldId`, `topologyRevision` y `sequence`; un salto obliga al
frontend a recargar la snapshot completa.

Intenciones autoritativas nuevas:

- `cropPlan.create|update|cancel`
- `assignment.create|accept|submit|approve|requestCorrection|cancel`
- `contract.create|accept|transition`
- `field.preparePurchase|purchase|setRoute`
- `cargo.deposit`
- `buyerOrder.transition`

El cliente envía IDs estables y datos de formulario. Membresía, propiedad,
Rows, Work, distancia, Treasury, calidad, stock y resultados se resuelven otra
vez en servidor.

### `sonar_farm:inspect`

Abre la snapshot autoritativa que alimenta el Crop Inspection Pulse Rail. El
cliente envía únicamente el identificador del cultivo; coordenadas, instancia,
distancia, existencia y reloj se resuelven en servidor.

```lua
local response = lib.callback.await('sonar_farm:inspect', false, {
    cropId = 'a3f1c9e2-...',
})
```

La respuesta de éxito incluye `serverTime` y el mismo payload mínimo de cultivo
que usa la sincronización espacial. El cliente construye localmente las series
mediante `Sonar.Inspection.Build`; no vuelve a consultar al servidor mientras la
barra permanece abierta.

**Validaciones:** runtime READY, jugador listo, routing bucket público, rate
limit, `cropId` válido, cultivo existente y distancia real del ped al cultivo.

**Rechazos posibles:** `service_unavailable`, `player_not_ready`,
`wrong_instance`, `rate_limited`, `crop_not_found`, `too_far`.

El contrato NUI v1 usa `inspection:open`, `inspection:update` e
`inspection:close`. Es informativo y no concede ninguna acción agrícola.

### `sonar_farm:plant`

Planta un cultivo en un **slot** configurado. El cliente no elige coordenadas:
envía `zone` + `slot`, y el servidor coloca el cultivo en la posición definida
en `config/zones.lua`. El plantado libre (cualquier punto dentro de un radio)
fue eliminado: producía solapamientos, campos desordenados y capacidad
impredecible.

**Petición**

```lua
local response = lib.callback.await('sonar_farm:plant', false, {
    cropType = 'carrot',
    zone = 'grapeseed_east',
    slot = 12,              -- índice 1-based del slot en esa zona
})
```

| Campo      | Tipo   | Descripción                                      |
| ---------- | ------ | ------------------------------------------------ |
| `cropType` | string | Clave en `Config.Crops`                          |
| `zone`     | string | Clave en `Config.Zones`                          |
| `slot`     | number | Índice del surco (1-based). Nunca 0: rompe SQL.  |

**Respuesta (éxito)**

```lua
{
    ok = true,
    data = {
        cropId = 'a3f1c9e2-...',
        cropType = 'carrot',
        label = 'Carrot',
        zone = 'grapeseed_east',
        slot = 12,
        growthTime = 900,
    },
}
```

**Validaciones aplicadas, en orden**

1. Token bucket (anti-flood)
2. Cooldown de la acción
3. Anti-teleport
4. El cultivo existe en `Config.Crops`
5. Lock del slot (anti-duplicación entre dos jugadores)
6. El slot existe, acepta ese cultivo y está libre
7. El jugador está a distancia real del slot
8. Límite de cultivos activos del jugador
9. Posee la semilla

La semilla **solo se consume tras pasar todas las validaciones**. Las coordenadas
del cultivo salen del slot en config, nunca del cliente.

**Rechazos posibles:** `rate_limited`, `cooldown`, `suspicious_movement`,
`unknown_crop`, `slot_not_found`, `slot_occupied`, `crop_not_allowed_here`,
`too_far`, `crop_limit_reached`, `missing_seed`, `already_in_progress`

Cuando `Config.Features.Minigames = true`, un cultivo con
`requiresMinigame = true` rechaza este callback con `minigame_required`. Debe
usar el lifecycle siguiente.

---

### Lifecycle `sonar_farm:minigame:*`

El primer contrato registrado es `tomato_initial_planting` v1. Ningún callback
acepta coordenadas del mundo ni una puntuación calculada por el navegador.

**Inicio**

```lua
local response = lib.callback.await('sonar_farm:minigame:begin', false, {
    cropType = 'tomato',
    zone = 'zone1',
    slot = 4,
})
```

El servidor valida jugador, distancia, inventario y límite; reserva el slot con
un registro `planting` y responde con `sessionId`, `cropId`, `nextStep` y límites
del contrato. Todavía no consume `tomato_seedling`.

**Checkpoint**

```lua
local response = lib.callback.await('sonar_farm:minigame:checkpoint', false, {
    sessionId = sessionId,
    contractVersion = '1.0.0',
    step = 'prepare', -- prepare | place | cover | water
    trace = {
        durationMs = 4200,
        samples = {
            { t = 0, x = 0.50, y = 0.56, down = true, pressure = 0.4 },
            -- Máximo configurado: 400 muestras normalizadas.
        },
    },
})
```

Los checkpoints deben llegar en orden. Lua comprueba versión, tamaño, duración,
frecuencia, coordenadas y tipos; después recalcula la métrica. El cuarto
checkpoint consume el trasplante una vez, cambia el registro a `planted` y
devuelve únicamente bandas cualitativas (`depth`, `alignment`, `aeration`,
`hydration`).

**Cancelar, reanudar y limpiar**

```lua
lib.callback.await('sonar_farm:minigame:cancel', false, {
    sessionId = sessionId,
    reason = 'escape',
})

lib.callback.await('sonar_farm:minigame:resume', false, {
    cropId = cropId,
})

lib.callback.await('sonar_farm:minigame:clearIncomplete', false, {
    cropId = cropId,
})
```

Cancelar conserva checkpoints validados y deja `planting_failed`. Solo el
propietario puede reanudar o limpiar. La limpieza solo acepta
`planting_failed`; no puede borrar un cultivo normal.

**Rechazos específicos:** `minigame_disabled`, `minigame_session_not_found`,
`minigame_session_expired`, `minigame_invalid_step`,
`minigame_invalid_trace`, `planting_incomplete`, `planting_not_failed`

---

### `sonar_farm:water`

Riega un cultivo. Recupera agua y cuenta como cuidado para la calidad final.

**Petición**

```lua
local response = lib.callback.await('sonar_farm:water', false, {
    cropId = 'a3f1c9e2-...',
})
```

**Respuesta (éxito)**

```lua
{
    ok = true,
    data = {
        cropId = 'a3f1c9e2-...',
        cropType = 'carrot',
        water = 100,      -- 0..100
        health = 92.5,    -- 0..100
        state = 'growing',
    },
}
```

**Permisos.** Con `Config.Farming.AllowPublicCare = true` (por defecto)
cualquiera puede regar un cultivo ajeno. Es deliberado: permite salvar la
cosecha de un vecino sin darle ningún derecho sobre el producto.

**Rechazos posibles:** `rate_limited`, `cooldown`, `suspicious_movement`,
`crop_not_found`, `too_far`, `not_owner`, `missing_tool`, `crop_dead`,
`already_watered`, `already_in_progress`

---

### Advanced Care: `fertilize`, `weed`, `treatPest`

Estos callbacks solo están activos con `Config.Features.AdvancedCare = true` y
cuando la condición está habilitada globalmente y para el cultivo. Comparten el
mismo pipeline autoritativo de distancia, permisos, rate limit, cooldown y lock
que `water`.

El cliente abre primero `sonar_farm:careOptions` con `cropId` y acción. Después
envía únicamente `cropId` e `itemId`; el servidor vuelve a resolver slot,
durabilidad, propiedad, efecto y duración proporcional.

```lua
lib.callback.await('sonar_farm:fertilize', false, { cropId = cropId, itemId = 'fertilizer_balanced' })
lib.callback.await('sonar_farm:weed', false, { cropId = cropId, itemId = 'hand_hoe_reinforced' })
lib.callback.await('sonar_farm:treatPest', false, { cropId = cropId, itemId = 'pest_spray_targeted' })
```

El item elegido debe existir en el inventario y corresponder a la acción.
Consumibles gastan una unidad; herramientas pierden durabilidad en el slot
exacto y se eliminan al romperse. Fertilizar puede superar el rango óptimo y
registra quemadura acumulada, pero rechaza el techo de saturación.

**Respuestas:** nutrientes restantes, cobertura de malas hierbas o presión de
plagas, respectivamente.

**Rechazos específicos:** `condition_disabled`, `nutrients_saturated`,
`no_weeds_detected`, `no_pest_detected`, `missing_tool`.

---

### `sonar_farm:harvest`

Cosecha un cultivo maduro y entrega el producto con metadata de calidad.

**Petición**

```lua
local response = lib.callback.await('sonar_farm:harvest', false, {
    cropId = 'a3f1c9e2-...',
})
```

**Respuesta (éxito)**

```lua
{
    ok = true,
    data = {
        cropId = 'a3f1c9e2-...',
        cropType = 'carrot',
        item = 'carrot',
        units = 4,
        quality = 86.4,        -- 0..100
        productionScore = 72,  -- solo con Advanced Care
        defect = 'pest_damage',-- solo con Advanced Care
        tier = 'fine',
        tierLabel = 'Fine',
        theft = false,
        xp = 10,               -- consumido en la Etapa 7
    },
}
```

**Garantías de integridad**

- Se comprueba `CanCarry` **antes** de crear producto.
- El cultivo se elimina **después** de entregar el producto: un inventario
  lleno nunca destruye una cosecha.
- Un lock por `cropId` impide que dos cosechas simultáneas entreguen producto
  dos veces (duplicación).
- Un cultivo muerto no da producto y se limpia para liberar la parcela.

**Rechazos posibles:** `rate_limited`, `cooldown`, `suspicious_movement`,
`crop_not_found`, `too_far`, `unknown_crop`, `crop_dead`, `crop_not_mature`,
`not_owner`, `inventory_full`, `already_in_progress`

---

### `sonar_farm:subscribe`

Suscribe al jugador a su celda espacial y las 8 adyacentes, y devuelve el snapshot
de esos cultivos. A partir de ahí el jugador recibe **solo deltas** de esas celdas.

**No acepta argumentos, y es deliberado.** El servidor deriva las celdas de la
posición real del jugador. Si el cliente pudiera nombrar sus celdas, un cliente
modificado podría suscribirse a celdas arbitrarias y volcar todos los cultivos del
mapa junto con quién es dueño de cada uno.

**Petición**

```lua
local response = lib.callback.await('sonar_farm:subscribe', false)
```

**Respuesta**

```lua
{
    ok = true,
    cells = { '22:50', '22:51', ... },   -- celdas suscritas
    serverTime = 1786000000,             -- para alinear el reloj del cliente
    crops = {
        {
            id = 'a3f1c9e2-...',
            cropType = 'carrot',
            cell = '22:50',
            x = 2236.8, y = 5031.6, z = 44.2,
            heading = 180.0,
            plantedAt = 1785999400,
            growthTime = 900,
            water = 82.5,
            health = 100,
            lastCare = 1785999400,
            isMine = true,
        },
    },
}
```

Con `ok = false` el servicio aún no está listo, el personaje no está disponible,
el jugador no está en el routing bucket público o se ha superado el límite
específico de suscripciones. El cliente limpia su caché cuando corresponde y
reintenta sin exponer estado anterior.

**Dos detalles del payload que importan**

- **Lleva timestamps, no estado calculado.** El cliente deriva el crecimiento y la
  condición localmente con las fórmulas compartidas (`shared/growth.lua`,
  `shared/physiology.lua`). Un campo lleno de cultivos creciendo **no genera ni un
  byte** de red mientras crece. El cliente solo puede equivocarse en lo que
  *dibuja*; toda acción la sigue decidiendo el servidor.
- **`isMine` en lugar del identificador.** El `citizenid` de otro jugador nunca
  llega a un cliente, así que nadie puede volcar quién es dueño de qué campo. Se
  calcula por destinatario.

`serverTime` permite al cliente corregir su reloj: sin eso, un jugador con la hora
del sistema mal vería las plantas en la fase equivocada.

---

## 3. Códigos de rechazo

Definidos en `Sonar.Constants.REJECT`. El cliente los traduce a texto.

| Código                  | Significado                                  |
| ----------------------- | -------------------------------------------- |
| `service_unavailable`   | Runtime aún no está en estado `READY`        |
| `player_not_ready`      | Framework/personaje/identifier no disponible |
| `wrong_instance`        | Routing bucket no permitido                  |
| `rate_limited`          | El jugador está saturando eventos            |
| `cooldown`              | Acción repetida demasiado rápido             |
| `too_far`               | Fuera del rango de interacción               |
| `suspicious_movement`   | Velocidad implícita imposible                |
| `not_in_zone`           | Fuera de toda zona de cultivo                |
| `crop_not_allowed_here` | La zona no admite ese cultivo                |
| `slot_not_found`        | El surco no existe en config                 |
| `slot_occupied`         | Ya hay un cultivo en ese surco               |
| `unknown_crop`          | `cropType` inexistente                       |
| `missing_seed`          | Sin semillas                                 |
| `missing_tool`          | Sin herramienta (regadera)                   |
| `crop_not_found`        | `cropId` inexistente en estado               |
| `crop_not_mature`       | Aún no está listo                            |
| `crop_dead`             | Cultivo muerto                               |
| `not_owner`             | Pertenece a otro jugador                     |
| `crop_limit_reached`    | Alcanzado `MaxCropsPerPlayer`                |
| `inventory_full`        | Sin espacio                                  |
| `already_in_progress`   | Otro jugador está actuando sobre ese cultivo |
| `already_watered`       | Todavía no necesita agua                     |
| `nutrients_saturated`   | El cultivo alcanzó su techo de nutrientes    |
| `no_weeds_detected`     | Cobertura insuficiente para desherbar        |
| `no_pest_detected`      | Presión insuficiente para tratar             |
| `condition_disabled`    | Condición desactivada por feature/cultivo    |
| `internal_error`        | Fallo inesperado                             |

---

## 4. Eventos públicos (servidor)

Otros recursos pueden escucharlos con `AddEventHandler`. Son informativos: no
esperan respuesta y no alteran el resultado de la acción.

```lua
AddEventHandler('sonar_farm:cropHarvested', function(payload)
    -- payload.source, payload.cropId, payload.cropType, payload.owner,
    -- payload.quality, payload.units, payload.theft, payload.xp
end)
```

| Evento                      | Cuándo             | Payload principal                                |
| --------------------------- | ------------------ | ------------------------------------------------ |
| `sonar_farm:cropPlanted`    | Cultivo plantado   | `cropId`, `cropType`, `zone`, `slot`, `owner`, `source` |
| `sonar_farm:cropWatered`    | Cultivo regado     | `cropId`, `cropType`, `owner`, `source`          |
| `sonar_farm:cropHarvested`  | Cultivo cosechado  | `+ quality`, `units`, `theft`, `xp`              |
| `sonar_farm:cropFertilized` | Cultivo fertilizado | `item`, `nutrients`, `overfertilizeExcess`     |
| `sonar_farm:cropWeeded`     | Malas hierbas retiradas | `weedCover`                                  |
| `sonar_farm:cropTreated`    | Plaga tratada      | `item`, `pestPressure`                           |

Los deltas de render (`sonar_farm:cropSync`, `sonar_farm:cropRemove`) **no** son API
pública: son el transporte interno del motor visual y pueden cambiar. Los eventos de
arriba son el contrato estable para terceros.

Por eso el motor de sincronización se dispara con llamadas explícitas
(`Sync.OnCropChanged`, `Sync.OnCropRemoved`) desde los handlers, en lugar de
escuchar los eventos públicos: hacer que el funcionamiento interno dependa de una
superficie que otros pueden modificar sería frágil.

---

## 5. Punto de extensión: proveedores de calidad

Es el contrato que permite que la Etapa 5 (minijuegos) entre **sin refactorizar
ni una línea** de `plant.lua`, `care.lua` o `harvest.lua`.

Un proveedor recibe el contexto de la acción y devuelve una puntuación `0..100`:

```lua
Quality.RegisterProvider('minigame', function(source, action, record)
    -- Se ejecuta en el servidor. Si la puntuación viene de un minijuego en el
    -- cliente, DEBE validarse aquí antes de devolverla.
    return score
end)

Quality.SetProvider('minigame')
```

Por defecto está activo el proveedor `default`, que devuelve
`Config.Quality.DefaultScore`. Si un proveedor lanza un error o no devuelve un
número, el sistema registra el fallo y cae al valor por defecto: un minijuego
roto nunca bloquea la cosecha.

### Cómo se calcula la calidad final

```
base     = score * ScoreWeight + health * CareWeight
calidad  = base * (1 - spoilage/100)
calidad  = calidad * (1 - defectoHistorico * DefectWeight) -- Advanced Care
calidad  = min(calidad, MechanizedCap)              -- solo trabajo mecanizado
calidad  = calidad * (1 - TheftQualityPenalty)      -- solo si es robo
```

Con Advanced Care, el rendimiento interpola desde un `productionScore`
independiente gobernado por déficit nutritivo y daño de plagas. Sin el feature,
sigue interpolando desde calidad exactamente como antes.

---

## 6. Configuración relevante

| Clave                                | Defecto | Efecto                                          |
| ------------------------------------ | ------- | ----------------------------------------------- |
| `Config.Farming.OwnerOnlyHarvest`    | `true`  | Solo el propietario cosecha                     |
| `Config.Farming.AllowPublicCare`     | `true`  | Cualquiera puede regar cultivos ajenos          |
| `Config.Farming.TheftQualityPenalty` | `0.3`   | Calidad perdida al cosechar ajeno               |
| `Config.Farming.MaxCropsPerPlayer`   | `25`    | Cultivos activos simultáneos por jugador        |
| `Config.Farming.NewCropSimulationVersion` | `2` | Modelo asignado solo a nuevas plantaciones    |
| `Config.Farming.WaterRefillThreshold`| `95`    | Agua por encima de la cual no se puede regar    |
| `Config.Features.AdvancedCare`       | `false` | Activa el modelo causal completo                 |
| `Config.Farming.ConditionEffects`    | `true`  | Techo global por nutrientes/malas hierbas/plagas|
| `Config.Security.MaxInteractDistance`| `3.0`   | Distancia máxima de interacción (m)             |
| `Config.Security.MaxSpeedMps`        | `60.0`  | Velocidad implícita que se considera sospechosa |
| `Config.Security.AllowedRoutingBuckets` | `{ 0 }` | Instancias donde se permite farming público  |
| `Config.Security.SubscriptionBucket` | `3 / 1s` | Presupuesto separado para snapshots           |
| `Config.Admin.Ace`                    | `sonar_farm.admin` | ACE de herramientas administrativas |
| `Config.Quality.DefaultScore`        | `75`    | Puntuación del proveedor stub                   |
| `Config.Quality.MechanizedCap`       | `80`    | Techo de calidad del trabajo automatizado       |
| `Config.Sync.CellRadius`             | `1`     | Celdas alrededor del jugador (1 = bloque 3x3)   |
| `Config.Sync.TickNear`               | `500`   | Intervalo (ms) con cultivos cerca               |
| `Config.Sync.TickFar`                | `2000`  | Intervalo (ms) sin cultivos cerca               |
| `Config.Render.Radius`               | `30.0`  | Distancia (m) a la que se crean props           |
| `Config.Render.MaxProps`             | `50`    | Tope duro de props simultáneos                  |
| `Config.Render.TargetDistance`       | `2.2`   | Distancia de ox_target (bajo el límite servidor)|
| `Config.Render.GroundSnap`           | `true`  | Asentar props con raycast al suelo              |
| `Config.Render.FallbackModel`        | —       | Modelo usado si el prop configurado no existe   |
| `Config.Render.InteractionCacheMs`   | `750`   | TTL local de la snapshot usada por ox_target    |
| `Config.Render.VisualStageCacheMs`   | `5000`  | TTL local de la etapa visual del cultivo        |
| `Config.Render.VisualStageJitterMs`  | `1500`  | Dispersión determinista de recálculos visuales  |

---

### Supplies Runtime V2

`Config.Features.Supplies = false` mantiene aislado este vertical. Cuando se
activa, el cliente abre una sesión con nonce ligado a `source`, superficie,
presencia y TTL. La NUI utiliza únicamente estos callbacks genéricos:

- `hub:bootstrap`: crea la sesión y devuelve capacidades reales.
- `hub:load`: carga Supplies o el slice disponible de Company.
- `hub:dispatch`: envía una intención; nunca precios, efectos ni permisos.
- `hub:close`: invalida el nonce y libera el foco.

Las superficies son `tablet` y `office`; la presencia independiente puede ser
`remote`, `office` o `warehouse`. Confirmar exige Office físico y retirar o
devolver exige Warehouse físico, ambos revalidados con coordenadas del ped en el
servidor. Las áreas sin backend responden `unavailable`.

Permisos persistidos: `supplies.view`, `supplies.request`, `supplies.order`,
`supplies.approve`, `supplies.view_ledger`, `warehouse.view`,
`warehouse.withdraw` y `warehouse.return`. Company Treasury es el único pagador.
El catálogo canónico vive en `shared/item_catalog.lua`; genera conjuntamente
`data/ox_inventory_items.lua` y `web/src/data/itemCatalog.generated.ts`. Ejecuta
`lua scripts/generate_items.lua --check` para rechazar divergencias.

---

## 7. Motor visual (cliente)

El cliente es "tonto" en decisiones y "listo" en dibujo: no calcula rendimientos ni
permisos, pero sí predice qué modelo toca mostrar.

| Módulo                                | Responsabilidad                                          |
| ------------------------------------- | -------------------------------------------------------- |
| `client/modules/render/pool.lua`      | Pool genérico de entidades no networkeadas por clave      |
| `client/modules/render/crops.lua`     | Caché local, predicción, fases, culling y tope de props   |
| `client/modules/zones/slots.lua`      | Esferas permanentes: plantar vacío; operar ocupado        |
| `client/modules/sync/client.lua`      | Hilo único adaptativo, suscripción y deltas               |
| `client/modules/interaction/actions.lua` | Punto único de acción, traducción de rechazos, resync  |

El pool es **agnóstico al contenido** y separa entidades por tag. Los props de
cultivos y los props opcionales de slots se refrescan y destruyen de forma
independiente.

### Autocorrección

Un rechazo del servidor cuyo motivo implique caché obsoleta (`crop_not_found`,
`crop_not_mature`, `crop_dead`, `already_watered`) fuerza una resuscripción. Cada
desacuerdo con el servidor se convierte en una corrección, que es precisamente lo
que hace segura la predicción del cliente.
