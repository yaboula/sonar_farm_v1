# Pruebas reales — Supplies Runtime, Warehouse e Items V2

Guía E2E para validar `sonar_farm` 0.3.0 dentro de un servidor FiveM real.
Está escrita para ejecutar las pruebas en orden y poder detener el rollout ante
el primer fallo importante.

## 1. Criterio de aceptación

La fase se considera aprobada únicamente si:

- el recurso arranca en estado `READY` sin errores Lua, NUI ni SQL;
- Tablet solo consulta y prepara; Office confirma; Warehouse retira y devuelve;
- Treasury es el único pagador y cada compra crea un único débito de Ledger;
- ninguna compra entrega objetos directamente al jugador;
- cada delivery llega una sola vez al Warehouse, incluso tras un reinicio;
- los objetos retirados tienen custodia empresarial y no se pueden transferir;
- herramientas, fertilizantes y tratamientos afectan realmente al cultivo;
- durabilidad, consumo, devolución y rotura coinciden entre ox_inventory y DB;
- dos jugadores concurrentes no duplican stock, dinero, pedidos ni objetos;
- no queda ningún outbox pendiente sin una causa conocida.

No activar Supplies en producción hasta completar esta guía.

## 2. Preparar el VPS

### 2.1 Actualizar la rama

Desde la carpeta del recurso:

```bash
git fetch origin
git switch codex/supplies-runtime-v2
git pull --ff-only origin codex/supplies-runtime-v2
git log -1 --oneline
```

No uses `git reset --hard` si el VPS contiene cambios locales. `git status`
debe estar limpio antes del pull o esos cambios deben guardarse primero.

### 2.2 Construir las dos interfaces

Se necesita Node.js 22:

```bash
cd web
npm ci
npm run typecheck
npm run lint
npm test
npm run build

cd ../minigames-ui
npm ci
npm run typecheck
npm run lint
npm test
npm run build
```

El resultado requerido es `web/build/` y `minigames-ui/dist/`. El único
`ui_page` es `nui-shell/index.html`.

### 2.3 Instalar items e imágenes

1. Fusiona las 21 entradas de `data/ox_inventory_items.lua` dentro de la tabla
   de `ox_inventory/data/items.lua`. No reemplaces otros items del servidor.
2. Copia los 21 PNG de `inventory_images/` a
   `ox_inventory/web/images/`. No copies `previews/`, `manifest.json` ni
   `PROMPTS.md`.
3. Reinicia `ox_inventory` después de modificar items o imágenes.
4. Comprueba que no existe ningún `unknown item` al arrancar `sonar_farm`.

Antes de subir los archivos puedes validar el origen:

```bash
lua scripts/generate_items.lua --check
python3 scripts/process_item_assets.py --check
lua scripts/check_version.lua
lua tests/run.lua
```

Resultado esperado: catálogo actual, 21 assets válidos, versión `0.3.0` y 30
pruebas Lua aprobadas.

### 2.4 Configuración temporal de prueba

En `config/config.lua`:

```lua
Config.Features.AdvancedCare = true
Config.Features.Supplies = true
```

Mantén los tiempos reales en la primera pasada:

- Basic, semillas y plantines: 5 minutos.
- Plus: 10 minutos.
- Pro: 15 minutos.

Valores importantes que deben conservarse:

- Treasury inicial: `$25,000`.
- Presupuesto mensual: `$12,000`.
- Fee: `5%`.
- Límite Procurement: `$1,500` por transacción.
- Office: `2448.38, 4977.18, 46.81`.
- Warehouse: `2441.84, 4968.77, 46.81`.
- Tablet: `/farmtablet` o `F7`.

En `server.cfg`:

```cfg
ensure oxmysql
ensure ox_lib
ensure qb-core
ensure ox_inventory
ensure ox_target

add_ace group.admin sonar_farm.admin allow
add_ace group.admin sonar_farm.company_admin allow

ensure sonar_farm
```

La base Company se crea automáticamente al arrancar. Si aparece
`company_database`, `Schema creation failed` o el runtime no llega a `READY`,
detén las pruebas y corrige primero conexión/permisos de MySQL.

## 3. Jugadores y datos necesarios

Usa dos jugadores conectados al mismo routing bucket:

- **Jugador A:** Owner y administrador ACE.
- **Jugador B:** empieza como Worker; después se prueba como Procurement.

El identificador empresarial es el `citizenid` de QB-Core, no el server ID.
Anota antes de empezar:

```text
Company ID:
CitizenID A:
CitizenID B:
Treasury inicial:
Hora de inicio:
Commit probado:
```

## 4. Bootstrap de Company y permisos

