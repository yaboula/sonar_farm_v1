# Simulación Agrícola Proporcional al Ciclo V2

## Objetivo

La biología de un cultivo se expresa como fracción de su ciclo. Un tomate de
40 minutos y otro de 6 horas alcanzan el mismo agua, nutrientes, maleza, plagas,
daño, progreso, calidad y producción al mismo porcentaje si reciben cuidados
equivalentes.

`Config.Crops.<crop>.growthTime` es el único valor que debe cambiarse para
alargar o acortar el ciclo. No se escalan cooldowns, minijuegos, sesiones NUI,
pedidos, delivery, restock, animaciones ni refrescos de interfaz.

## Autoridad y compatibilidad

- `shared/crop_clock.lua` es la autoridad de segundos reales, fracción de ciclo
  y vencimientos residuales.
- Toda plantación nueva guarda `simulationVersion = 2` y
  `growthAdjustmentRatio` dentro del JSON `data`.
- Los cultivos anteriores, sin `simulationVersion`, continúan íntegramente en
  V1 hasta cosecharse o limpiarse.
- `Config.Farming.NewCropSimulationVersion = 1` solo afecta nuevas
  plantaciones; nunca reinterpreta registros existentes.
- El tiempo se deriva de timestamps, por lo que avanza con el propietario
  desconectado y durante reinicios sin workers agrícolas permanentes.

## Reloj y bandas

Una fracción real se obtiene con `(to - from) / growth_time`. El evaluador divide
un intervalo al cruzar vencimientos, aparición de plagas, límites de bandas,
saturaciones y ventanas críticas.

- Water: Green `>=60`, Watch `35..59`, Critical `<35`.
- Nutrients: Green dentro del rango del cultivo, Watch hasta 20 puntos fuera,
  Critical más allá.
- Weeds/Pests: Green `<=20`, Watch `21..50`, Critical `>50`.
- Growth: Green `+20 %`, Watch `-10 %`, Critical `-55 %`.

Los nutrientes iniciales son el centro del rango óptimo del cultivo. Las tasas
`cycle` en `config/crops.lua` son cantidades por ciclo completo, nunca por hora.

## Materiales

Los items conservan precio, peso y durabilidad. `protectionCycleRatio` define la
cobertura residual: Basic 6 %, Plus 18 % y Pro 40 % del ciclo para consumibles;
las herramientas Basic no tienen residual. El servidor convierte esa cobertura
a un `protectionUntil` real usando el `growth_time` almacenado del cultivo.

El menú de cuidado muestra tanto el porcentaje como la duración concreta para
el cultivo seleccionado. Supplies muestra el porcentaje porque aún no existe un
cultivo concreto durante la compra.

## Inspección

- Historial visible: 25 % del ciclo, limitado por `plantedAt` y `lastCare`.
- Diagnóstico interno sin cuidado: 10 % del ciclo.
- ETA: búsqueda de hasta cuatro ciclos.
- Las curvas terminan en `NOW`; el diagnóstico futuro no genera proyección
  visual.
- Los timers y refrescos de UI continúan en tiempo real.

## Calibración sin cuidados

Las pruebas deterministas bloquean estas ventanas de muerte:

- Lettuce: 25–35 %.
- Tomato: 32–40 %.
- Carrot: 50–58 %.
- Potato: 58–65 %.

Ningún cultivo abandonado puede madurar. Un cultivo siempre Green madura cerca
del 83,3 %. Un perfil Watch controlado madura entre 100–125 % y reduce calidad y
producción a sus bandas de diseño.

## Prueba local

```text
lua tests/run.lua
lua scripts/generate_items.lua --check
```

## Prueba E2E en FiveM

1. Activa `Config.Debug = true` y concede `sonar_farm.admin`.
2. Crea dos cultivos iguales con ciclos distintos:
   `/farm_debug_plant tomato 2400` y `/farm_debug_plant tomato 21600`.
3. Aplica los mismos cuidados a porcentajes equivalentes del ciclo.
4. Usa `/farm_debug_grow <id>` y la inspección para comparar estado.
5. Guarda, reinicia `sonar_farm` durante una protección y vuelve a inspeccionar.
6. Verifica que el vencimiento conserva el mismo porcentaje restante y que
   pedidos, Warehouse, cooldowns y minijuegos no han cambiado de duración.

Para acelerar una prueba no se editan tasas agrícolas: se cambia únicamente
`growthTime` o se usa el segundo argumento de `/farm_debug_plant`.
