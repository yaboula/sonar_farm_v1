# Decisiones de Arquitectura y Visión — sonar_farm

> Documento vivo de decisiones aprobadas. Fuente de verdad del diseño.
> Fecha de congelado inicial: 2026-08-07
> Repositorio: https://github.com/yaboula/sonar_farm_v1.git (branch: `main`)
>
> **Regla de idioma global:** la documentación (`docs/`) y la discusión se mantienen en **español**.
> El **código, script, UI, variables, comentarios, logs y configuración van 100% en inglés**, sin ninguna palabra en español.

---

## Resumen ejecutivo

`sonar_farm` es un script de farming para FiveM diseñado como **plataforma escalable de nivel empresarial**, no como un script simple. Arranca con **verduras** (MVP) sobre **QB-Core + ox_lib + ox_inventory + ox_target**, con arquitectura preparada para escalar en frameworks, cultivos, progresión, economía y sistemas jugables. El diferenciador central es un **gameplay activo basado en minijuegos profesionales** que reemplaza el clásico "mantener E y esperar".

---

## Módulo 1 — Capa de Abstracción (Bridge Layer)

- **Framework target:** soporte nativo **QB-Core** en el MVP. Interfaz abstracta (Bridge) preparada con **adaptadores desacoplados** para **ESX** y **Qbox** a futuro.
- **Detección de entorno:** verificación automática vía `GetResourceState()`, con advertencias claras por consola y **override manual** del framework en `config.lua`.
- **Inventario:** dependencia directa con **ox_inventory** para metadatos nativos (`quality`, `freshness`, `moisture`). Wrapper abstracto básico en el Bridge: `AddItem`, `RemoveItem`, `HasItem`.
- **Target y utilidades:** dependencia obligatoria de **ox_lib** y **ox_target** (objetivo **0.00 ms en reposo**), estandarizando notificaciones, menús contextuales e inputs.

## Módulo 2 — Lógica de Negocio Autoritativa en Servidor

- **Modelo Zero-Trust:** el servidor es la única entidad autorizada para modificar estado o entregar ítems. El cliente solo envía **intención** (IDs + coordenadas).
- **Validación anti-exploit multinivel** por acción: distancia real jugador↔cultivo, validación de estado en memoria, posesión de herramientas en inventario y **detección de saltos de distancia anómalos** (teleport).
- **Control de red:** **Token Bucket global por jugador** contra event flooding + cooldowns específicos por acción.
- **Auditoría:** sistema de logging desacoplado por niveles (`INFO`, `WARN`, `EXPLOIT`) con conectores para **Consola, Discord Webhooks y Base de Datos**.

## Módulo 3 — Motor de Estado y Persistencia Asíncrona

- **Hot State en RAM:** tabla de memoria Lua del servidor como fuente de verdad en tiempo real (cero latencia I/O en jugabilidad).
- **Esquema relacional (oxmysql):** estructura normalizada — `farming_crops`, `farming_zones`, `farming_players` — con **columnas JSON** para atributos dinámicos.
- **Estrategia de guardado:** **Dirty Flags** + guardado asíncrono por lotes (**batch writing cada 60s**) + guardado de emergencia en `onResourceStop` y apagado del servidor.
- **Crecimiento sin ticks:** cálculo por diferencial de tiempo (`Elapsed = t_now - t_planted`). Sin bucles constantes; **lazy evaluation** al acercarse o interactuar.

## Módulo 4 — Motor Visual y Optimización de Clientes

- **Streaming por proximidad:** los cultivos no son entidades físicas fijas; marcadores lógicos en memoria y el cliente crea/destruye props solo en radio cercano (**<30m**).
- **Grilla espacial (Spatial Hashing):** celdas de **100x100m**; el servidor solo transmite a la celda del jugador y sus **8 adyacentes**.
- **Props locales (client-side only):** objetos no networkeados (`isNetwork = false`) con `CreateObjectNoOffset`. Cero consumo de NetIDs, cero tráfico de sincronización física.
- **Etapas visuales:** **3 fases** en MVP (semilla/brote, crecimiento, maduro) con soporte dinámico para **N fases** (`stages`). Interacción vía **ox_target**.

## Módulo 5 — Interfaz de Usuario (NUI) y Estética

- **Arquitectura híbrida:** **ox_lib** para acciones de campo ultrarrápidas; **NUI custom** solo para dashboards complejos (tech-tree, estadísticas, mercado).
- **Stack:** **React + Vite + Tailwind CSS**, empaquetado como SPA independiente en `web/build`.
- **Idioma:** **English-Only** en todo el código base (UI, variables, comentarios, logs, config, mensajes de servidor). Sin capa de traducción.
- **Identidad visual (Anti-AI clichés):** diseño limpio, editorial, altamente legible. **Se rechazan** glassmorphism, `backdrop-blur` pesado, neones fluorescentes y gradientes cibernéticos. Se opta por: estructuras sólidas y planas, jerarquía tipográfica estricta, alto contraste, bordes limpios (1px solid baja opacidad), micro-márgenes matemáticos, paleta **tierra/industrial neutra** (a definir).

## Módulo 6 — Sistema de API y Exports Públicos

