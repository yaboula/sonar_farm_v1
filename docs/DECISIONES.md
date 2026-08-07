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

## Decisiones de la Etapa 3 (implementación)

Tomadas al construir la lógica autoritativa. Se documentan porque condicionan las etapas siguientes.

### Transporte y contrato

- **Callbacks de `ox_lib`, no eventos fire-and-forget.** Toda acción devuelve `{ ok, reason, data }`. El cliente sabe si funcionó sin inventar timeouts y no existe estado a medias.
- **El servidor devuelve códigos, no frases** (`too_far`, `missing_seed`). El cliente traduce. El servidor queda agnóstico al idioma y no se duplican textos.
- **La posición se lee siempre en el servidor** con `GetEntityCoords(GetPlayerPed(source))`. Las coordenadas del cliente se ignoran por completo: es la diferencia entre anti-cheat real y decorativo.

### Anti-teleport con tolerancia

La detección de movimiento imposible **debe** tolerar los casos en que las coordenadas del servidor no son fiables, o castiga a jugadores legítimos justo al conectar. Tres guardas:

1. La primera muestra solo inicializa la caché, sin comprobar velocidad.
2. Las muestras más antiguas que `PositionSampleTtl` se descartan (cambio de routing bucket o interior).
3. Los jugadores dentro de `ConnectGracePeriod` se omiten, porque el ped aún está haciendo streaming y puede reportar el origen del mapa.

### Permisos separados: cuidar vs. cosechar

- `AllowPublicCare = true`: cualquiera puede regar un cultivo ajeno. Deliberado, no un descuido: permite **salvar la cosecha de un vecino** y genera cooperación real sin abrir la puerta al robo.
- `OwnerOnlyHarvest = true`: la cosecha es del propietario. Si se pone en `false`, el robo se permite pero penaliza la calidad (`TheftQualityPenalty = 0.3`) y se registra como evento de rol/ilegal.
- Decisión de aplicar la penalización a la **calidad** y no al rendimiento: la calidad mueve el precio, así que el producto robado vale menos, que es más coherente que dar menos unidades.

### Integridad y concurrencia

- **Orden en cosecha:** comprobar `CanCarry` → entregar el item → borrar el cultivo. Al revés, un inventario lleno destruiría la cosecha.
- **Lock por `cropId` durante la acción:** evita que dos cosechas simultáneas entreguen producto dos veces. Es el fallo que no aparece en pruebas manuales pero sí el día que dos jugadores pulsan a la vez.
- **Cada módulo libera lo que reserva** en `playerDropped`: buckets en `ratelimit`, caché de posición y cooldowns en `validation`. Centralizar la limpieza en un módulo ajeno acopla y termina olvidando una tabla.

### Límites y contenido

- `MaxCropsPerPlayer = 25`: sin parcelas privadas todavía, evita que un jugador o un bot monopolice una zona pública.
- Las 4 verduras tienen **fisiología deliberadamente distinta** para que cada una ejercite un camino de código: tubérculos (`carrot`, `potato`) resisten la sequía, la hoja (`lettuce`) es rápida y frágil, el fruto (`tomato`) es lento y exigente.
- `tomato.multiHarvest` existe en el esquema pero está **inactivo**: documenta la intención sin implementar cosecha múltiple fuera de plan.

### Calidad: el contrato que evita refactor en la Etapa 5

`Quality.RegisterProvider` / `SetProvider` aísla "cuánto de bien lo hizo el jugador" del resto de la lógica. Hoy un stub devuelve `Config.Quality.DefaultScore`; cuando lleguen los minijuegos se registra un proveedor real y **no cambia ni una línea** de `plant.lua`, `care.lua` ni `harvest.lua`. Si un proveedor falla o no devuelve número, se registra y se cae al valor por defecto: un minijuego roto nunca bloquea la cosecha.

---

## Decisiones de la Etapa 4 (implementación)

Las 23 preguntas de [CUESTIONARIO_ETAPA4.md](CUESTIONARIO_ETAPA4.md) se cerraron con las recomendaciones aceptadas. Lo que sigue es lo que condiciona etapas futuras.

### La decisión que estructura el resto

**El cliente deriva el crecimiento desde timestamps, no lo recibe calculado.** El crecimiento es una función pura del tiempo, así que el cliente puede predecirlo sin poder falsearlo: la predicción solo afecta a qué modelo dibuja y qué opciones ofrece, nunca a lo que recibe. Un campo lleno de cultivos creciendo no genera tráfico de red.

Consecuencia obligatoria: la fórmula vive en **un solo fichero compartido** (`shared/growth.lua`, `shared/physiology.lua`), no duplicada. Con dos copias, la divergencia es cuestión de tiempo y se manifiesta como "la planta se ve madura pero el servidor no me deja cosechar". Los mutadores (`Apply`, `Water`) siguen siendo exclusivos del servidor.

