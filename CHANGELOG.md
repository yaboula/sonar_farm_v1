# Changelog

Todos los cambios relevantes de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y el proyecto se adhiere a [Versionado Semantico](https://semver.org/lang/es/).

## [Unreleased]

### Added

- **Etapa 1 — Bootstrap y Bridge Layer:**
  - Estructura de carpetas de nivel empresarial (`config/`, `shared/`, `bridge/`, `server/`, `client/`, `web/`).
  - `fxmanifest.lua` con dependencias ox, `lua54` y orden de carga controlado.
  - Configuracion base (`config/config.lua`) con override de framework, debug, intervalo de guardado y feature flags. Placeholders data-driven para `crops`, `zones` y `minigames`.
  - Constantes y utilidades compartidas (`shared/constants.lua`, `shared/utils.lua`).
  - Capa de abstraccion (Bridge Layer): deteccion automatica de framework via `GetResourceState`, interfaz publica y adaptador completo de QB-Core con stubs desacoplados para ESX y Qbox.
  - Wrappers de inventario (ox_inventory) y target (ox_target).
  - Logger de servidor con niveles `INFO`/`WARN`/`EXPLOIT` y conectores desacoplados (consola; Discord/DB como stubs).
  - Smoke test de arranque ("Bridge ready") en servidor y cliente.
