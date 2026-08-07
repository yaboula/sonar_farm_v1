# Cuestionario de Alineación — Etapa 4: Motor Visual y Optimización

Etapa 4 = **Stream & Culling**. Es la etapa donde el jugador *ve* por primera vez lo que hasta ahora solo existía en RAM y en la base de datos.

Es también la etapa con más riesgo de rendimiento de todo el proyecto: aquí se decide si el script marca `0.00 ms` en reposo con 2000 cultivos en el mapa, o si tira el servidor a 40 FPS. Por eso quiero cerrar estas decisiones antes de escribir código, no durante.

> **Cómo responder:** basta con el número de pregunta y la letra (ej. `1.C`, `2.A`). Si estás de acuerdo con todas mis recomendaciones, dime "todo recomendado" y arranco.
>
> Las preguntas marcadas **[CRÍTICA]** son las que obligarían a reescribir módulos enteros si se eligen mal más tarde. Las demás son ajustables sin coste.

---

## Estado actual (de dónde partimos)

Lo que ya está construido y condiciona esta etapa:

- El índice espacial **ya existe** en el servidor: `State.CellKey(x, y)` con celdas de 100x100m (`Constants.SPATIAL_CELL_SIZE`) y `State.cells[cellKey]`, más el lookup `State.GetByCell(cellKey)`.
- El cliente **no tiene nada visual todavía**: `client/main.lua` solo inicializa el Bridge.
- `Bridge.Target` ya envuelve `ox_target` (`AddLocalEntity`, `AddBoxZone`, y sus `Remove*`).
- Cada cultivo ya tiene `stages` en `config/crops.lua` con `model` y `ratio`.
- El crecimiento y la fisiología son **derivables desde timestamps** (`planted_at`, `growth_time`, `data.lastCare`), sin ticks.

Ese último punto es la palanca más importante de toda la etapa, y es el fondo de la pregunta 1.

---

## Módulo A — Protocolo de sincronización servidor → cliente

### 1. [CRÍTICA] ¿Cómo se enteran los clientes del estado de los cultivos?

- **A) Pull periódico.** El cliente pide cada X segundos los cultivos cercanos (como el `sonar_farm:nearby` actual). Simple, pero es tráfico constante por jugador esté pasando algo o no, y escala mal: 60 jugadores = 60 consultas recurrentes al estado completo.
- **B) Push por suscripción a celdas.** El cliente informa de su celda; el servidor mantiene la lista de suscriptores por celda y **solo envía cambios** (plantado, regado, cosechado) a quien está mirando esa celda. Cero tráfico si nadie planta nada.
- **C) Híbrido: snapshot + deltas.** Al cambiar de celda, el cliente recibe un snapshot de su celda y las 8 adyacentes. A partir de ahí, solo deltas dirigidos a los suscriptores de esa celda.

> **Recomendación: C.** El snapshot resuelve la entrada (aparecer, bajar de un coche, cambiar de zona) y los deltas resuelven el mantenimiento. B sola tiene el problema del arranque en frío: un jugador que acaba de conectar no ha recibido ningún delta y ve un campo vacío. Es exactamente el patrón que ya prepara el índice `State.cells`.

### 2. [CRÍTICA] ¿El cliente recibe el estado calculado, o los datos para calcularlo él?

Esta es la pregunta que decide si el motor visual es gratis o caro.

- **A) El servidor envía el estado ya calculado** (`progress = 64%`, `water = 42`) y lo refresca periódicamente. El cliente es tonto del todo, pero el crecimiento es continuo en el tiempo: para que la planta *parezca* crecer hay que reenviar estado cada X segundos a todos los que miran. Tráfico permanente y proporcional a jugadores × cultivos.
- **B) El servidor envía los datos crudos** (`planted_at`, `growth_time`, parámetros de fisiología) **una sola vez**, y el cliente deriva el progreso localmente con la misma fórmula. Un cultivo plantado hoy no genera **ni un byte** de red hasta que alguien lo toque. El servidor sigue siendo la única autoridad: al actuar, recalcula y decide, y si el cliente mentía, rechaza.

> **Recomendación: B, sin dudarlo.** El crecimiento es una función pura del tiempo, así que el cliente puede predecirlo sin poder falsearlo: la predicción solo afecta a qué modelo dibuja y qué opción muestra en el menú, nunca a lo que recibe. Es la diferencia entre un script que escala a miles de cultivos y uno que no. Si el cliente calcula mal (o miente), el servidor rechaza la acción y ya tenemos el mecanismo de refresco (pregunta 20).

### 3. ¿Qué se envía como identidad del propietario?

