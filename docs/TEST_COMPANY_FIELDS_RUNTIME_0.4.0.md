# Pruebas reales — Company Fields, Work y Land Runtime 0.4.0

Esta guía prueba el módulo por fases y evita activar toda la autoridad de golpe.
Haz una copia de la base de datos antes de empezar y usa un servidor de staging.

## 1. Preparación

1. Haz `git pull` de la rama publicada.
2. Conserva una copia de tu `config/config.lua` privado si tiene coordenadas
   propias.
3. Compila o verifica que el release contiene:
   - `web/build`
   - `minigames-ui/dist`
   - `inspection-ui/dist`
4. Arranca en este orden: `oxmysql`, framework, `ox_lib`, `ox_inventory`,
   `ox_target`, `sonar_farm`.
5. Confirma en consola: `State engine ready` y ausencia de `Fields schema ... failed`.

ACE necesario:

```cfg
add_ace group.admin sonar_farm.company_admin allow
add_ace group.admin sonar_farm.fields_admin allow
add_ace group.admin sonar_farm.admin allow
```

Valores iniciales seguros:

```lua
Config.Features.Fields = true
Config.Features.CompanyFieldAuthority = false
Config.Features.Work = false
Config.Features.PublicContracts = false
Config.Features.CompanyCargo = false
Config.Features.BuyerOrders = false
```

Con esos valores se prueba catálogo, propiedad, mapa y Land. El gameplay actual
continúa funcionando sin exigir Company/Plan/Work.

## 2. Smoke test de base de datos

Ejecuta en MySQL:

```sql
SELECT id, active_revision_id, starter_eligible, starter_priority
FROM sf_fields ORDER BY starter_priority, id;

SELECT field_id, revision_number, checksum, status
FROM sf_field_revisions ORDER BY field_id, revision_number;

SELECT field_id, COUNT(*) AS slots
FROM sf_field_slots GROUP BY field_id ORDER BY field_id;
```

Resultado esperado:

- `grapeseed_east`: 40 Slots.
- `grapeseed_south`: 24 Slots.
- `zone1`: 24 Slots, oculto del catálogo comercial.
- Una única revisión `active` por Field.

Reinicia `sonar_farm` dos veces. No deben aparecer Fields, revisiones, Rows ni
Slots duplicados. Si cambias geometría en `data/fields.lua`, el reinicio debe
crear una revisión `draft`; no debe cambiar la activa automáticamente.

## 3. Starter Field y dos empresas

Usa dos personajes sin Company. Cada futuro Owner ejecuta:

```text
/farmcompany bootstrap Nombre de Empresa
```

Comprueba:

```sql
SELECT c.name, cf.field_id, cf.acquisition_kind, cf.price_cents
FROM sf_company_fields cf JOIN sf_companies c ON c.id=cf.company_id;
```

- Cada empresa recibe un Starter Field distinto.
- `acquisition_kind = starter`, precio cero.
- Repetir el comando no crea otra empresa ni otro Field.
- Con todos los Starter Fields ocupados, un tercer bootstrap responde
  `no_starter_field` y no deja una Company incompleta.

Prueba de concurrencia: libera el staging, deja un solo Starter disponible y
ejecuta bootstrap con dos jugadores casi al mismo tiempo. Solo uno debe ganar.

## 4. Hub, Fields y Land

Abre Office y Tablet:

- El Hub abre aunque `Supplies` esté apagado.
- Fields muestra únicamente datos reales de MySQL/estado agrícola.
- Company → Land & Fields no dice “Leases” ni muestra pagos recurrentes.
- El Starter figura como propiedad permanente.
- Los Fields libres muestran precio, Rows, Slots y cultivos permitidos.
- `Route` cierra el Hub y coloca el waypoint del acceso devuelto por servidor.

En idle, con Hub cerrado y lejos de cultivos, verifica resmon: objetivo
`0.00–0.01 ms`. No debe existir tráfico periódico de Field Detail cerrado.

## 5. Preparación Manager y compra Owner

Obtén el `company_id` y añade un Manager:

```text
/farmcompany member <citizenid_manager> manager
```

1. Manager abre un Field disponible y pulsa **Prepare Purchase**.
2. No debe descontarse Treasury ni cambiar propiedad.
3. Owner abre Office físico y confirma **Purchase Field**.
4. Tablet, Warehouse u Owner lejos del Office deben ser rechazados.

Valida:

```sql
SELECT field_id, company_id, acquisition_kind, price_cents, ledger_id
FROM sf_company_fields;

SELECT entry_type, direction, amount_cents, linked_id
FROM sf_company_ledger WHERE entry_type='field_purchase';
```

Debe existir una sola propiedad y un solo débito Ledger. Repetir el mismo
`operationId` o competir con otra empresa no duplica compra ni débito.

## 6. Revisiones y builders

Activa `Config.Debug = true` solo en staging. Usa `/farm_zone` o `/farm_slots`:

- Preview antes de guardar.
- 1–20 Rows, 2–20 Slots por Row, máximo 400.
- Rechazo de IDs duplicados, coordenadas inválidas, separación insuficiente,
  solapamiento y cultivo desconocido.
- Publicar guarda `draft`; no reemplaza topología activa.

Activa una revisión libre:

```text
/farmfield activate <fieldId> <revisionId>
```

Debe fallar si hay cultivos, Plan, reserva, Work o Cargo pendiente. Al activar
una revisión válida, Field Detail debe recargar por cambio de revisión.

## 7. Work y autoridad empresarial

Activa juntos en staging:

```lua
Config.Features.Work = true
Config.Features.CompanyCargo = true
Config.Features.CompanyFieldAuthority = true
```

La autoridad solo se considera activa si los tres flags están encendidos.

1. Owner/Manager reserva Rows en un Crop Plan.
2. Sin Work vinculado, plantar debe responder `work_required`.
3. Crea Assignment para un Worker con requisito estructurado `plant`.
4. El Worker ve únicamente su Field y Rows asignados.
5. Owner tampoco puede trabajar físicamente sin Assignment propio.
6. Ejecuta Plant, Water, Fertilize, Weed, Treat y Harvest.
7. Repite/reconecta: cada resultado real incrementa progreso una sola vez.
8. Si el requisito exige Plus/Pro o threshold, una acción válida de tier bajo
   se registra en historial pero no verifica el requisito.
9. Submit solo funciona con todos los requisitos completos.
10. Supervisor/Manager aprueba; el payout aparece una vez en banco personal.

Si el proveedor bancario no confirma idempotencia, el outbox debe quedar en
`reconciliation_required`; no vuelvas a acreditar manualmente sin comparar el
journal del framework.

## 8. Public Contracts

Activa `Config.Features.PublicContracts = true`.

- Crear Contract reserva Treasury pero no concede acceso aún.
- Solo un jugador puede aceptar una oferta pública concurrentemente.
- El Contractor ve únicamente Field, Rows y acciones contratadas.
- No puede operar tras deadline, cancelación o finalización.
- Abandonar sin progreso devuelve la oferta al board.
- Cancelar antes de progreso devuelve escrow a Treasury una sola vez.
- Con progreso existente, la cancelación simple debe bloquearse para revisión.

## 9. Harvest, Company Cargo y Warehouse

Con Cargo activo:

- Harvest no entrega producto personal: metadata contiene `ownership=company`,
  `companyId`, `cargoId`, `fieldId` y Work de origen.
- Drop, transferencia, trunk y stash externos deben ser bloqueados.
- Inventario lleno conserva el cultivo.
- Solo Warehouse físico acepta depósito.
- Depósito parcial conserva el resto bajo la misma custodia.
- Los lotes separan item, quality, production y defect.

Restart crítico:

1. Reinicia antes de crear el item: cultivo permanece y reserva falla segura.
2. Reinicia después de `AddItem` y antes de finalizar: reconciliación detecta
   `cargoId`, elimina el cultivo y no vuelve a añadir producto.
3. Si faltan cultivo e item, queda `reconciliation_required`; no inventa stock.

## 10. Buyer Orders

Activa `Config.Features.BuyerOrders = true`.

- Una ventana genera una sola oferta incluso tras restart.
- Dos empresas compitiendo: solo una acepta.
- `reserve` utiliza únicamente lotes compatibles y evita doble reserva.
- Al vencer, libera reservas y marca `expired`.
- La entrega exige destino físico, consume stock reservado exacto y acredita
  Treasury/Ledger una sola vez.

## 11. Streaming y sincronización

- Acércate y aléjate de dos Fields: los Slot targets aparecen/desaparecen.
- No deben existir targets permanentes para todo el mapa.
- Abre un Field Detail: recibe solo esa suscripción.
- Una acción agrícola produce actualización inmediata.
- Cierra Hub: termina refresh y suscripción.
- Simula gap de `sequence` o nueva `topologyRevision`: la UI hace reload completo.

## 12. Checklist de salida

- [ ] Sin errores de boot/SQL.
- [ ] Import idempotente y revisiones seguras.
- [ ] Starter y compra concurrente correctos.
- [ ] Scope exacto Worker/Contractor.
- [ ] Work progresa solo con resultados verificados.
- [ ] Payout/Cargo/Buyer Order sobreviven restart sin duplicar.
- [ ] Hub real sin fixtures runtime.
- [ ] `0.00–0.01 ms` sin interacción.
- [ ] Dos jugadores concurrentes completan el E2E.
- [ ] Rollback probado volviendo `CompanyFieldAuthority = false` sin reinterpretar cultivos.

No actives Work/Cargo/Contracts/Buyer Orders en producción hasta completar sus
secciones. `Fields = true` con `CompanyFieldAuthority = false` es el rollout
inicial soportado.
