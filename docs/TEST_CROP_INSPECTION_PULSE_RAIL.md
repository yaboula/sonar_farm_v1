# Prueba in-game — Crop Inspection Pulse Rail

Esta guía valida el HUD con datos y condiciones reales de FiveM. El objetivo no
es juzgar únicamente la imagen: hay que comprobar autoridad, evolución temporal,
cierre, convivencia NUI y coste en runtime.

## 1. Preparación

En el VPS, después del `git pull`:

```bash
cd inspection-ui
npm ci
npm run build
cd ../minigames-ui
npm ci
npm run build
cd ../web
npm ci
npm run build
```

Confirma estos valores y reinicia `sonar_farm`:

```lua
Config.Features.InspectionHud = true
Config.Features.AdvancedCare = true
Config.Inspection.CloseDistance = 4.0
```

No cambies la ventana máxima de 10 minutos de historial para la aceptación final. Para
probar una expiración rápidamente sí puedes reducir temporalmente la duración de
una protección en el catálogo de un entorno de pruebas.

## 2. Apertura y autoridad

1. Acércate a un cultivo y usa `ox_target → Inspect`.
2. Comprueba que aparece el rail y no una notificación genérica.
3. Verifica que puedes caminar, mover cámara, apuntar y combatir: el HUD no debe
   capturar ratón ni teclado.
4. Pulsa Backspace; debe cerrar.
5. Inspecciona dos veces el mismo cultivo; la segunda inspección debe cerrar.
6. Intenta ejecutar el callback con un `cropId` inexistente, desde más de 4 m y
   en otro routing bucket. Debe rechazar sin mostrar datos.

Resultado esperado: el cliente solo envía `cropId`; no puede elegir métricas,
coordenadas, timestamps, efectos ni ownership.

## 3. Contenido obligatorio

En un tomate en crecimiento confirma:

- Crop, fase data-driven y slot correctos.
- Growth y Health coinciden con la inspección/estado autoritativo.
- Water, Nutrients, Weeds y Pests tienen valor, estado y curva.
- Línea histórica sólida que termina exactamente en NOW, sin proyección futura.
- `LAST CARE`, hora del servidor y ETA/hora de maduración visibles.
- Field Guide rotativa, informativa y sin botón ni chevron.
- La barra empieza después del minimapa y termina dentro del safe-zone.

Repite con Carrot, Potato y Lettuce. Si desactivas Weeds o Pests para uno en
config, su columna debe permanecer y mostrar `0% · UNAFFECTED`; no debe aparecer
estado persistente nuevo en DB.

## 4. Actualización por cuidados

Mantén abierto Inspect y realiza cada acción mediante `ox_target`:

1. Water: el valor y la curva deben cambiar tras el delta, sin reabrir el HUD.
2. Fertilize Basic/Plus/Pro: valor inmediato, tier y tiempo restante correctos.
3. Weed Basic/Plus/Pro: reducción según herramienta y nuevo diagnóstico.
4. Treat Pests Basic/Plus/Pro: reducción inmediata, tier y vencimiento correctos.

El valor/contador debe avanzar cada segundo. La curva se reconstruye al recibir
el delta y después como máximo cada cinco segundos. Un Basic reaplicado sobre un
Pro puede aplicar su efecto inmediato, pero no debe degradar el residual Pro de
mayor `strength × horas restantes`.

## 5. Cruce de expiración

1. Aplica una protección corta en el entorno de prueba.
2. Mantén el HUD abierto antes, durante y después del vencimiento.
3. El tiempo restante debe mostrarse debajo de la métrica correspondiente.
4. Al cruzarlo, desaparece el tiempo restante y el historial posterior refleja la
   trayectoria sin protección.
5. Confirma que estrés o daño histórico no se reduce al expirar/reaplicar.

## 6. Estados especiales

- Plantación interrumpida: muestra progreso y `RESUME OR CLEAR PLOT`.
- Maduro: muestra READY/READY SINCE, spoilage y `HARVEST`.
- Muerto: causa dominante histórica y `CLEAR PLOT`.
- `AdvancedCare = false`: Growth, Health y Water siguen reales; Nutrients,
  Weeds y Pests muestran `UNAFFECTED`.
- Crecimiento bloqueado: sin ETA dentro del límite, muestra `GROWTH STALLED`.

## 7. Cierre y exclusión NUI

Con el HUD abierto valida cada cierre por separado:

- alejarse más de 4 m;
- eliminar/cosechar el cultivo;
- morir;
- ejecutar reset/resync;
- abrir Business Hub;
- abrir/reanudar minijuego;
- `restart sonar_farm`.

No debe quedar un iframe visible, foco retenido ni HUD huérfano tras ningún caso.

## 8. Resoluciones y rendimiento

Prueba 1280×720, 1920×1080 y ultrawide:

- nunca cubre el radar;
- ninguna columna se superpone o sale del viewport;
- métricas, diagnóstico y referencia temporal siguen legibles;
- el crop asset conserva proporción y nitidez.

Con `resmon 1` registra:

- HUD cerrado: `sonar_farm` debe estabilizarse en 0.00 ms y no emitir tráfico
  periódico de inspección.
- HUD abierto: solo existe evaluación local; el callback de inspección ocurre una
  vez por apertura y no cada segundo.

## 9. Criterio de aceptación

La prueba queda aprobada únicamente si todos los apartados pasan, no hay errores
NUI/cliente/servidor y el rail nunca invade el minimapa. Adjunta capturas de las
tres resoluciones y un fragmento de resmon cerrado/abierto al resultado E2E.