- **A) El `citizenid` en crudo.** Cualquier jugador podría leer con un dumper quién es dueño de cada planta del mapa.
- **B) Solo un booleano `isMine`** calculado en el servidor por destinatario, más un nombre público opcional si algún día hace falta.

> **Recomendación: B.** No hay ninguna funcionalidad que necesite el `citizenid` ajeno en el cliente, y filtrarlo alimenta metagaming ("sé que este campo es de X"). El cliente solo necesita saber si puede cosechar, y eso el servidor ya lo sabe.

### 4. ¿Radio de suscripción?

- **A) Solo la celda actual** (100x100m). Ahorra memoria, pero al cruzar un borde el jugador ve aparecer plantas de golpe delante de él.
- **B) Celda actual + 8 adyacentes** (300x300m). El jugador siempre tiene datos por delante en cualquier dirección.

> **Recomendación: B**, tal como se decidió en el Módulo 4 de la visión. El coste de memoria es despreciable (son filas de datos, no entidades) y elimina el "popping" en los bordes.

---

## Módulo B — Renderizado de props

### 5. [CRÍTICA] ¿Los modelos de `config/crops.lua` son definitivos?

Hay que resolverlo antes de escribir el renderizador. Los modelos que puse (`prop_veg_crop_03`, `prop_veg_crop_orange`, `prop_veg_crop_tr_01`...) son **placeholders que no he verificado**. Si un modelo no existe, `CreateObject` falla en silencio: no hay error, simplemente no aparece nada, y se pierde una tarde depurando el streaming cuando el problema era el nombre del prop.

- **A) Solo props vanilla verificados.** Yo verifico cada hash con `IsModelValid` al arrancar, aviso por consola de los que fallen y uso un modelo de respaldo. Cero dependencias externas.
- **B) Props custom.** Tú aportas los modelos en `stream/` y yo los cableo.
- **C) Mixto:** vanilla ahora, con la ruta de custom lista para sustituirlos sin tocar código.

> **Recomendación: C, y en cualquier caso la validación de A.** La validación con aviso por consola debe entrar sí o sí: es la diferencia entre "no aparece nada y no sé por qué" y una línea clara que dice qué modelo falta. ¿Tienes props custom de cultivos, o vamos con vanilla?

### 6. ¿Presupuesto de entidades?

Cada prop es una entidad del cliente. Con `isNetwork = false` no gasta NetIDs (esa parte ya está decidida), pero sí cuesta render.

- **A) Sin límite:** se renderiza todo lo que haya en el radio.
- **B) Radio de 30m con tope duro** (~50 props simultáneos), priorizando los más cercanos.
- **C) Dos niveles:** props sólidos cerca (<30m) y algo baratísimo a media distancia (marcador simple) para que el campo no parezca vacío desde la carretera.

> **Recomendación: B para esta etapa, y evaluar C después de verlo en vivo.** El tope duro es un seguro contra el caso patológico: 20 jugadores plantando 25 cultivos cada uno en la misma zona son 500 plantas en 100 metros. Sin tope, eso son 500 entidades y unos FPS de un dígito.

### 7. ¿Cómo se asienta el prop en el suelo?

- **A) Usar la `pos_z` guardada al plantar.** Es la posición del jugador, que puede no ser el suelo exacto (pendiente, bordillo): planta flotando o medio enterrada.
- **B) Raycast al suelo en el cliente** (`GetGroundZFor_3dCoord`) al crear el prop, con la `pos_z` como respaldo si el raycast falla.

> **Recomendación: B.** Es barato (una vez por creación, no por frame) y es la diferencia entre un campo creíble y plantas levitando. Grapeseed tiene pendientes suaves por todas partes.

### 8. ¿Variación visual?

- **A) Todos los props idénticos**, con el `heading` guardado.
- **B) Rotación aleatoria y variación leve de escala** derivadas del `cropId` (determinista: todos los clientes ven la misma planta igual).

> **Recomendación: B.** Cuesta nada y rompe el efecto de "cuadrícula clonada" que delata a un script. Derivarlo del `cropId` en lugar de `math.random` es lo que garantiza que dos jugadores vean lo mismo.

### 9. ¿Transición entre fases de crecimiento?

- **A) Destruir y recrear** la entidad al cambiar de fase.
- **B) Mantener la entidad y cambiar el modelo.**

> **Recomendación: A.** En FiveM no hay un "swap de modelo" limpio sobre una entidad existente, y una fase cambia como mucho 3 veces en 15 minutos: no es una operación caliente. Simple y sin trucos.

---

## Módulo C — Interacción (ox_target)

### 10. [CRÍTICA] ¿Dónde se ancla la interacción?

