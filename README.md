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
                  + cultivation opcional (fertilize, weed, treat pests)
      minigames/ Sesiones, checkpoints y scoring autoritativo
      logger/    Logging por niveles con conectores
  client/        Motor visual, interaccion y herramientas de administracion
  inspection-ui/ HUD agronomico React/Vite, transparente y sin foco
  minigames-ui/  NUI React/Canvas 2D aislada del Business Hub
  nui-shell/     Punto de entrada NUI unico y control de foco entre superficies
  web/           Business Hub React (runtime FiveM + fixtures de navegador)
  docs/          Documentacion tecnica (espanol)
```

## Instalacion (desarrollo)

1. Clonar dentro de `resources/[local]/` de tu servidor FiveM.
2. Asegurar que `oxmysql`, `qb-core`, `ox_lib`, `ox_inventory` y `ox_target` estan iniciados antes.
3. Copiar los items de [`data/ox_inventory_items.lua`](data/ox_inventory_items.lua) a `ox_inventory/data/items.lua` y reiniciar `ox_inventory`.
4. Construir `inspection-ui/`, `minigames-ui/` y `web/` con `npm ci` y
   `npm run build` en cada directorio. El shell carga los tres artefactos; el
   HUD de inspeccion nunca toma foco y las otras dos superficies lo comparten
   de forma excluyente.
5. Conceder `sonar_farm.admin` y `sonar_farm.company_admin` solo a los
   administradores correspondientes.
   herramientas de desarrollo.
6. Anadir `ensure sonar_farm` a tu `server.cfg`.

```cfg
add_ace group.admin sonar_farm.admin allow
add_ace group.admin sonar_farm.company_admin allow
```

El esquema de base de datos se crea solo al arrancar (`Config.Database.AutoCreateSchema`). Detalles y alternativa manual en [docs/RUNBOOK.md](docs/RUNBOOK.md).

## Estado del proyecto

Etapas 1–4 estabilizadas, primer corte vertical de la Etapa 5 implementado y
Advanced Crop Care disponible como rollout opt-in.
Ver [docs/DECISIONES.md](docs/DECISIONES.md) para la vision completa,
[docs/API.md](docs/API.md) para el contrato actual y [CHANGELOG.md](CHANGELOG.md)
para el historial.

- [x] Etapa 1 — Bootstrap del recurso + Bridge Layer
- [x] Etapa 2 — Motor de estado + persistencia
- [x] Etapa 3 — Logica de servidor autoritativa (plantar / cuidar / cosechar)
- [x] Etapa 4 — Motor visual (streaming/culling + ox_target)
- [~] Etapa 5 — Motor de minijuegos (Tomato Initial Planting)
- [x] Advanced Crop Care — modelo causal opcional (`AdvancedCare = false`)
- [x] Supplies Runtime V2 - Treasury, pedidos y Warehouse (`Supplies = false`)
- [x] Crop Inspection Pulse Rail - diagnostico temporal sin foco (`InspectionHud = true`)
- [ ] ... (ver docs/DECISIONES.md)

Tomato se planta como trasplante mediante el minijuego de cuatro pasos
Prepare → Place → Cover → Water. La NUI solo captura interaccion; el servidor
reserva el slot, valida checkpoints, recalcula calidad y consume
`tomato_seedling` al confirmar. Water/Harvest conservan barras placeholder hasta
sus respectivos cortes de Etapa 5.

Advanced Crop Care añade nutrientes, malas hierbas y plagas con crecimiento,
producción, calidad y defectos causalmente separados. Se entrega desactivado por
defecto para preservar exactamente el farming estabilizado; activación y objetos
necesarios se documentan en [docs/RUNBOOK.md](docs/RUNBOOK.md).

Supplies Runtime convierte el Business Hub en una superficie autoritativa:
Tablet prepara, Office confirma contra Company Treasury y Warehouse entrega tras
el plazo configurado. Los objetos empresariales conservan custodia y durabilidad.
La validacion dentro de un servidor real se ejecuta con
[`docs/TEST_SUPPLIES_RUNTIME_V2.md`](docs/TEST_SUPPLIES_RUNTIME_V2.md).

Inspect abre una barra agronomica autoritativa junto al minimapa. Muestra diez
minutos de historial, diez minutos de prevision sin cuidado, ETA, protecciones y
una recomendacion causal. Se cierra sin bloquear movimiento, camara ni combate.
La aceptación dentro del servidor está detallada en
[`docs/TEST_CROP_INSPECTION_PULSE_RAIL.md`](docs/TEST_CROP_INSPECTION_PULSE_RAIL.md).

La versión actual del recurso se encuentra en `VERSION`. El contrato frontend
mantiene versionado independiente; el proceso de tags y paquetes está en
[docs/RELEASING.md](docs/RELEASING.md).

**Requisito de la Etapa 4:** los props de plantas (`bzzz_plants_*`) viven en su propio recurso de streaming, que debe estar iniciado. Si falta, el cliente avisa por consola con el nombre exacto del modelo y usa un respaldo. Ver [docs/RUNBOOK.md](docs/RUNBOOK.md).

La version actual soporta **QB-Core**. Los adaptadores ESX y Qbox son stubs
deliberados: si se seleccionan o detectan, el arranque falla de forma explicita
en lugar de aceptar jugadores con un Bridge incompleto. `Config.Debug` viene
desactivado; activarlo no concede permisos sin el ACE configurado.
