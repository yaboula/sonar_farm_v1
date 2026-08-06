# Cuestionario de Visión — Script de Farming Escalable (FiveM)

> Objetivo: alinear la visión de producto, arquitectura y game design **antes** de escribir código.
> Stack objetivo inicial: **QB-Core**, **ox_lib**, **ox_inventory**, **ox_target** (con Bridge para futuras compatibilidades).
> Alcance de la primera entrega (MVP): **verduras**, con arquitectura preparada para escalar a otros cultivos y sistemas.
>
> Instrucciones: responde en línea bajo cada pregunta (`> Respuesta:`). Cada pregunta trae **opciones** y una **[Recomendación]** de arquitecto. Si estás de acuerdo con la recomendación, basta con escribir "ok".

---

## Leyenda de prioridad

- 🔴 Crítico (decisión estructural, difícil de cambiar después)
- 🟠 Importante (afecta a varios módulos)
- 🟢 Ajuste fino (fácil de cambiar más adelante)

---

## Módulo 1 — Capa de Abstracción (Bridge Layer) 🔴

> Rol: aislar el core del framework (QB-Core hoy, ESX/Qbox mañana) para que el 95% del código no dependa de ningún framework concreto.

1. **[🔴] Frameworks objetivo a corto/medio plazo.** ¿Solo QB-Core al inicio, o el Bridge debe contemplar desde el día 1 la estructura para ESX y Qbox?
  - a) Solo QB-Core ahora, Bridge con "hueco" para el resto.
  - b) QB-Core + Qbox desde el inicio (comparten mucho).
  - c) QB-Core + ESX + Qbox.
  - **[Recomendación]** a) — diseñar la interfaz del Bridge completa, pero implementar solo QB-Core para no dispersarnos.
    > Respuesta:
2. **[🔴] Detección de dependencias.** ¿Auto-detección de recursos (`GetResourceState`) o configuración manual explícita en `config`?
  - a) Auto-detección con fallback a config.
  - b) Config manual estricta (más predecible).
  - **[Recomendación]** a) — auto-detecta y avisa por consola si falta algo obligatorio.
    > Respuesta:
3. **[🟠] Inventario.** ¿Solo ox_inventory, o Bridge de inventario para soportar qb-inventory/qs-inventory a futuro?
  - a) Solo ox_inventory (más limpio, metadata rica).
  - b) Bridge de inventario abstracto.
  - **[Recomendación]** a) — ox_inventory como estándar; abstraer solo las 4-5 llamadas clave por si acaso.
    > Respuesta:
4. **[🟠] Target y notificaciones.** ¿Fijamos ox_target + ox_lib (notify, progressbar, context menu, input) como dependencia dura, o abstraemos target/notify?
  - a) ox_target + ox_lib como dependencia dura (recomendado para calidad UX).
  - b) Abstraer target/notify para qb-target/otros.
  - **[Recomendación]** a) — ox_lib es el estándar de calidad en 2026.
    > Respuesta:

---

## Módulo 2 — Lógica de Negocio Autoritativa en Servidor 🔴

> Rol: el servidor es la única fuente de verdad. El cliente solo pide y renderiza. Anti-cheat by design.

1. **[🔴] Modelo de confianza.** Confirmamos que **todas** las acciones que dan valor (plantar, cosechar, procesar, vender) se validan y ejecutan en servidor, y el cliente nunca decide cantidades ni recompensas. ¿De acuerdo?
  - **[Recomendación]** Sí, 100% server-authoritative. El cliente solo envía "intención" + IDs.
    > Respuesta:
2. **[🔴] Validación anti-exploit por acción.** ¿Qué nivel de validación exigimos por defecto?
  - a) Distancia + cooldown + posesión de item + estado del cultivo (recomendado).
  - b) Lo anterior + rate-limiting por jugador + detección de patrones (teleport, spam).
  - **[Recomendación]** b) — en 2026 el anti-exploit es diferenciador; rate-limiting central y logging de sospechas.
    > Respuesta:
3. **[🟠] Rate-limiting / cooldowns.** ¿Cooldowns por acción individuales, o un "presupuesto de acciones" por jugador (token bucket)?
  - a) Cooldowns simples por acción.
  - b) Token bucket global anti-spam + cooldowns por acción.
  - **[Recomendación]** b) — protege el hilo del servidor ante spam de eventos.
    > Respuesta:
4. **[🟠] Logging / auditoría.** ¿Integramos logs (Discord webhook / oxmysql) de acciones económicas para auditoría desde el inicio?
  - a) Sí, logging estructurado con niveles (info/warn/exploit).
  - b) Solo consola por ahora.
  - **[Recomendación]** a) — logging modular con adapters (consola, Discord, ox_lib).
    > Respuesta:

---

## Módulo 3 — Motor de Estado en Memoria y Persistencia Asíncrona 🔴

> Rol: rendimiento. Miles de plantas no pueden golpear la DB constantemente. Estado en RAM + persistencia por lotes.

1. **[🔴] Fuente de verdad en runtime.** ¿Estado de cultivos vive en memoria del servidor (tabla Lua) y se sincroniza a DB de forma asíncrona por lotes?
  - **[Recomendación]** Sí — memoria como verdad en caliente, DB como respaldo. Save por lotes cada X segundos + save en eventos críticos (cosecha, resource stop).
    > Respuesta:
2. **[🔴] Base de datos.** ¿oxmysql como capa de acceso? ¿Modelo de tablas relacional clásico o JSON blob por zona/parcela?
  - a) oxmysql + esquema relacional normalizado (cultivos, zonas, jugadores, progresión).
    - b) oxmysql + blobs JSON por zona (más simple, menos consultable).
    - **[Recomendación]** a) — relacional para poder hacer analítica/economía; JSON solo para metadata flexible.
      > Respuesta:
3. **[🟠] Frecuencia de persistencia.** ¿Cada cuánto guardamos y bajo qué estrategia?
  - a) Batch cada 60s + dirty-flag (solo guarda lo cambiado) + save en `onResourceStop`.
    - b) Guardado inmediato por acción (más seguro, más carga DB).
    - **[Recomendación]** a) — dirty-flag + batch; es el equilibrio profesional.
      > Respuesta:
4. **[🟠] Crecimiento de plantas.** ¿El crecimiento se calcula por "timestamp" (plantado_en + tiempo transcurrido, sin ticks) o por tick de servidor?
  - a) Basado en timestamps (crecimiento "offline", sin coste de CPU, escalable a miles).
    - b) Tick loop de servidor.
    - **[Recomendación]** a) — timestamp-based: las plantas crecen aunque el servidor no las procese activamente; se recalcula al consultar.
      > Respuesta:
5. **[🟢] Multi-servidor / sharding futuro.** ¿Debemos contemplar varios servidores compartiendo DB (sync entre instancias) o un solo servidor?
  - **[Recomendación]** Un solo servidor por ahora; dejar la puerta abierta sin implementar.
    > Respuesta:

---

## Módulo 4 — Motor Visual de Clientes y Optimización (Stream & Culling) 🔴

> Rol: que 2000 plantas no maten los FPS. Renderizar solo lo cercano/visible. Aquí se gana o se pierde el rendimiento del cliente.

1. **[🔴] Representación de la planta.** ¿Props/objetos reales, o mezcla de props + zonas lógicas?
  - a) Props reales por planta con LOD y culling agresivo.
    - b) Props solo cerca del jugador; a distancia, "zonas" abstractas sin objeto.
    - **[Recomendación]** b) — spawning/despawning dinámico por distancia (grid espacial), nunca todas las entidades a la vez.
      > Respuesta:
2. **[🔴] Estrategia de culling.** ¿Grid espacial + radio de interés por jugador para decidir qué se spawnea?
  - **[Recomendación]** Sí — spatial hashing/bucketing por celdas; el cliente solo recibe entidades de su celda + adyacentes.
    > Respuesta:
3. **[🟠] Sincronización de entidades.** ¿Entidades creadas localmente en cliente (client-side objects, sin networkear) o entidades networkeadas?
  - a) Objetos locales por cliente (recomendado: 0 carga de red, cada cliente crea lo suyo).
    - b) Entidades networkeadas por servidor.
    - **[Recomendación]** a) — client-side, el servidor solo manda datos (posición, estado, tipo), el cliente materializa el prop.
      > Respuesta:
4. **[🟠] Estados visuales de crecimiento.** ¿Cuántas fases visuales por planta (modelos distintos por etapa)?
  - a) 3 fases (semilla/brote, crecimiento, maduro).
    - b) 4-5 fases con transición de modelo/textura.
    - **[Recomendación]** a) para MVP, arquitectura que permita N fases por config.
      > Respuesta:
5. **[🟢] Interacción visual.** ¿Marcadores/halos sobre plantas listas para cosechar, o solo texto de ox_target al apuntar?
  - **[Recomendación]** ox_target al apuntar + marcador sutil opcional (config) para no saturar.
    > Respuesta:

---

## Módulo 5 — Interfaz de Usuario (NUI) Moderna 🟠

