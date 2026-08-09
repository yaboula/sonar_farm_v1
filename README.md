# sonar_farm

Script de farming escalable para **FiveM**, disenado como **plataforma** (no como un script simple). Arranca con verduras (MVP) sobre **QB-Core + ox_lib + ox_inventory + ox_target**, con arquitectura preparada para escalar en frameworks, cultivos, progresion, economia y sistemas jugables.

> Regla de idioma: la documentacion (`docs/`) esta en **espanol**. El **codigo, UI, variables, comentarios, logs y configuracion estan 100% en ingles**.

## Filosofia

- **Server-authoritative (Zero-Trust):** el servidor es la unica fuente de verdad; el cliente solo envia intencion.
- **Data-driven:** los cultivos y las zonas actuales viven en config, no en el codigo.
- **Escalabilidad por diseno:** Bridge desacoplado y contratos internos preparados para ampliar el producto por etapas.
- **Rendimiento primero:** 0.00 ms en reposo, crecimiento sin ticks (timestamp), culling agresivo, props client-side.

## Stack y dependencias

| Dependencia   | Uso                                              | Obligatoria |
| ------------- | ------------------------------------------------ | ----------- |
| QB-Core       | Framework base (MVP)                             | Si          |
| ox_lib        | Notify, context menu, input, progressbar         | Si          |
| ox_inventory  | Inventario + metadata de calidad                 | Si          |
| ox_target     | Interaccion por objetivo                         | Si          |
| oxmysql       | Persistencia (a partir de Etapa 2)               | Si          |

## Estructura del proyecto

```
sonar_farm/
  fxmanifest.lua
  config/        Configuracion data-driven (config, crops, zones, minigames)
  shared/        Constantes y utilidades puras (cliente + servidor)
  bridge/        Capa de abstraccion (frameworks, inventory, target)
  data/          Definiciones para copiar a otros recursos (items de ox_inventory)
  database/      Esquema SQL
  server/        Logica autoritativa de servidor + modulos
    modules/
      database/  Acceso a datos (oxmysql)
      state/     Hot-state en RAM + crecimiento por timestamp
      security/  Rate limiting y validacion anti-exploit
      farming/   Acciones autoritativas: plant, care, harvest
      minigames/ Sesiones, checkpoints y scoring autoritativo
      logger/    Logging por niveles con conectores
  client/        Motor visual, interaccion y herramientas de administracion
  minigames-ui/  NUI React/Canvas 2D aislada del Business Hub
  docs/          Documentacion tecnica (espanol)
```

## Instalacion (desarrollo)

1. Clonar dentro de `resources/[local]/` de tu servidor FiveM.
2. Asegurar que `oxmysql`, `qb-core`, `ox_lib`, `ox_inventory` y `ox_target` estan iniciados antes.
3. Copiar los items de [`data/ox_inventory_items.lua`](data/ox_inventory_items.lua) a `ox_inventory/data/items.lua` y reiniciar `ox_inventory`.
4. Construir la NUI de minijuegos con `npm ci` y `npm run build` dentro de
   `minigames-ui/`.
5. Conceder `sonar_farm.admin` solo a administradores que deban usar las
   herramientas de desarrollo.
6. Anadir `ensure sonar_farm` a tu `server.cfg`.

```cfg
add_ace group.admin sonar_farm.admin allow
```

El esquema de base de datos se crea solo al arrancar (`Config.Database.AutoCreateSchema`). Detalles y alternativa manual en [docs/RUNBOOK.md](docs/RUNBOOK.md).

## Estado del proyecto

Etapas 1–4 estabilizadas y primer corte vertical de la Etapa 5 implementado.
Ver [docs/DECISIONES.md](docs/DECISIONES.md) para la vision completa,
[docs/API.md](docs/API.md) para el contrato actual y [CHANGELOG.md](CHANGELOG.md)
para el historial.

- [x] Etapa 1 — Bootstrap del recurso + Bridge Layer
- [x] Etapa 2 — Motor de estado + persistencia
- [x] Etapa 3 — Logica de servidor autoritativa (plantar / cuidar / cosechar)
- [x] Etapa 4 — Motor visual (streaming/culling + ox_target)
- [~] Etapa 5 — Motor de minijuegos (Tomato Initial Planting)
- [ ] ... (ver docs/DECISIONES.md)

Tomato se planta como trasplante mediante el minijuego de cuatro pasos
Prepare → Place → Cover → Water. La NUI solo captura interaccion; el servidor
reserva el slot, valida checkpoints, recalcula calidad y consume
`tomato_seedling` al confirmar. Water/Harvest conservan barras placeholder hasta
sus respectivos cortes de Etapa 5.

**Requisito de la Etapa 4:** los props de plantas (`bzzz_plants_*`) viven en su propio recurso de streaming, que debe estar iniciado. Si falta, el cliente avisa por consola con el nombre exacto del modelo y usa un respaldo. Ver [docs/RUNBOOK.md](docs/RUNBOOK.md).

La version actual soporta **QB-Core**. Los adaptadores ESX y Qbox son stubs
deliberados: si se seleccionan o detectan, el arranque falla de forma explicita
en lugar de aceptar jugadores con un Bridge incompleto. `Config.Debug` viene
desactivado; activarlo no concede permisos sin el ACE configurado.