- **A) `AddLocalEntity` sobre el prop.** El objetivo es la planta misma. Se limpia solo al destruir la entidad y es lo que el jugador espera apuntar.
- **B) Una esfera/box por cultivo.** Funciona sin prop, pero hay que gestionar la creación y destrucción de zonas en paralelo a los props: dos ciclos de vida que se pueden desincronizar.
- **C) Una zona grande por campo** que resuelve el cultivo más cercano al interactuar. Muy barato, pero la puntería es imprecisa y confunde con plantas juntas.

> **Recomendación: A.** Ata el ciclo de vida de la interacción al del prop, que es justo lo que ya vamos a gestionar. Una sola fuente de verdad para "existe visualmente" e "es interactuable".

### 11. ¿Distancia del target?

El servidor rechaza por encima de `Config.Security.MaxInteractDistance = 3.0`.

- **A) Igualar a 3.0.** En el límite exacto, el borde del target y el del servidor coinciden y el jugador puede ver un rechazo `too_far` apuntando a algo que ox_target le dejaba pulsar.
- **B) Poner el target en ~2.2m,** por debajo del umbral del servidor.

> **Recomendación: B.** El margen hace que un rechazo por distancia sea *imposible* en juego legítimo: si ox_target te deja pulsar, estás dentro. Los rechazos por distancia quedan reservados a lo que son, intentos de exploit.

### 12. ¿Opciones dinámicas en el menú?

- **A) Siempre las mismas tres opciones** (plantar/regar/cosechar) y que el servidor rechace lo que no toque.
- **B) `canInteract` filtra según el estado local:** "Water" solo si tiene sed, "Harvest" solo si está maduro.

> **Recomendación: B.** Un operario con guantes no debe leer un menú de opciones que van a fallar. El servidor sigue validando todo igual: el filtro es comodidad, no seguridad.

### 13. ¿Cómo ve el jugador el estado de la planta (agua, salud, progreso)?

- **A) Texto en la etiqueta de ox_target** ("Harvest — Fine, 92% health").
- **B) `lib.showTextUI`** al acercarse.
- **C) `DrawText3D` flotante** sobre cada planta.

> **Recomendación: A + B, y descartar C.** `DrawText3D` obliga a un bucle por frame por cada planta visible: es exactamente el tipo de coste que hace que un script pase de `0.00 ms` a `0.8 ms` sin que nadie sepa por qué. La etiqueta del target es gratis, porque solo se calcula al apuntar.

### 14. ¿Cómo se planta, sin un cultivo al que apuntar?

Plantar es la única acción sin objetivo previo.

- **A) Comando** (lo que hay ahora).
- **B) Usar el item de semilla desde ox_inventory** (`export` de item usable). Es el gesto natural: saco la semilla y la planto.
- **C) Zona de ox_target por campo** con la opción "Plant", que abre un menú de semillas disponibles.

> **Recomendación: B como principal y C como apoyo.** B es lo que el jugador intenta por instinto. C ayuda a descubrir la mecánica a quien nunca ha usado el script. Ambas acaban en el mismo callback `sonar_farm:plant`, así que no hay lógica duplicada.

---

## Módulo D — Alcance de esta etapa (evitar solapamiento con Etapas 5 y 6)

### 15. [CRÍTICA] ¿Barra de progreso y animaciones ahora, o en la Etapa 6?

En el orden acordado, la Etapa 5 son los minijuegos y la 6 el feedback sensorial (PTFX, sonidos 3D, animaciones). Riesgo real de tirar trabajo a la basura: si ahora construyo una barra de progreso bonita, la Etapa 5 la sustituye por un minijuego.

- **A) Acciones instantáneas.** Etapa 4 puramente visual; el tiempo de acción llega con los minijuegos.
- **B) `progressCircle` mínimo y desechable,** marcado en el código como placeholder que la Etapa 5 reemplaza.
- **C) Animaciones y PTFX completos ya.**

> **Recomendación: B.** Sin ninguna espera, la acción se siente a medio hacer y no podrás juzgar el gameplay al probarlo. Pero que sea deliberadamente pobre y esté marcado como temporal, para que nadie (yo incluido) se encariñe con código que va a morir en la etapa siguiente. **C lo descarto**: sería hacer la Etapa 6 dos veces.

### 16. ¿Blips de zona en el mapa?

- **A) No.** El jugador descubre las zonas explorando o preguntando.
- **B) Sí, configurables por zona** (activables/desactivables en `config/zones.lua`).

> **Recomendación: B con el flag por defecto activado.** Un jugador nuevo que no encuentra dónde plantar abandona la actividad. Que cada servidor decida si prefiere el descubrimiento orgánico.

---

## Módulo E — Robustez y casos borde

### 17. Alguien cosecha una planta que yo tengo en pantalla. ¿Qué pasa?