- **Filosofía plataforma desde el día 1:** exports de cliente/servidor + eventos públicos documentados.
- **Registro dinámico (Opción A):** `exports.farming:RegisterCrop({...})` para registrar cultivos, herramientas y zonas desde recursos externos sin tocar el núcleo.
- **Hooks de economía:** callbacks configurables para modificar rendimientos y precios en runtime.

## Módulo 7 — Progresión / Tech-Tree

- **Modelo mixto (Opción C):** **XP** para nivel general de personaje + **árbol de tecnologías** por ramas (especializaciones y pasivas).
- **Desbloqueos:** por nivel (semillas, herramientas, recetas) y por puntos de tech-tree (bonus pasivos de rendimiento, velocidad, resistencia).
- **Persistencia:** por personaje (`citizenid`).

## Módulo 8 — Cultivos y Fisiología Vegetal

- **Data-driven total:** el motor es agnóstico a los cultivos; lee reglas desde tablas de configuración.
- **Fisiología (Opción B, realismo medio):** riego + salud + merma por descuido.
- **Clima/estaciones (Opción A):** sin impacto directo en MVP, con **hooks listos** para futuro.
- **Calidad y metadatos:** el cuidado del cultivo determina la **calidad final**, registrada como metadata en ox_inventory y afectando el valor de venta.

## Módulo 9 — Funcionalidades y Sistemas Jugables

- **Tenencia de tierra (Opción A):** zonas públicas delimitadas en MVP; estructura preparada para parcelas privadas/propiedades en Fase 2.
- **Cadena económica:** bucle inicial **Sembrar → Cuidar → Cosechar → Vender a NPC**.
- **Economía (Opción A):** precios fijos configurables **ajustados por calidad**, con capa abstraída para mercado dinámico futuro.
- **Roadmap:** Contratos/Misiones y **Sistema Business** (empresas agrícolas gestionadas por jugadores con contratación de empleados).

## Módulo 10 — Gameplay (Núcleo Diferenciador)

- **Sin "mantener E y esperar":** el trabajo manual se fundamenta en **minijuegos activos** que exigen habilidad y precisión para obtener **calidad máxima (100%)** y XP extra.
- **Mecanización y riesgo:** la maquinaria/automatización permite **saltar los minijuegos** y cubrir grandes extensiones rápido, pero impone un **techo de calidad (75-80%)** y **riesgo de dañar/matar** la planta si no está mantenida/calibrada.
- **Feedback sensorial alto:** PTFX al trabajar, sonidos 3D, notificaciones limpias.

## Módulo 11 — Motor de Minijuegos (NUEVO — módulo propio)

> Elevado a módulo independiente por decisión del Technical Lead: los minijuegos son el corazón del gameplay y el mayor reto técnico. Requieren un **framework de minijuegos profesional y reutilizable**, no minijuegos hardcodeados.

- **Framework de minijuegos** desacoplado y reutilizable (registro de minijuegos por tipo de acción/cultivo/herramienta).
- **Server-authoritative:** el resultado (score/calidad) se **valida en servidor**; el cliente no puede reportar un 100% arbitrario. El servidor conoce parámetros y umbrales; anti-exploit por diseño.
- **Renderizado NUI o nativo** según el minijuego; API común de "iniciar minijuego → devolver score 0-100".
- **Escalable:** añadir un minijuego nuevo = registrar un módulo, sin tocar la lógica de farming.

---

## Decisiones transversales de proyecto

- **46 — Workspace:** estructura muy organizada, pensada a nivel empresarial y lista para escalabilidad futura (monorepo: core Lua + `web/` para NUI).
- **47 — Nombre del recurso:** `sonar_farm`.
- **48 — Documentación:** `docs/` (API.md, GAMEPLAY.md, CONFIG.md, CHANGELOG.md) en **español**; código/script **100% inglés**.
- **49 — Repositorio:** https://github.com/yaboula/sonar_farm_v1.git (branch `main`, Conventional Commits, commit por módulo, push tras cada commit).
- **50 — Orden de construcción del MVP (actualizado con Módulo 11):**
  1. Bootstrap del recurso + estructura empresarial + Bridge Layer (QB-Core/ox).
  2. Motor de estado en memoria + persistencia (oxmysql, dirty flags, crecimiento por timestamp).
  3. Lógica de servidor autoritativa (plantar/cuidar/cosechar + validaciones + token bucket + logging).
  4. Motor visual cliente (spatial hashing, props client-side, culling <30m, 3 fases).
  5. **Framework de minijuegos (Módulo 11)** + integración con acciones de farming.
  6. Gameplay + feedback sensorial (PTFX, sonidos 3D, ox_target, animaciones).
  7. Config data-driven de verduras + progresión (XP + tech-tree básico).
  8. Venta a NPC + economía por calidad.
  9. NUI dashboard (React/Vite/Tailwind) + pulido estético.
  10. API pública / exports + hooks de economía + documentación de plataforma.

---

## Principios de ingeniería (no negociables)

- **Server-authoritative** en todo lo que da valor.
- **Data-driven**: contenido en config, no en código.
- **Escalabilidad por diseño**: Bridge, plugin system (`RegisterCrop`), minijuegos registrables.
- **Rendimiento primero**: 0.00 ms en reposo, sin ticks de crecimiento, culling agresivo, client-side props.
- **English-only** en código; **español** en docs.