1. Jugador A ejecuta en juego:

   ```text
   /farmcompany bootstrap Sonar Test Farm
   ```

2. Debe recibir `Company ready: <uuid>`. Guarda ese UUID como `companyId`.
3. Repite el mismo comando: no debe crear una segunda empresa ni otro crédito.
4. Jugador A añade al Jugador B:

   ```text
   /farmcompany member <citizenIdB> worker
   ```

5. Comprueba en DB:

```sql
SELECT id, name, owner_identifier, treasury_cents, monthly_budget_cents
FROM sf_companies;

SELECT company_id, identifier, role_key, status
FROM sf_company_members
ORDER BY created_at;

SELECT entry_type, direction, amount_cents, balance_after_cents, idempotency_key
FROM sf_company_ledger
ORDER BY created_at;
```

Esperado: una empresa, Owner + Worker, Treasury `2500000`, presupuesto
`1200000` y un solo crédito `bootstrap` de `2500000`.

Desde consola del servidor, la sintaxis alternativa es:

```text
farmcompany member <companyId> <citizenId> <role>
farmcompany remove <companyId> <citizenId>
```

Roles válidos para miembros: `manager`, `procurement`, `supervisor`, `worker`.
El rol `owner` solo se crea mediante bootstrap.

## 5. Superficies y autoridad física

Ejecuta estas comprobaciones antes de comprar:

1. Jugador B abre Tablet con `F7` lejos de Office y Warehouse.
2. Debe ver catálogo real, precios, tier, efecto, stock, ETA y Warehouse-owned.
3. Añade un item y abre Review. Tablet debe indicar que la confirmación se
   completa en Office; no debe descontar dinero ni entregar objetos.
4. Acércate a Office y abre `Open Farm Office` mediante ox_target.
5. Aleja al jugador más de 3 metros con la UI abierta e intenta confirmar. Debe
   fallar/cerrar por presencia inválida.
6. Abre Company Warehouse desde Tablet: debe ser `Remote View` y el botón de
   retirada debe estar deshabilitado.
7. En el punto físico abre `Open Company Warehouse`: debe mostrar
   `At Warehouse`.
8. Abre el minijuego y el Hub en intentos consecutivos. Nunca deben quedar las
   dos superficies visibles ni compartir foco; `Escape` debe cerrar la activa.

## 6. Pedido completo: Worker → Owner → Office → Warehouse

### 6.1 Crear solicitud

Con Jugador B todavía como Worker:

1. Tablet → Supplies → Supply Market.
2. Añade `2 × Organic Fertilizer`.
3. Total esperado: subtotal `$70`, fee `$3.50`, total `$73.50`.
4. Pulsa `Review Purchase`.

Esperado: estado `approval_required`; Treasury e inventarios no cambian.

### 6.2 Aprobar y confirmar

1. Jugador A abre Supplies → Company Procurement.
2. Revisa la solicitud y pulsa `Approve Request`.
3. Ve físicamente a Office, abre el terminal y confirma el pedido.
4. Pulsa confirmar una segunda vez o repite rápidamente la acción.

Esperado:

- una sola orden `in_transit`;
- un solo receipt y una sola delivery;
- un solo débito de `$73.50`;
- Treasury pasa de `$25,000` a `$24,926.50`;
- ningún jugador recibe fertilizante todavía;
- ETA 5 minutos.

Consulta de control:

```sql
SELECT id, status, subtotal_cents, fee_cents, total_cents, due_at, delivered_at
FROM sf_supply_orders ORDER BY created_at DESC LIMIT 5;

SELECT order_id, status, due_at, delivered_at
FROM sf_supply_deliveries ORDER BY due_at DESC LIMIT 5;

SELECT entry_type, direction, amount_cents, balance_after_cents, linked_id
FROM sf_company_ledger ORDER BY created_at DESC LIMIT 10;
```

### 6.3 Entrega diferida

1. Antes de 5 minutos abre Warehouse: el fertilizante debe aparecer en
   `Incoming`, no en stock disponible.
2. Al superar el ETA, espera al worker de delivery o vuelve a abrir Warehouse.
3. Debe aparecer exactamente `2` en stock.
4. Reinicia `sonar_farm` y vuelve a abrir Warehouse varias veces.

Esperado: sigue habiendo exactamente `2`; no aparece un segundo receipt, lote
ni débito.

```sql
SELECT company_id, item_id, quantity
FROM sf_warehouse_lots
WHERE item_id = 'fertilizer_organic';

SELECT order_id, COUNT(*) AS deliveries
FROM sf_supply_deliveries
GROUP BY order_id HAVING COUNT(*) <> 1;
```

La segunda consulta debe devolver cero filas.