Segunda consecuencia: predecir desde timestamps exige que ambos lados compartan el mismo "ahora". El servidor manda `serverTime` en cada sincronización y el cliente guarda el offset, de modo que un jugador con la hora del sistema mal no ve fases equivocadas.

### Sincronización

- **Snapshot + deltas por celda.** El snapshot resuelve la entrada (aparecer, bajar de un coche) y los deltas el mantenimiento. Solo deltas tendría el problema del arranque en frío: quien acaba de conectar vería un campo vacío.
- **Las celdas se derivan de la posición real en el servidor y el callback no acepta argumentos.** Si el cliente pudiera nombrar sus celdas, un cliente modificado volcaría todos los cultivos del mapa y sus propietarios.
- **`isMine` en lugar del `citizenid`.** Ninguna funcionalidad necesita el identificador ajeno en el cliente, y filtrarlo alimenta metagaming.
- **Deltas bufferizados durante la suscripción.** El snapshot reemplaza la caché, así que sin buffer un cultivo plantado durante el viaje de ida y vuelta quedaría invisible hasta el siguiente cambio de celda.
- **Los deltas de render no son API pública.** El motor interno se dispara con llamadas explícitas desde los handlers, no escuchando los eventos públicos: acoplar el funcionamiento interno a una superficie que otros pueden modificar sería frágil.

### Renderizado

- Props **no networkeados**: cero NetIDs, cero tráfico de física.
- Radio de 30m con **tope duro** de props priorizando los más cercanos. El caso patológico (20 jugadores × 25 cultivos en la misma zona) son 500 entidades y unos FPS de un dígito.
- **Snap al suelo por raycast**: la `pos_z` guardada es la posición del pie del jugador y flota o se entierra en cualquier pendiente.
- **Variación solo de rotación**, derivada del `cropId`. No hay native fiable para escalar props, así que no se ofrece escala. Derivarlo del id (y no de `math.random`) garantiza que dos jugadores vean la misma planta igual.
- **Destruir y recrear** al cambiar de fase: no hay swap limpio de modelo en una entidad viva, y una fase cambia 3 veces en 15 minutos.
- **Validación de modelos al arrancar**, con aviso por nombre y respaldo en runtime. Un nombre de prop equivocado no produce ningún error: simplemente no aparece nada.

### Interacción

- **Anclada al prop** (`AddLocalEntity`): un solo ciclo de vida para "existe visualmente" y "es interactuable".
- **Distancia por debajo del umbral del servidor** (2.2 frente a 3.0). Si ox_target deja pulsar, el servidor no rechaza por distancia; un `too_far` pasa a significar lo que debe, un intento de exploit.
- **El `cropId` se captura en el closure** de la opción, no se busca desde la entidad. `canInteract` corre mientras el jugador apunta, así que no puede contener búsquedas.
- **Sin `DrawText3D`**: obligaría a un bucle por frame por planta visible. El estado se muestra en la opción `Inspect`, que solo se calcula al apuntar.

### Robustez

- **Autocorrección por rechazo.** Un rechazo cuyo motivo implique caché obsoleta fuerza resuscripción. Cada desacuerdo con el servidor se convierte en una corrección, y eso es lo que hace segura la predicción.
- **Limpieza en `onResourceStop`.** Sin ella, cada `restart` deja props huérfanos que nadie puede borrar.
- **Interiores en lugar de routing bucket.** Los buckets no son legibles desde el cliente, así que se usa la detección de interior como proxy honesto.

### Alcance

Nada de PTFX, sonidos ni animaciones: eso es la Etapa 6. La barra de progreso es un placeholder deliberadamente pobre y marcado como temporal, porque la Etapa 5 la sustituye por minijuegos. Construirla bien ahora sería hacer la Etapa 6 dos veces.

### Deuda pagada

`Validation.CropLimit` ya no recorre todo el estado: `State` mantiene un índice por propietario. Se pagó aprovechando que esta etapa ya tocaba el indexado espacial.

### Slots fijos (post Etapa 4)

El plantado libre dentro de un radio se sustituyó por surcos configurados:

- Capacidad dura por zona (`rows * cols`), economía predecible.
- Posición siempre desde config en el servidor: el cliente solo manda `zone` + `slot`.
- Interacción: ox_target sobre el surco vacío; la semilla usable planta en el slot vacío más cercano (nunca en coordenadas libres).
- Lock por `zone:slot` al plantar para que dos jugadores no ocupen el mismo surco a la vez.
- Índices 1-based: el `NULLIF(?, '')` de oxmysql trataría el slot `0` como NULL.
- `SlotProp` opcional y apagado por defecto: los targets existen sin prop extra.

---

## Principios de ingeniería (no negociables)

- **Server-authoritative** en todo lo que da valor.
- **Data-driven**: contenido en config, no en código.
- **Escalabilidad por diseño**: Bridge, plugin system (`RegisterCrop`), minijuegos registrables.
- **Rendimiento primero**: 0.00 ms en reposo, sin ticks de crecimiento, culling agresivo, client-side props.
- **English-only** en código; **español** en docs.