> Rol: la experiencia visual premium. Menús de gestión de granja, progresión, estadísticas.

1. **[🔴] Alcance de la NUI.** ¿Qué necesita NUI propia vs. qué se resuelve con ox_lib (context/menu/dialog)?
  - a) NUI propia solo para el "panel de granja/progresión" (dashboard); resto con ox_lib.
    - b) NUI propia para todo (más control, más trabajo).
    - **[Recomendación]** a) — ox_lib para acciones rápidas; NUI custom solo para dashboards ricos (tech-tree, stats, mercado).
      > Respuesta:
2. **[🟠] Stack NUI.** Si hacemos NUI custom, ¿framework?
  - a) React + Vite + Tailwind (moderno, ecosistema fuerte).
    - b) Vue 3 + Vite.
    - c) HTML/CSS/JS vanilla (ligero).
    - **[Recomendación]** a) React + Vite + Tailwind — mejor DX y componentes reutilizables.
      > Respuesta:
3. **[🟢] Idioma / i18n de la UI.** ¿Sistema de locales desde el inicio (es/en/fr) o solo inglés?
  - **[Recomendación]** Sistema i18n con locales; empezar en inglés + español.
    > Respuesta:
4. **[🟢] Estética.** ¿Estilo visual objetivo del dashboard?
  - a) "Farming moderno" (verdes/tierra, orgánico, premium).
    - b) "Tech/MES industrial" (oscuro, datos, dashboards).
    - c) Neutro glassmorphism.
    - **[Recomendación]** definir en fase de diseño; propongo a) orgánico premium para farming.
      > Respuesta:

---

## Módulo 6 — Sistema de API y Exports Públicos 🟠

> Rol: que otros scripts/desarrolladores extiendan el nuestro. Diferenciador de un producto "plataforma" vs. un script cerrado.

1. **[🟠] Filosofía de extensibilidad.** ¿Diseñamos el script como "plataforma" con exports + eventos públicos documentados desde el día 1?
  - **[Recomendación]** Sí — exports server/client + eventos (`onCropPlanted`, `onCropHarvested`, etc.) + hooks para modificar recompensas.
    > Respuesta:
2. **[🟠] Registro dinámico de contenido.** ¿Permitimos que otros recursos registren cultivos/herramientas/zonas vía export (plugin system)?
  - a) Sí, `exports.farming:registerCrop({...})` (plataforma real).
    - b) No, todo el contenido vive en nuestro config.
    - **[Recomendación]** a) — registro dinámico = escalabilidad infinita sin tocar el core.
      > Respuesta:
3. **[🟢] Hooks de economía.** ¿Exponemos hooks para que server owners modifiquen precios/recompensas/mermas en runtime?
  - **[Recomendación]** Sí, callbacks configurables (p.ej. `calculateYield`, `calculatePrice`).
    > Respuesta:

---

## Módulo 7 — Escalabilidad en Formas de Trabajo (Progresión / Tech-Tree) 🟠

> Rol: la profundidad de largo plazo. Que el jugador tenga metas y sensación de crecimiento.

1. **[🔴] Sistema de progresión.** ¿Qué modelo de progresión de base?
  - a) XP + niveles de "granjero" que desbloquean cultivos/herramientas/zonas.
    - b) Tech-tree por ramas (agricultura, procesamiento, comercio) con puntos de habilidad.
    - c) Ambos: XP para nivel general + tech-tree para especialización.
    - **[Recomendación]** c) — XP como columna vertebral + tech-tree por ramas para profundidad.
      > Respuesta:
2. **[🟠] Qué desbloquea la progresión.** (marca lo que aplica)
  - Nuevos cultivos / semillas / herramientas mejores / nuevas zonas / recetas de procesamiento / mejoras pasivas (más yield, menos merma, crecimiento más rápido).
    - **[Recomendación]** Todas, distribuidas entre niveles (contenido) y tech-tree (bonus pasivos).
      > Respuesta:
3. **[🟢] Persistencia de progresión.** ¿Progresión por personaje (citizenid) o por cuenta/licencia?
  - **[Recomendación]** Por personaje (citizenid), coherente con QB-Core.
    > Respuesta:

---

## Módulo 8 — Escalabilidad en Tipos de Cultivos y Fisiología Vegetal 🟠

> Rol: que añadir un cultivo nuevo sea "rellenar un config", no reprogramar. Y que cada cultivo se "sienta" distinto.