Con deltas por celda (pregunta 1) llega el borrado y el prop desaparece. La pregunta es qué ocurre si el delta **se pierde**.

- **A) Confiar en el delta.** Si se pierde, queda un prop fantasma interactuable para siempre.
- **B) Delta + reconciliación perezosa:** al fallar una acción con `crop_not_found`, el cliente limpia ese prop y refresca su celda.

> **Recomendación: B.** Los rechazos del servidor ya son una señal gratuita de desincronización; aprovecharla cuesta muy poco y evita el prop fantasma, que es el bug que los jugadores reportan como "el script está roto".

### 18. ¿Limpieza de entidades al parar el recurso?

- **A) Confiar en que FiveM limpie.**
- **B) `onResourceStop` en el cliente destruye todos los props creados.**

> **Recomendación: B, obligatorio.** Sin esto, cada `restart sonar_farm` durante el desarrollo deja props huérfanos que nadie puede borrar y que se van acumulando hasta que el jugador reconecta. Lo sufriríamos nosotros mismos veinte veces al día.

### 19. ¿Interiores y routing buckets?

- **A) Ignorarlo:** renderizar siempre.
- **B) No renderizar** si el jugador está en un interior o en un bucket distinto de 0.

> **Recomendación: B en su versión simple** (comprobar el bucket). Evita el caso absurdo de ver plantas de Grapeseed desde dentro de un apartamento.

### 20. ¿Refresco tras un rechazo del servidor?

Ligada a la 2 y la 17: si el cliente predice el crecimiento y se equivoca (reloj desfasado, delta perdido), el servidor rechaza con `crop_not_mature`.

- **A) Solo mostrar el mensaje.**
- **B) Mostrar el mensaje y refrescar la celda** para corregir la predicción.

> **Recomendación: B.** Convierte cada rechazo en una autocorrección. Es lo que hace que la predicción del cliente sea segura: si se desvía, el primer intento fallido la vuelve a alinear.

---

## Módulo F — Rendimiento

### 21. ¿Presupuesto de coste en cliente que consideras aceptable?

- **A) Estricto:** `0.00 ms` fuera de zona, `< 0.05 ms` dentro.
- **B) Holgado:** `< 0.10 ms` dentro de zona, priorizando fluidez visual.

> **Recomendación: A**, con un bucle único de intervalo adaptativo (espera larga cuando no hay cultivos cerca, corta cuando sí) en lugar de varios hilos sueltos. Un solo hilo es medible y depurable; cinco hilos con `Wait(0)` escondidos son cómo un script llega a 1 ms sin que nadie sepa qué lo causó.

### 22. Deuda técnica declarada: ¿la pagamos en esta etapa?

`Validation.CropLimit` recorre **todos** los cultivos para contar los de un jugador. Hoy es irrelevante y solo corre al plantar, pero es O(n) sobre el estado completo.

- **A) Dejarlo.** Con volúmenes de PoC no se nota.
- **B) Añadir un índice por propietario en `State`** ahora, aprovechando que esta etapa ya toca el indexado espacial.

> **Recomendación: B.** El coste es una tabla más en `State` mantenida en `Add`/`Remove`, y ya vamos a estar trabajando dentro de ese fichero. Pagarlo ahora es media hora; pagarlo cuando el servidor tenga 5000 cultivos es una sesión de perfilado.

---

## Módulo G — Preparar el futuro sin sobreingeniería

### 23. ¿El renderizador es "de cultivos" o genérico?

En la Etapa 9 llegan maquinaria y parcelas privadas, que también necesitan props con streaming y culling.

- **A) Específico de cultivos.** Más simple ahora; se duplicará después.
- **B) Un pool genérico de entidades** (clave, modelo, posición, radio) con los cultivos como primer consumidor.

> **Recomendación: B, pero sin inventar nada más.** Un pool que gestione crear, destruir y contar entidades por clave no es sobreingeniería: es exactamente lo que necesita la propia Etapa 4, y resulta que además sirve para maquinaria. Lo que **no** voy a hacer es un sistema de plugins visuales para necesidades que aún no existen.

---

## Resumen de lo crítico

Si solo quieres responder cinco cosas, que sean estas:

1. **Pregunta 1** — protocolo de sincronización (recomiendo snapshot + deltas por celda).
2. **Pregunta 2** — el cliente deriva el crecimiento de timestamps en lugar de recibir estado refrescado. Es la decisión de la que depende que esto escale.
3. **Pregunta 5** — props: ¿vanilla o tienes modelos custom?
4. **Pregunta 10** — la interacción se ancla al prop con `AddLocalEntity`.
5. **Pregunta 15** — alcance: nada de PTFX ni animaciones todavía, solo un placeholder de progreso.