## 7. Retirada, custodia y devolución

1. Jugador B abre el Warehouse físico.
2. Selecciona Organic Fertilizer y retira `1`.
3. Confirma en ox_inventory que existe metadata:
   `ownership=company`, `companyId`, `issueId`, `itemId`.
4. Intenta tirarlo al suelo, pasarlo al otro jugador, guardarlo en stash y
   meterlo en trunk/glovebox.

Esperado: las cuatro transferencias se bloquean. Solo se permite moverlo entre
slots del inventario personal, usarlo o devolverlo en Warehouse.

5. Intenta retirar desde Tablet o lejos del Warehouse: debe fallar.
6. Con una herramienta parcialmente usada, vuelve al Warehouse físico, abre
   Supplies → Issued Materials y ejecuta `Record Return`.
7. Retira otra vez la misma herramienta.

Esperado: vuelve con exactamente la durabilidad que tenía al devolverla, no con
100%.

```sql
SELECT id, identifier, item_id, issued_units, consumed_units, returned_units,
       uses_spent, durability, status
FROM sf_material_issues
ORDER BY created_at DESC LIMIT 30;

SELECT id, item_id, durability, status, issue_id
FROM sf_warehouse_tool_units
ORDER BY created_at DESC LIMIT 30;
```

## 8. Probar los tres tiers sobre cultivos reales

Compra y entrega al menos una unidad de cada variante:

- `watering_can`, `watering_can_reinforced`, `watering_can_professional`;
- `hand_hoe`, `hand_hoe_reinforced`, `hand_hoe_professional`;
- `fertilizer_organic`, `fertilizer_balanced`, `fertilizer_chemical`;
- `pest_spray_organic`, `pest_spray_targeted`, `pest_spray_chemical`.

Se recomiendan dos pedidos: seis herramientas y seis consumibles. Cada pedido
tendrá ETA 15 minutos por contener Pro. Retira las unidades con el jugador que
hará las acciones.

### 8.1 Preparar cultivos de test

Usa al menos tres cultivos de Carrot, Potato o Lettuce. Para evitar esperar horas
en un entorno de prueba, detén el recurso, haz backup y ajusta solo los cultivos
del tester:

```sql
UPDATE farming_crops
SET data = JSON_SET(
    COALESCE(NULLIF(data, ''), '{}'),
    '$.water', 0,
    '$.nutrients', 10,
    '$.weedCover', 100,
    '$.pestPressure', 95,
    '$.lastCare', UNIX_TIMESTAMP()
)
WHERE owner = '<citizenIdTester>';
```

Después inicia `sonar_farm`. No edites DB mientras el recurso está activo porque
el estado autoritativo reside en RAM y puede sobrescribir el cambio.

### 8.2 Resultados esperados

- Regaderas: desgaste aproximado por uso `5%`, `2%`, `1%`; desaparecen tras
  20, 50 y 100 usos respectivamente y notifican `tool_broken`.
- Azadas desde weed cover 100: Basic deja `45`, Plus deja `25`, Pro deja `0`.
- Fertilizantes desde nutrientes 10: Basic deja `35`, Plus `50`, Pro `65`.
- Protección nutricional: `15%/2h`, `35%/6h`, `55%/12h`.
- Tratamientos desde pest pressure 95: Basic deja `55`, Plus `30`, Pro `5`.
- Protección de plagas: `25%/3h`, `55%/8h`, `80%/16h`.
- Cada fertilizante o tratamiento consume exactamente una unidad.
- La inspección muestra tier y tiempo de protección restante.
- Reaplicar Basic sobre una protección Pro ejecuta el efecto inmediato, pero no
  sustituye el residual Pro si su `strength × tiempo restante` sigue siendo mayor.
- El servidor selecciona primero la herramienta poseída con menor durabilidad.

Para repetir un tier con valores iniciales idénticos, usa otro cultivo o detén el
recurso, restablece ese cultivo con el SQL anterior y vuelve a arrancarlo.

## 9. Permisos y límites

Ejecuta cada caso y marca aprobado solo si no cambia Treasury, stock ni Ledger al
fallar:

- Worker/Supervisor: puede solicitar, no confirmar.
- Procurement: puede confirmar hasta `$1,500`; por encima requiere aprobación y
  confirmación final de Owner/Manager.
- Owner/Manager: puede aprobar y confirmar.
- Tablet: nunca confirma aunque el jugador sea Owner.
- Office: no retira ni devuelve material.
- Warehouse: no confirma compras.
- Draft con más de 10 líneas, más de 99 unidades o expirado: rechazado.
- Treasury insuficiente: rechazado.
- Presupuesto mensual superado: rechazado.
- Stock Plus/Pro insuficiente: rechazado.