1. **[🔴] Modelo de datos de cultivo.** ¿Definimos cada cultivo con un esquema rico y data-driven?
  - Ejemplo de campos: `growthStages`, `growthTime`, `waterNeeds`, `soilType`, `season`, `yieldRange`, `spoilage/merma`, `xpReward`, `requiredLevel`, `props[]`, `seedItem`, `productItem`.
    - **[Recomendación]** Sí — todo data-driven; el core lee el esquema y no conoce cultivos concretos.
      > Respuesta:
2. **[🟠] Profundidad de "fisiología vegetal".** ¿Cuánto realismo queremos en el MVP de verduras?
  - a) Simple: plantar → esperar → cosechar (con riego opcional).
    - b) Medio: riego + fertilizante + salud de planta (se puede marchitar si no se cuida).
    - c) Avanzado: agua + nutrientes del suelo + clima/estación + plagas + enfermedades.
    - **[Recomendación]** b) para MVP (riego + salud + merma por descuido), con arquitectura lista para c).
      > Respuesta:
3. **[🟠] Clima y estaciones.** ¿El clima/estación de FiveM afecta al crecimiento desde el inicio?
  - a) No en MVP (dejar hooks).
    - b) Sí, modificadores por clima/estación.
    - **[Recomendación]** a) — hooks listos, activación en fase posterior.
      > Respuesta:
4. **[🟢] Merma / calidad.** ¿Sistema de calidad del producto (pobre/normal/premium) que afecte al precio?
  - **[Recomendación]** Sí — calidad basada en cómo se cuidó la planta; gran diferenciador de gameplay.
    > Respuesta:

---

## Módulo 9 — Escalabilidad de Funcionalidades y Sistemas Jugables 🟠

> Rol: qué sistemas rodean al farming para convertirlo en una economía/loop completo.

1. **[🔴] Modelo de tenencia de tierra.** ¿Dónde se cultiva?
  - a) Zonas públicas compartidas (cualquiera planta en zonas designadas).
    - b) Parcelas privadas por jugador (comprar/alquilar terreno).
    - c) Sistema de granjas/propiedades (integración con housing).
    - **[Recomendación]** a) para MVP + arquitectura para b) parcelas privadas después.
      > Respuesta:
2. **[🟠] Cadena económica.** ¿Loop completo desde el inicio o por fases?
  - Fases posibles: sembrar → cosechar → **procesar** (limpiar/empaquetar) → **vender** (NPC/mercado dinámico/entrega).
    - **[Recomendación]** MVP = sembrar→cosechar→vender a NPC con precio configurable; procesamiento y mercado dinámico como fases 2-3.
      > Respuesta:
3. **[🟠] Economía dinámica.** ¿Precios fijos o mercado con oferta/demanda?
  - a) Precios fijos configurables (MVP).
    - b) Mercado dinámico (el precio baja si todos venden lo mismo).
    - **[Recomendación]** a) ahora, con la capa de precio abstraída para meter b) sin refactor.
      > Respuesta:
4. **[🟢] Sistemas de apoyo (roadmap).** ¿Cuáles te interesan para el roadmap? (marca)
  - Trabajo cooperativo/gangs, herramientas y vehículos agrícolas, riego automático/infraestructura, contratos/misiones, ranking/leaderboards, eventos temporales, integración business (empresa agrícola con empleados).
    - **[Recomendación]** priorizar: contratos/misiones + herramientas mejorables + cooperativo. Resto backlog.
      > Respuesta:

---

## Módulo 10 — GAME PLAY (núcleo diferenciador) 🔴🔴🔴

> Rol: LO MÁS IMPORTANTE. Aquí es donde superamos a 0r, 17mov, Codem, Prism, Nano. El objetivo es que farmear **no sea "hold E y esperar"**, sino una experiencia con skill, feedback y sensación premium.

1. **[🔴] Filosofía anti-tedio.** ¿Qué define un "buen momento a momento" para ti?
  - a) Skill-based: minijuegos/timing que recompensan la habilidad (mejor cosecha si lo haces bien).
    - b) Gestión/estrategia: la diversión está en optimizar la granja, no en el input manual.
    - c) Inmersión: animaciones, feedback físico, realismo satisfactorio.
    - d) Mezcla equilibrada de las tres.
    - **[Recomendación]** d) con énfasis en c) inmersión + a) skill ligero, evitando el "hold E" plano.
      > Respuesta:
2. **[🔴] Interacción de siembra/cosecha.** ¿Cómo se siente el acto de plantar/cosechar?
  - a) ox_target + progressbar de ox_lib (estándar, sólido).
    - b) Progressbar + animación + props en mano + skill check ocasional.
    - c) Minijuego dedicado (timing/ritmo) con recompensa variable según desempeño.
    - **[Recomendación]** b) como base premium (animaciones + props + feedback), c) para acciones clave (cosecha de calidad).
      > Respuesta:
