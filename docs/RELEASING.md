# Proceso de releases

El recurso FiveM y el contrato frontend tienen versiones independientes:

- `VERSION` y `fxmanifest.lua` definen la versión SemVer del recurso completo.
- `web/src/frontendV1Contract.ts` define la versión del contrato de interfaz;
  no tiene que coincidir con la versión del recurso.

## Preparar una versión

1. Trabajar en una rama y mantener `main` como rama integrable.
2. Actualizar `VERSION` y `fxmanifest.lua` con la misma versión SemVer.
3. Mover los cambios relevantes desde `[Unreleased]` a una sección
   `## [x.y.z] - AAAA-MM-DD` en `CHANGELOG.md`.
4. Ejecutar `lua scripts/check_version.lua` y todos los gates del repositorio.
5. Integrar el commit de release en `main`.
6. Crear y publicar un tag anotado `vx.y.z` sobre ese commit.

El workflow `release.yml` rechaza tags que no coincidan exactamente con
`VERSION`, recompila la NUI, repite las regresiones y publica un ZIP limpio del
recurso. Nunca debe crearse un tag sobre cambios sin commit o desde una rama con
un gate fallido.