Para probar saldo o presupuesto insuficiente sin gastar todo, guarda primero los
valores y modifícalos solo en la base de test con el recurso detenido. Restáuralos
después y documenta el cambio; no hagas esto en producción.

## 10. Concurrencia con dos jugadores

### 10.1 Stock proveedor

1. Asigna temporalmente `procurement` a dos testers autorizados.
2. Ambos crean un draft de `6 × Professional Pest Treatment`.
3. El stock Pro inicial es 10. Confirman simultáneamente desde Office.

Esperado: solo una operación reserva seis; la otra recibe `stock_changed`. El
stock nunca queda negativo y cada draft tiene como máximo una orden.

### 10.2 Warehouse

1. Ambos seleccionan la última unidad del mismo item.
2. Pulsa Withdraw simultáneamente.

Esperado: solo uno recibe el item; el lote queda en cero, nunca en `-1`, y solo
existe un issue válido para esa unidad.

### 10.3 Uso agrícola

Intenta usar el mismo `issueId` dos veces casi simultáneamente sobre cultivos
distintos. Esperado: el uso pendiente bloquea el segundo; nunca hay dos efectos
con un único decremento de durabilidad.

## 11. Reinicios y recuperación de outbox

Ejecuta por separado:

1. Confirma un pedido Basic y reinicia `sonar_farm` antes de su ETA.
2. Tras el ETA, verifica una sola entrega.
3. Durante una retirada, reinicia el recurso inmediatamente después de pulsar
   Withdraw.
4. Reconecta y abre Supplies/Warehouse para activar reconciliación lazy.
5. Repite el escenario durante una devolución y durante un uso agrícola.

Estado final válido:

- o el objeto está en Warehouse;
- o está una sola vez en el inventario con un único issue;
- o fue consumido/devuelto y la custodia está cerrada;
- nunca aparece simultáneamente en dos lugares.

```sql
SELECT id, kind, status, attempts, last_error, identifier, updated_at
FROM sf_supply_outbox
ORDER BY created_at DESC;
```

`pending`, `prepared` o `inventory_done` pueden existir brevemente durante una
operación. Tras reconectar/abrir el módulo y esperar unos segundos deben pasar a
`completed` o a `failed` con una causa segura. Un registro atascado debe guardarse
como evidencia y no borrarse manualmente.

## 12. Membresía con custodia pendiente

1. Jugador B retira un item.
2. Owner intenta `/farmcompany remove <citizenIdB>`.
3. Debe fallar mientras exista material pendiente/emitido.
4. Jugador B usa o devuelve todo el material.
5. Repite la baja; ahora debe completarse.
6. El jugador eliminado no debe poder abrir Hub ni usar material empresarial.

## 13. Evidencias y reporte de fallo

Por cada bloque conserva:

- captura o vídeo de la UI;
- hora exacta y citizenid de los jugadores;
- commit probado (`git rev-parse HEAD`);
- extracto de consola FiveM/txAdmin;
- filas relacionadas de order, delivery, ledger, issue y outbox;
- inventario antes/después con metadata y durabilidad;
- pasos exactos para reproducir.

Plantilla mínima:

```text
Caso:
Resultado esperado:
Resultado real:
Hora y zona:
Jugador/citizenid:
Order/Draft/Issue/Outbox ID:
¿Ocurre después de restart?:
¿Se reproduce 2 de 2 veces?:
Logs y capturas:
```

No reintentes ni borres filas si aparece una duplicación: conserva el estado para
diagnóstico.

## 14. Cierre y rollback

Antes de aprobar producción:

- [ ] Company bootstrap es idempotente.
- [ ] Roles y límites se comportan como se documenta.
- [ ] Tablet, Office y Warehouse respetan presencia física.
- [ ] Treasury, fee, presupuesto y Ledger cuadran al céntimo.
- [ ] Delivery Basic/Plus/Pro llega una única vez.
- [ ] Retirada, uso, rotura y devolución conservan custodia.
- [ ] Los 12 items agrícolas fueron probados sobre cultivos.
- [ ] Transferencias empresariales están bloqueadas.
- [ ] Concurrencia de dos jugadores no duplica estado.
- [ ] Reinicios de order/withdraw/return/use se reconcilian.
- [ ] Outbox no contiene operaciones atascadas.
- [ ] Consola no contiene errores Lua, NUI, ox_inventory ni oxmysql.

Si un punto falla, vuelve a:

```lua
Config.Features.Supplies = false
```

y reinicia `sonar_farm`. No es necesario borrar las tablas: mantenerlas permite
diagnosticar y reactivar la fase después de la corrección.
