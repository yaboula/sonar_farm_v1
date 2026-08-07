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

### Coordenadas: nunca las del cliente

El servidor obtiene la posición del jugador con
`GetEntityCoords(GetPlayerPed(source))`. Las coordenadas que envíe el cliente se
ignoran por completo. Sin esto, noclip y duplicación a distancia serían
triviales.

---

## 2. Callbacks

### `sonar_farm:plant`

Planta un cultivo en la posición actual del jugador.

**Petición**

```lua
local response = lib.callback.await('sonar_farm:plant', false, {
    cropType = 'carrot',
})
```

| Campo      | Tipo   | Descripción                       |
| ---------- | ------ | --------------------------------- |
| `cropType` | string | Clave en `Config.Crops`           |

**Respuesta (éxito)**

```lua
{
    ok = true,
    data = {
        cropId = 'a3f1c9e2-...',
        cropType = 'carrot',
        label = 'Carrot',
        zone = 'grapeseed_east',
        growthTime = 900,
    },
}
```

**Validaciones aplicadas, en orden**

1. Token bucket (anti-flood)
2. Cooldown de la acción
3. Anti-teleport
4. El cultivo existe en `Config.Crops`
5. Posición del servidor disponible
6. Dentro de una zona y el cultivo permitido en ella
7. Límite de cultivos activos del jugador
8. Posee la semilla

La semilla **solo se consume tras pasar todas las validaciones**.

**Rechazos posibles:** `rate_limited`, `cooldown`, `suspicious_movement`,
`unknown_crop`, `too_far`, `not_in_zone`, `crop_not_allowed_here`,
`crop_limit_reached`, `missing_seed`

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

Con `ok = false` el ped todavía no ha hecho streaming y el cliente reintenta en su
siguiente pasada.

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

### `sonar_farm:nearby`

Consulta de solo lectura. No muta estado ni toca inventario.

**Petición**

```lua
local crops = lib.callback.await('sonar_farm:nearby', false, 20.0) -- radio, máx 50
```

**Respuesta**

```lua
{
    {
        cropId = 'a3f1c9e2-...',
        cropType = 'carrot',
        owner = 'BIV71460',
        distance = 3.4,
        state = 'mature',
        progress = 100,   -- porcentaje
        water = 42.5,
        health = 88.0,
    },
}
```

La Etapa 4 sustituye este escaneo por radio por suscripciones a celdas
espaciales.

---

## 3. Códigos de rechazo

Definidos en `Sonar.Constants.REJECT`. El cliente los traduce a texto.

| Código                  | Significado                                  |
| ----------------------- | -------------------------------------------- |
| `rate_limited`          | El jugador está saturando eventos            |
| `cooldown`              | Acción repetida demasiado rápido             |
| `too_far`               | Fuera del rango de interacción               |
| `suspicious_movement`   | Velocidad implícita imposible                |
| `not_in_zone`           | Fuera de toda zona de cultivo                |
| `crop_not_allowed_here` | La zona no admite ese cultivo                |
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
| `sonar_farm:cropPlanted`    | Cultivo plantado   | `cropId`, `cropType`, `zone`, `owner`, `source`  |
| `sonar_farm:cropWatered`    | Cultivo regado     | `cropId`, `cropType`, `owner`, `source`          |
| `sonar_farm:cropHarvested`  | Cultivo cosechado  | `+ quality`, `units`, `theft`, `xp`              |

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
calidad  = min(calidad, MechanizedCap)              -- solo trabajo mecanizado
calidad  = calidad * (1 - TheftQualityPenalty)      -- solo si es robo
```

El rendimiento interpola entre `yield.min` y `yield.max` según la calidad, con
un mínimo de 1 unidad.

---

## 6. Configuración relevante

| Clave                                | Defecto | Efecto                                          |
| ------------------------------------ | ------- | ----------------------------------------------- |
| `Config.Farming.OwnerOnlyHarvest`    | `true`  | Solo el propietario cosecha                     |
| `Config.Farming.AllowPublicCare`     | `true`  | Cualquiera puede regar cultivos ajenos          |
| `Config.Farming.TheftQualityPenalty` | `0.3`   | Calidad perdida al cosechar ajeno               |
| `Config.Farming.MaxCropsPerPlayer`   | `25`    | Cultivos activos simultáneos por jugador        |
| `Config.Farming.WaterRefillThreshold`| `95`    | Agua por encima de la cual no se puede regar    |
| `Config.Security.MaxInteractDistance`| `3.0`   | Distancia máxima de interacción (m)             |
| `Config.Security.MaxSpeedMps`        | `60.0`  | Velocidad implícita que se considera sospechosa |
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

---

## 7. Motor visual (cliente)

El cliente es "tonto" en decisiones y "listo" en dibujo: no calcula rendimientos ni
permisos, pero sí predice qué modelo toca mostrar.

| Módulo                                | Responsabilidad                                          |
| ------------------------------------- | -------------------------------------------------------- |
| `client/modules/render/pool.lua`      | Pool genérico de entidades no networkeadas por clave      |
| `client/modules/render/crops.lua`     | Caché local, predicción, fases, culling y tope de props   |
| `client/modules/render/target.lua`    | Opciones de ox_target ancladas al prop                    |
| `client/modules/sync/client.lua`      | Hilo único adaptativo, suscripción y deltas               |
| `client/modules/interaction/actions.lua` | Punto único de acción, traducción de rechazos, resync  |

El pool es **agnóstico al contenido**: gestiona entidades por clave y no sabe qué es
un cultivo, así que la maquinaria de la Etapa 9 lo reutiliza sin cambios.

### Autocorrección

Un rechazo del servidor cuyo motivo implique caché obsoleta (`crop_not_found`,
`crop_not_mature`, `crop_dead`, `already_watered`) fuerza una resuscripción. Cada
desacuerdo con el servidor se convierte en una corrección, que es precisamente lo
que hace segura la predicción del cliente.
