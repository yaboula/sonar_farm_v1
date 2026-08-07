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