3. **[🟠] Skill checks / minijuegos.** ¿Los usamos y dónde?
  - a) No (fricción innecesaria).
    - b) Solo en momentos de valor (cosecha premium, procesamiento).
    - c) En casi todo.
    - **[Recomendación]** b) — usados con moderación para que aporten, no molesten (recordar UX guantes/pantalla sucia si aplicara, aunque aquí es un juego).
      > Respuesta:
4. **[🔴] Feedback y "juice".** ¿Qué nivel de feedback sensorial buscamos?
  - Elementos: partículas al cosechar, sonidos satisfactorios, animaciones fluidas, screen shake sutil, números flotantes de recompensa/XP, notificaciones elegantes.
    - **[Recomendación]** Alto — el "juice" es lo que separa un script premium de uno genérico. Todo lo anterior, con moderación de rendimiento.
      > Respuesta:
5. **[🟠] Bucle de recompensa (retención).** ¿Qué mantiene al jugador enganchado sesión a sesión?
  - a) Progresión/desbloqueos constantes.
    - b) Objetivos diarios/semanales + racha.
    - c) Colección (completar todos los cultivos, logros).
    - d) Competencia (leaderboards, mercado).
    - **[Recomendación]** combinación de a) + b) desde etapas tempranas; c) y d) en roadmap.
      > Respuesta:
6. **[🟠] Cooperación / social.** ¿El farming es individual o fomenta juego en grupo?
  - a) Individual (cada uno su granja).
    - b) Cooperativo opcional (ayudar acelera, granjas compartidas).
    - **[Recomendación]** individual sólido en MVP, con hooks para cooperativo (b) en roadmap.
      > Respuesta:
7. **[🔴] Anti-AFK / anti-macro.** ¿Cómo evitamos que sea puro farmeo pasivo/macro?
  - a) Crecimiento por timestamp (offline) + acciones activas que dan bonus de calidad/XP.
    - b) Requiere presencia activa (riego, cuidado) para maximizar.
    - **[Recomendación]** a)+b) — puede farmearse relajado, pero el jugador activo obtiene mejor calidad/rendimiento. Sin premiar el macro.
      > Respuesta:
8. **[🟢] Referencias.** De los scripts que mencionaste (0r, 17mov, Codem, Prism, Nano), ¿qué **te gusta** de cada uno y qué **odias**? (esto guía el diseño diferencial)
  > Respuesta:
9. **[🟢] "Wow factor".** Si tuvieras que nombrar **una sola cosa** que haga decir "este farming es de otro nivel", ¿cuál sería?
  > Respuesta:

---

## Preguntas transversales de proyecto 🟠

1. **[🟠] Repositorio.** ¿Confirmamos monorepo (core Lua + NUI) en un solo recurso, o recurso separado para NUI?
  - **[Recomendación]** Un recurso (`sonar_farm`) con carpeta `web/` para la NUI.
    > Respuesta:
2. **[🟢] Nombre del recurso.** ¿`sonar_farm`, otro?
  > Respuesta:
3. **[🟢] Documentación.** ¿Mantenemos `docs/` (API.md, GAMEPLAY.md, CONFIG.md, CHANGELOG.md) en español desde el inicio?
  - **[Recomendación]** Sí — documentación en español, textos de UI in-game en inglés (o el idioma que definas en Q21).
    > Respuesta:
4. **[🟢] Control de versiones / Git.** ¿Inicializamos git con Conventional Commits y commits por módulo?
  - **[Recomendación]** Sí — commit por módulo funcional.
    > Respuesta:
5. **[🟠] Orden de construcción del MVP.** ¿Confirmas este orden de entrega módulo a módulo?
  1. Bootstrap del recurso + Bridge Layer (QB-Core/ox).
  2. Estado en memoria + persistencia (DB, crecimiento timestamp).
  3. Lógica servidor (plantar/cosechar/validaciones).
  4. Motor visual cliente (spawn/culling/props por fase).
  5. Interacción + gameplay (target, animaciones, feedback).
  6. Config data-driven de verduras + progresión básica.
  7. Venta a NPC + economía básica.
  8. NUI dashboard + pulido.
    **[Recomendación]** Este orden (fundaciones → gameplay → contenido → UI).
    Respuesta:

---

### Notas libres / visión adicional

> Escribe aquí cualquier idea, referencia o requisito que no encaje en las preguntas anteriores:

