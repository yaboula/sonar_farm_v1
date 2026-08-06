# sonar_farm

Script de farming escalable para **FiveM**, disenado como **plataforma** (no como un script simple). Arranca con verduras (MVP) sobre **QB-Core + ox_lib + ox_inventory + ox_target**, con arquitectura preparada para escalar en frameworks, cultivos, progresion, economia y sistemas jugables.

> Regla de idioma: la documentacion (`docs/`) esta en **espanol**. El **codigo, UI, variables, comentarios, logs y configuracion estan 100% en ingles**.

## Filosofia

- **Server-authoritative (Zero-Trust):** el servidor es la unica fuente de verdad; el cliente solo envia intencion.
- **Data-driven:** el contenido (cultivos, zonas, minijuegos) vive en config, no en el codigo.
- **Escalabilidad por diseno:** Bridge Layer multi-framework, plugin system (`RegisterCrop`), minijuegos registrables.
- **Rendimiento primero:** 0.00 ms en reposo, crecimiento sin ticks (timestamp), culling agresivo, props client-side.

## Stack y dependencias

| Dependencia   | Uso                                              | Obligatoria |
| ------------- | ------------------------------------------------ | ----------- |
| QB-Core       | Framework base (MVP)                             | Si          |
| ox_lib        | Notify, context menu, input, progressbar         | Si          |
| ox_inventory  | Inventario + metadata (quality, freshness)       | Si          |
| ox_target     | Interaccion por objetivo                         | Si          |
| oxmysql       | Persistencia (a partir de Etapa 2)               | Si          |

## Estructura del proyecto

```
sonar_farm/
  fxmanifest.lua
  config/        Configuracion data-driven (config, crops, zones, minigames)
  shared/        Constantes y utilidades puras (cliente + servidor)
  bridge/        Capa de abstraccion (frameworks, inventory, target)
  server/        Logica autoritativa de servidor + modulos
  client/        Motor visual, interaccion y minijuegos
  web/           SPA de NUI (React + Vite + Tailwind) — a partir de Etapa 9
  docs/          Documentacion tecnica (espanol)
```

## Instalacion (desarrollo)

1. Clonar dentro de `resources/[local]/` de tu servidor FiveM.
2. Asegurar que `qb-core`, `ox_lib`, `ox_inventory` y `ox_target` estan iniciados antes.
3. Anadir `ensure sonar_farm` a tu `server.cfg`.

## Estado del proyecto

En construccion por etapas. Ver [docs/DECISIONES.md](docs/DECISIONES.md) para la vision completa y [CHANGELOG.md](CHANGELOG.md) para el historial.

- [x] Etapa 1 — Bootstrap del recurso + Bridge Layer
- [ ] Etapa 2 — Motor de estado + persistencia
- [ ] Etapa 3 — Logica de servidor autoritativa
- [ ] Etapa 4 — Motor visual (streaming/culling)
- [ ] Etapa 5 — Motor de minijuegos
- [ ] ... (ver docs/DECISIONES.md)
