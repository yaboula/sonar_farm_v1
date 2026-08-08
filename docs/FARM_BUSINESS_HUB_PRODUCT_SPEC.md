# Farm Business Hub — Product Specification

> Estado: Product Owner source of truth
>
> Audiencia: Product Designer / UX Designer
>
> Documento: español
>
> Copy canónico de UI: English
>
> Alcance: arquitectura de producto, contenido, permisos, estados y flujos
>
> Fuera de alcance: theme, colores, tipografía, componentes, layout y backend

---

## 1. Propósito

Este documento define qué debe permitir hacer el **Farm Business Hub**, qué
información necesita cada usuario y qué contenido debe existir en cada vista.

El designer decide la composición visual, navegación concreta, densidad,
jerarquía gráfica y sistema de componentes. Debe preservar:

- capacidades y restricciones;
- separación entre información pública y privada;
- disponibilidad según rol y contexto;
- acciones principales;
- estados vacíos, bloqueados, expirados y de error;
- vocabulario canónico en inglés.

No deben añadirse métricas, módulos, monedas, rankings, niveles, herramientas o
automatizaciones que no estén definidos aquí.

---

## 2. Definición del producto

### 2.1 Qué es

El **Farm Business Hub** es la interfaz operativa de la única empresa agrícola
gestionada por jugadores en el servidor.

No es un menú de pausa, una tienda aislada ni un dashboard estadístico. Es el
punto donde se entiende el estado del negocio, se prepara el trabajo, se compran
materiales, se gestionan campos, se coordina personal, se aceptan pedidos, se
controlan existencias y se administra la propiedad.

### 2.2 Cadena operativa

**Supplier → Materials → Fields → Company Cargo → Warehouse → Buyer Orders → Treasury**

La empresa puede:

- ser adquirida y revendida;
- contratar personal;
- subcontratar trabajo a visitantes;
- comprar materiales;
- operar campos iniciales o arrendados;
- producir, transportar y almacenar cultivos;
- completar pedidos;
- vender excedente a un mayorista;
- transferirse como empresa completa.

### 2.3 Objetivo por usuario

- **Visitor:** descubrir la empresa, comprar suministros personales, buscar
  contratos públicos o solicitar empleo.
- **Contractor:** completar un contrato público reservado.
- **Worker:** conocer y ejecutar su trabajo asignado.
- **Procurement:** adquirir material empresarial dentro de presupuesto.
- **Supervisor:** convertir necesidades del campo en trabajo asignado.
- **Manager:** coordinar operaciones, personal, contratos, pedidos y recursos.
- **Owner:** gobernar permisos, activos, identidad y propiedad.

### 2.4 Principios funcionales

1. **Actionable first.** Priorizar decisiones y acciones, no cifras decorativas.
2. **Permission aware.** Mostrar solo acciones ejecutables por el usuario.
3. **World presence.** Las acciones físicas ocurren en lugares de FiveM.
4. **Traceable business.** Dinero, materiales, carga y propiedad son auditables.
5. **No dead modules.** Lo futuro no aparece hasta estar operativo.
6. **Continuous history.** Cambia el Owner, no la identidad histórica.
7. **Role-specific clarity.** El detalle depende de la responsabilidad.

---

## 3. Contextos de acceso

### 3.1 Office Terminal

Acceso completo desde oficina, cooperativa, mostrador o almacén.

Requerido para:

- comprar la empresa inicialmente;
- ejecutar compras que entregan objetos;
- recoger material empresarial;
- depositar Company Cargo;
- retirar objetos del Warehouse;
- finalizar transferencias de propiedad;
- acciones ligadas a NPC, terminal o punto físico.

### 3.2 Farm Tablet

Acceso remoto sensible a permisos.

Puede permitir:

- consultar campos, cultivos, contracts, assignments y buyer orders;
- publicar o administrar trabajo;
- revisar applications;
- consultar Warehouse, Treasury y Ledger;
- aprobar procurement;
- gestionar personal y permisos;
- preparar operaciones que deban finalizar físicamente.

No sustituye la presencia física. Cuando una acción exige un lugar, debe explicar
dónde completarla.

### 3.3 Paridad

Terminal y tablet usan los mismos conceptos y reglas. Solo cambia:

- disponibilidad de acciones;
- profundidad de información;
- pasos que requieren presencia.

### 3.4 Estados de la empresa

**Sin propietario**

- ficha pública marcada **For Sale**;
- no existen Staff, Assignments ni contratos creados por management;
- el Supply Market personal puede operar como servicio externo;
- un Visitor puede evaluar y comprar la empresa.

**Operativa**

- ficha pública con identidad y oportunidades;
- Job Applications configurables;
- staff autorizado publica trabajo;
- miembros acceden a información privada.

**En venta**

- sigue siendo la misma empresa;
- se muestran listing, activos y obligaciones;
- la operación continúa salvo durante el cierre atómico.

---

## 4. Actores y permisos

Los roles base incluyen permisos iniciales editables por el Owner. No pueden
desactivarse protecciones de propiedad, escrow, auditoría o separación de fondos.

### 4.1 Visitor

Puede:

- ver Company Profile y Business for Sale;
- comprar con fondos personales;
- ver y aceptar Public Contracts;
- enviar Job Application.

No puede:

- ver finanzas internas;
- operar cultivos fuera de un contrato;
- usar fondos empresariales;
- entrar al Warehouse;
- ver Staff o permisos.

### 4.2 Contractor

Es un Visitor con un Public Contract activo.

Puede:

- ver objetivo, campo, plazo, reward y progreso;
- operar únicamente el ámbito del contrato;
- completar o abandonar según sus reglas.

El Contractor aporta sus materiales.

### 4.3 Worker

Puede:

- consultar Today, Fields y sus Assignments;
- ejecutar trabajo autorizado;
- transportar y depositar Company Cargo;
- comprar personalmente;
- usar materiales empresariales emitidos.

No puede crear contratos, cambiar permisos o gastar fondos de empresa sin
permisos adicionales.

### 4.4 Procurement

Además de Worker, puede:

- comprar categorías autorizadas con fondos empresariales;
- gastar dentro de límites;
- revisar compras y materiales emitidos;
- devolver material cuando proceda.

No puede cambiar su propio presupuesto ni borrar transacciones.

### 4.5 Supervisor

Puede:

- revisar necesidades de campos;
- crear Assignments mediante plantillas;
- asignar Workers;
- seguir progreso;
- resolver excepciones permitidas;
- proponer Public Contracts si tiene permiso.

### 4.6 Manager

Puede, según permisos:

- publicar contratos;
- gestionar Buyer Orders;
- revisar Applications y contratar;
- administrar Assignments;
- consultar Warehouse, Treasury, Leases y Ledger;
- aprobar Procurement;
- operar remotamente desde tablet.

No puede vender la empresa, transferirla o quitar al Owner.

### 4.7 Owner

Puede:

- realizar toda la gestión;
- configurar roles y budgets;
- cambiar el nombre con coste y cooldown;
- contratar o despedir management;
- publicar la empresa para venta;
- completar transferencia de propiedad.

Solo existe un Owner.

### 4.8 Former Owner

Tras una venta:

- pierde Owner;
- sale de la empresa;
- no conserva permisos;
- puede volver a solicitar empleo como Visitor.

### 4.9 Distinciones obligatorias

- Contractor ejecuta **Public Contract**.
- Worker ejecuta **Assignment**.
- Contractor cobra del contract escrow.
- Worker cobra assignment pay reservado.
- Contractor usa materiales propios.
- Worker puede recibir material de empresa.

---

## 5. Arquitectura de navegación

Áreas principales:

- **Today**
- **Fields**
- **Work**
- **Supplies**
- **Company**

El patrón visual es decisión del designer.

### Today

Responde: **What needs my attention now?**

Prioriza:

1. trabajo actual;
2. cargo pendiente;
3. campo/cultivo atendible;
4. deadline relacionado;
5. aprobación pendiente;
6. siguiente trabajo.

No debe ser un grupo de KPIs.

### Fields

Contiene campos, leases, cultivos, capacidad, condición, trabajo y restricciones.

### Work

Agrupa:

- Public Contracts;
- Active Contract;
- Assignments;
- Buyer Orders relacionados con trabajo;
- historial operativo necesario.

### Supplies

Agrupa:

- Supply Market;
- Personal Purchase;
- Company Procurement;
- Purchase Review;
- Issued Materials;
- supplier stock.

### Company

Agrupa:

- Company Profile;
- Staff y Applications;
- Warehouse;
- Treasury y Transaction Ledger;
- Leases;
- Roles & Permissions;
- Company Identity;
- Business Sale.

### Navegación dinámica

- Una función futura se oculta.
- Una sección no autorizada no promete acciones bloqueadas.
- Perder permisos convierte la ruta abierta en Restricted.
- Cambiar de rol refresca navegación y datos privados.

### Navegación visible por actor

**Visitor**

- Company: Company Profile, Business for Sale, Job Application.
- Work: Public Contracts.
- Supplies: Supply Market con Personal Purchase.
- No ve Fields ni información empresarial privada.

**Contractor**

- Today: resumen de Active Contract.
- Work: Active Contract, Contract Progress y Completion.
- Supplies: Supply Market personal.
- Company: ficha pública.
- Fields solo muestra la ubicación autorizada por su contrato.

**Worker**

- Today, Fields, Work, Supplies y Company.
- Work contiene únicamente sus Assignments.
- Company se limita a información interna básica y Company Cargo.

**Procurement**

- Mantiene navegación de Worker.
- Supplies añade Company Procurement e Issued Materials.
- Company añade el ámbito de Transaction Ledger necesario para sus compras.

**Supervisor**

- Mantiene las cinco áreas.
- Fields y Work añaden creación/seguimiento de Assignments.
- Solo ve finanzas ligadas al trabajo que puede crear.

**Manager**

- Acceso operativo a las cinco áreas.
- Work añade Buyer Orders y Public Contract Management.
- Company añade Staff, Applications, Warehouse, Procurement, Treasury, Ledger y
  Leases según permisos.

**Owner**

- Acceso a todas las áreas.
- Company añade Roles & Permissions, Company Identity y Business Sale.

---

## 6. Reglas globales de UX

### Acción principal

Cada vista tiene una acción principal inequívoca. Las secundarias no compiten.

### Confirmaciones obligatorias

Confirmar explícitamente:

- gastar fondos;
- publicar/cancelar contrato;
- contratar/despedir;
- cambiar permisos;
- abandonar trabajo;
- vender stock;
- terminar lease;
- publicar/retirar/comprar Business Sale;
- transferir propiedad.

La confirmación explica el efecto, no solo **Are you sure?**

### Dinero

Mostrar siempre:

- quién paga;
- cuenta usada;
- importe y fees;
- saldo posterior;
- si queda en escrow o se ejecuta.

### Objetos

Distinguir:

- personal material;
- company-owned material;
- Company Cargo;
- Warehouse stock;
- supplier stock;
- reserved stock.

### Plazos

Mostrar fecha, hora local, tiempo restante cuando sea útil y estado Expired.

### Permisos

Restricted debe indicar permiso requerido y quién puede resolverlo.

### Cierre

Al cerrar la NUI:

- no se ejecuta lo no confirmado;
- drafts persistentes conservan su estado;
- operaciones en curso explican si terminaron;
- el foco vuelve al juego.

---

## 7. Contrato de contenido por vista

Todas las vistas deben definir:

- propósito;
- usuarios;
- Office/Tablet;
- datos obligatorios;
- acción principal;
- acciones secundarias;
- estados;
- restricciones.

Las siguientes secciones son el contrato mínimo.

---

## 8. Vistas públicas

### 8.1 Company Profile

**Propósito:** presentar la empresa y los caminos públicos.

**Usuarios:** Visitor, Contractor y miembros consultando la ficha pública.

**Office/Tablet:** ambos.

**Contenido obligatorio**

- company name;
- ownership status;
- Open / For Sale / Temporarily Unavailable;
- descripción breve;
- campos expresados de forma pública;
- oportunidades públicas;
- Job Applications status;
- office location;
- condiciones generales para contractors.

**Acción principal**

- **View Public Contracts** si opera.
- **View Business Sale** si está For Sale.

**Secundarias**

- **Apply for a Job**
- **Open Supply Market**
- **Set Route to Office**

**Estados:** For Sale, operating, no contracts, applications closed, unavailable.

**Restricción:** no mostrar Treasury, stock exacto, miembros, margins o Buyer
Orders privados.

### 8.2 Business for Sale

**Propósito:** evaluar y comprar la empresa.

**Usuarios:** Visitor comprador y Owner vendedor para revisión.

**Office/Tablet:** consulta en tablet; compra final en terminal/registry.

**Contenido obligatorio**

- Initial Sale u Owner Listing;
- asking price;
- personal payment source;
- company name;
- Treasury incluido;
- Warehouse valuation;
- active leases;
- employee count;
- active Buyer Orders;
- contracts y escrow comprometido;
- obligaciones;
- fees;
- qué se transfiere.

**Principal:** **Buy Business**

**Secundarias:** **Review Assets**, **Review Obligations**, **Set Route to Registry**

**Estados:** available, insufficient funds, pending, listing changed, sold,
ineligible, unavailable.

**Restricciones:** compra personal, revalidación final y exclusión mutua entre
compradores.

### 8.3 Public Contracts

**Propósito:** descubrir trabajo subcontratado.

**Usuarios:** Visitor y Contractor.

**Office/Tablet:** ambos.

**Cada contrato muestra**

- title y type;
- crop;
- field/location;
- quantity;
- minimum quality si aplica;
- deadline;
- reward;
- required materials;
- contractor-provided materials;
- availability.

**Principal:** **View Contract**

**Estados:** available, empty, all reserved, loading, unavailable.

**Restricción:** no mostrar drafts, costes internos o identidad de otros
contractors.

### 8.4 Public Contract Detail

**Propósito:** evaluar y reservar un contrato.

**Contenido obligatorio**

- objetivo y pasos verificables;
- location y field access;
- materials checklist e inventory readiness;
- deadline;
- reward y escrow status;
- failure/cancellation rules;
- cargo ownership;
- completion destination.

**Principal:** **Accept Contract**

**Secundarias:** **Set Route**, **Open Supply Market**, **Back to Contracts**

**Estados:** available, reserved, expired, missing materials, active-contract
limit, field unavailable, escrow unavailable.

### 8.5 Job Application

**Propósito:** solicitar empleo de forma persistente.

**Contenido de formulario**

- character identity;
- short introduction;
- availability note;
- preferred work type;
- company rules acknowledgement.

**Contenido de estado**

- submitted date;
- last update;
- application status;
- withdraw option.

**Principal:** **Submit Application**

**Secundarias:** **Save Draft**, **Withdraw Application**

**Estados:** none, draft, submitted, under review, accepted, rejected, closed.

**Restricción:** una activa por personaje; no inventar CV, levels o certificates.

### 8.6 Supply Market — Public

**Propósito:** comprar materiales con fondos personales.

**Usuarios:** Visitor, Contractor y miembros.

**Office/Tablet:** catálogo remoto; compra final física.

**Catálogo inicial**

- planting materials funcionales;
- Watering Can;
- consumibles activos;
- categorías futuras ocultas.

**Cada producto muestra**

- item name;
- crop relation;
- unit price;
- Personal payer;
- owned quantity;
- supplier stock;
- restock si aplica;
- availability;
- quantity.

**Principal:** **Review Purchase**

**Estados:** available, sold out, restocking, insufficient personal funds,
inventory warning, unavailable.

**Restricción:** no usa Treasury ni company ownership.

---

## 9. Vistas de Contractor

Salvo que una vista indique lo contrario:

- usuario: Contractor;
- disponible en Office Terminal y Farm Tablet;
- los estados globales Loading, Restricted, Unavailable y Connection Lost
  también aplican.

### 9.1 Active Contract

**Propósito:** ser el punto de retorno mientras el contrato está activo.

**Office/Tablet:** ambos.

**Contenido obligatorio**

- title y current objective;
- completed/remaining requirements;
- location y deadline;
- reward in escrow;
- materials readiness;
- cargo status;
- blockers;
- next valid action.

**Principal según el paso**

- **Set Route to Field**
- **Open Supply Market**
- **Set Route to Delivery**
- **Submit Contract**

**Secundarias:** **View Full Terms**, **Abandon Contract**

**Estados:** active, waiting for location, in progress, ready to submit, blocked,
expired, failed, completed.

### 9.2 Contract Progress

**Propósito:** explicar qué contribución ha sido reconocida.

**Contenido obligatorio**

- required operations;
- verified operations;
- rejected operations con razón;
- quantity/quality progress;
- cargo held;
- remaining time;
- next location.

**Principal:** **Continue Contract**

**Restricción:** no reducir distintos requisitos a una barra genérica.

### 9.3 Contract Completion

**Propósito:** cerrar el trabajo y explicar el resultado.

**Contenido obligatorio**

- result;
- delivered quantity;
- accepted quality;
- base reward;
- adjustments y penalties;
- final payout y destination;
- escrow resolution;
- cargo/material resolution.

**Principal:** **Collect Payment** cuando sea físico, o **Close** si es automático.

**Estados:** successful, partially accepted si la plantilla lo permite, failed,
payout pending, paid, account issue.

---

## 10. Vistas de operación interna

Salvo que una vista indique lo contrario:

- usuarios: Worker y roles superiores dentro de su ámbito;
- disponible en Office Terminal y Farm Tablet;
- las acciones de inventario, cargo o ubicación mantienen requisitos físicos;
- los estados globales también aplican.

### 10.1 Today

**Propósito:** responder **What needs my attention now?**

**Usuarios:** todos los miembros, con contenido según role.

**Office/Tablet:** ambos.

**Prioridad**

1. active Assignment;
2. Company Cargo pendiente;
3. field/crop atendible;
4. Buyer Order deadline relacionado;
5. approval o exception pendiente;
6. next work.

**Principal:** abrir o continuar la prioridad número uno.

**Estados:** active priority, no assigned work, waiting approval, blocked by
supplies, field unavailable, service unavailable.

**Restricción:** no añadir KPIs sin decisión asociada.

### 10.2 Fields

**Propósito:** mostrar dónde puede operar la empresa y dónde existe trabajo.

**Usuarios:** Worker, Supervisor, Manager y Owner.

**Office/Tablet:** ambos.

**Cada campo muestra**

- field name;
- ownership/lease status;
- lease expiration;
- operational status;
- occupied/available capacity;
- crop summary;
- attention summary;
- active Assignments;
- restrictions.

**Principal:** **View Field**

**Estados:** active, Grace Period, planting suspended, lease expired, no access,
empty, unavailable.

### 10.3 Field Detail

**Propósito:** entender la situación del campo y crear o ejecutar trabajo.

**Contenido obligatorio**

- identity y location;
- Lease status;
- rows/slots;
- crop list;
- growth, water, health y readiness;
- attention requirements;
- linked Assignments, Public Contracts y Buyer Orders;
- access restrictions.

**Principal por role**

- Worker: **Open Assignment** o **Set Route**
- Supervisor: **Create Assignment**
- Manager: **Manage Operations**

**Secundarias:** **Filter Crops**, **View Lease**, **View Work History**

**Estados:** empty, active crops, urgent attention, planting suspended, grace,
inaccessible.

### 10.4 Assignments

**Propósito:** organizar trabajo interno remunerado.

**Usuarios:** Workers ven las suyas; management ve su ámbito.

**Office/Tablet:** ambos.

**Cada Assignment muestra**

- title;
- assignee;
- work type;
- crop y field;
- objective;
- deadline;
- reserved pay;
- status;
- blocker;
- verified progress.

**Principal**

- Worker: **View Assignment**
- Supervisor: **Create Assignment**

**Estados:** open, assigned, accepted, in progress, blocked, completed, failed,
expired, cancelled.

### 10.5 Assignment Detail

**Propósito:** definir trabajo y pago sin ambigüedad.

**Contenido obligatorio**

- template y objective;
- assignee;
- location;
- issued materials;
- verified requirements;
- deadline;
- reserved pay;
- payout conditions;
- progress history;
- cancellation rules.

**Principal por estado:** **Accept Assignment**, **Continue Assignment**,
**Submit Assignment** o **Review Result**.

**Management:** **Reassign**, **Cancel Assignment**, **Resolve Blocker**

**Restricción:** pago por resultado validado, nunca por tiempo online.

### 10.6 Company Cargo

**Propósito:** explicar qué inventario pertenece a la empresa y dónde depositarlo.

**Usuarios:** miembros y Contractor cuando proceda.

**Office/Tablet:** consulta en ambos; depósito en Warehouse físico.

**Contenido obligatorio**

- cargo items y quantities;
- quality metadata;
- source field/action;
- company ownership;
- linked Assignment/Order/Contract;
- destination;
- status;
- transfer restrictions.

**Principal:** **Set Route to Warehouse**

**Estados:** carrying, partial deposit, ready, completed, mismatch, unauthorized
transfer.

### 10.7 Supply Market — Member

Mantiene el catálogo público y añade, si existe permiso:

- **Personal Purchase**
- **Company Procurement**

Cambiar payer debe actualizar claramente:

- cuenta pagadora;
- límites;
- ownership final;
- auditoría;
- transfer restrictions.

### 10.8 Purchase Review

**Propósito:** confirmar una compra antes de mover dinero u objetos.

**Contenido obligatorio**

- items, quantities y unit prices;
- subtotal y fees;
- payer Personal o Company;
- current/projected balance;
- budget impact;
- ownership posterior;
- inventory capacity;
- fulfillment location.

**Principal:** **Confirm Purchase**

**Estados:** ready, insufficient funds, budget exceeded, permission required,
stock changed, inventory full, processing, completed, failed.

---

## 11. Vistas de gestión

Salvo que una vista indique lo contrario:

- usuarios: Supervisor, Manager y Owner según permisos;
- disponible en Office Terminal y Farm Tablet;
- retirar/depositar objetos y cerrar transferencias físicas requiere presencia;
- los estados globales también aplican.

### 11.1 Buyer Orders

**Propósito:** mostrar demanda externa que genera ingresos.

**Usuarios:** Manager y Owner; Worker solo ve orders ligados a su trabajo.

**Office/Tablet:** ambos.

**Tipos**

- NPC/system buyer;
- future external business;
- fallback wholesaler como canal separado.

**Cada Order muestra**

- buyer y source type;
- products, quantity y minimum quality;
- deadline;
- gross payment;
- escrow/funding;
- reserved stock;
- fulfillment progress;
- status.

**Principal:** **View Order**

**Estados:** offered, accepted, in progress, ready to deliver, completed, failed,
expired, cancelled.

### 11.2 Buyer Order Detail

**Propósito:** decidir si aceptar y cómo cumplir.

**Contenido obligatorio**

- buyer identity;
- requested lines;
- quality rules;
- deadline y payment;
- buyer escrow;
- Warehouse availability;
- shortage;
- linked Fields y Assignments;
- delivery destination;
- failure/cancellation effects.

**Principal:** **Accept Order**, **Plan Fulfillment**, **Prepare Delivery** o
**Complete Delivery**.

**Secundarias:** **Create Assignment**, **Reserve Stock**, **Reject Order**

### 11.3 Public Contract Management

**Propósito:** administrar trabajo externo.

**Contenido obligatorio**

- drafts, published, reserved, active, completed, failed y expired;
- escrow;
- Contractor;
- linked field/order.

**Principal:** **Create Contract**

**Secundarias:** **View Contract**, **Cancel Contract**, **Duplicate from Template**

### 11.4 Create Contract

**Propósito:** publicar un contrato validable desde plantilla.

**Campos**

- template;
- crop y work type;
- field/slots;
- quantity y minimum quality;
- deadline;
- reward dentro de límites;
- contractor requirements;
- completion destination.

**Review previo**

- summary;
- Treasury impact;
- escrow;
- conflicts;
- field availability;
- validation rules.

**Principal:** **Publish Contract**

**Estados:** draft, invalid, insufficient Treasury, field conflict, ready,
publishing, published.

**Restricción:** no objetivos libres imposibles de validar.

### 11.5 Staff

**Propósito:** gestionar miembros, roles y estado laboral.

**Cada miembro muestra**

- character name;
- role y employment status;
- active Assignment;
- Company Cargo;
- issued materials;
- join date;
- last relevant activity;
- permission exceptions;
- unresolved issues.

**Principal:** **View Member**, **Invite Member** o **Review Applications**.

**Estados:** active, off duty si existe, suspended, pending removal, empty.

### 11.6 Applications

**Propósito:** revisar solicitudes.

**Cada solicitud muestra**

- applicant;
- submitted date;
- preferred work;
- status;
- reviewer;
- duplicate/recent warning.

**Principal:** **Review Application**

**Estados:** pending, under review, accepted, rejected, withdrawn, closed.

### 11.7 Application Review

**Propósito:** tomar una decisión de contratación.

**Contenido obligatorio**

- application;
- applicant identity;
- relevant Public Contract history si está permitido;
- previous employment state;
- proposed role;
- permission summary;
- onboarding effects.

**Principal:** **Hire as Worker**

**Secundarias:** **Reject Application**, **Request Interview**,
**Change Proposed Role**

**Restricción:** no mostrar información privada externa al farming.

### 11.8 Warehouse

**Propósito:** representar stock empresarial y reservas.

**Cada item muestra**

- total, available y reserved quantity;
- quality breakdown;
- incoming Company Cargo;
- Buyer Order reservation;
- storage status;
- discrepancies.

**Principal:** **Deposit Cargo**, **Prepare Order** o **View Stock**.

**Estados:** stocked, low, reserved, full, empty, discrepancy, unavailable.

**Restricción:** withdraw/deposit físico exige presencia.

### 11.9 Procurement

**Propósito:** controlar compras con fondos de empresa.

**Contenido obligatorio**

- budget y remaining budget;
- allowed categories;
- transaction limit;
- recent purchases;
- outstanding issued materials;
- pending approvals;
- policy violations.

**Principal:** **Open Company Market**

**Secundarias:** **Review Purchase**, **Approve Request**,
**View Issued Materials**

### 11.10 Treasury

**Propósito:** explicar dinero disponible y comprometido.

**Contenido obligatorio**

- available balance;
- escrow reserved;
- Assignment pay reserved;
- Lease obligations;
- pending Buyer Order income;
- recent income/expense.

**Principal:** **View Transaction Ledger**

**Restricción:** no confundir balance con company valuation.

### 11.11 Transaction Ledger

**Propósito:** auditar movimientos empresariales.

**Cada movimiento muestra**

- type, amount y direction;
- actor y timestamp;
- source/destination;
- linked Contract/Order/Assignment/Purchase/Lease;
- resulting status;
- failure/reversal reason.

**Principal:** **View Transaction**

**Estados:** completed, pending, escrowed, released, refunded, reversed, failed.

**Restricción:** no se borran movimientos desde UI.

### 11.12 Leases

**Propósito:** mostrar terrenos arrendables, activos y en riesgo.

**Contenido obligatorio**

- starter field;
- active/available fields;
- recurring cost;
- next payment;
- status;
- capacity y crop restrictions;
- Grace Period;
- obligation.

**Principal:** **View Lease** o **Lease Field**

### 11.13 Lease Detail

**Propósito:** evaluar, contratar o resolver un Lease.

**Contenido obligatorio**

- field y location;
- capacity y allowed crops;
- recurring price/billing;
- next payment;
- Treasury impact;
- active crops y linked work;
- Grace rules;
- termination effects.

**Principal:** **Lease Field**, **Pay Lease**, **Resolve Grace Period** o
**End Lease**.

**Grace Period de 24 horas**

- planting suspended;
- care y harvest permitidos;
- deadline exacto;
- alerta para management.

Tras expirar:

- Lease termina;
- field deja de operar;
- se explica el efecto sobre trabajo y cultivos.

---

## 12. Vistas exclusivas del Owner

Salvo que una vista indique lo contrario:

- usuario: Owner;
- disponible para consulta y preparación en Office Terminal y Farm Tablet;
- adquisición o transferencia final de propiedad exige Office/registry;
- los estados globales también aplican.

### 12.1 Roles & Permissions

**Propósito:** configurar capacidades sin accesos ambiguos.

**Contenido obligatorio**

- roles base;
- members por role;
- permissions agrupados;
- financial limits;
- physical/remote permissions;
- pending changes;
- non-editable protections.

**Principal:** **Save Permissions**

**Secundarias:** **Reset Role to Default**, **Review Affected Members**

**Estados:** unchanged, unsaved, invalid combination, conflict, saved,
unavailable.

**Restricciones**

- Manager nunca vende la empresa.
- Nadie elimina al Owner fuera de una transferencia válida.
- Nadie aprueba su propio aumento de budget cuando la policy lo prohíbe.

### 12.2 Company Identity

**Propósito:** gestionar el único elemento personalizable: el nombre.

**Contenido obligatorio**

- current/original name;
- last rename date;
- rename cost;
- cooldown;
- naming rules;
- textual preview.

**Principal:** **Rename Company**

**Estados:** available, cooldown, insufficient funds, invalid/unavailable name,
completed.

**Restricción:** no prometer logo, color, emblem o theme custom.

### 12.3 Business Sale

**Propósito:** preparar la venta de la empresa completa.

**Contenido obligatorio**

- suggested valuation informativa;
- asking price;
- Treasury y Warehouse valuation;
- Leases y Staff count;
- active obligations y escrow;
- Buyer Orders y Public Contracts;
- sale fee;
- seller proceeds;
- effects para Owner y Staff.

**Principal:** **Review Sale Listing**

**Estados:** not listed, draft, invalid price, blocked, ready.

### 12.4 Sale Listing Review

**Propósito:** confirmar qué se vende y qué hereda el comprador.

**Contenido obligatorio**

- final price;
- included assets/liabilities;
- staff continuity;
- active Leases, Orders y Contracts;
- Treasury retained by company;
- seller payment y fees;
- former Owner exit;
- listing expiration.

**Principal:** **Publish Business for Sale**

**Secundarias:** **Edit Listing**, **Cancel**

### 12.5 Ownership Transfer Confirmation

**Propósito:** cerrar compra/venta sin ambigüedad.

**Usuarios:** Buyer y selling Owner.

**Office/Tablet:** final en Office/registry.

**Contenido obligatorio**

- seller, buyer y company;
- final price y buyer funds source;
- fees;
- asset/liability summary;
- listing version;
- atomic transfer warning;
- staff continuity;
- former Owner exit.

**Principal:** Buyer **Confirm Purchase**; Seller **Confirm Sale** cuando proceda.

**Estados:** awaiting, validating, listing changed, insufficient buyer funds,
locked, completed, failed without partial transfer.

---

## 13. Flujos esenciales

### 13.1 Compra inicial

1. Visitor abre Company Profile.
2. Entra en Business for Sale.
3. Revisa precio, activos y obligaciones.
4. Ve fondos personales y saldo posterior.
5. Se desplaza al punto físico.
6. Confirma.
7. Se valida que sigue sin Owner.
8. Dinero y ownership cambian atómicamente.
9. Nuevo Owner define company name.
10. Se abre onboarding interno.

### 13.2 Solicitar empleo

1. Visitor completa Job Application.
2. Management la recibe en Applications.
3. Abre Application Review.
4. Selecciona role inicial.
5. Confirma **Hire as Worker**.
6. El applicant recibe acceso de miembro.
7. Today cambia a experiencia interna.

### 13.3 Publicar y aceptar Public Contract

1. Staff abre Create Contract.
2. Elige plantilla verificable.
3. Define objetivo, field, deadline y reward.
4. Se validan conflictos, permissions y Treasury.
5. Reward queda en escrow.
6. Contract se publica.
7. Visitor revisa términos y materiales propios.
8. Confirma **Accept Contract**.
9. Queda reservado a una persona.
10. Active Contract guía el trabajo.
11. Completion libera pago o resuelve fallo.

### 13.4 Assignment interna

1. Supervisor identifica una necesidad.
2. Crea Assignment desde plantilla.
3. Elige Worker, objetivo, deadline y pay.
4. Pay queda reservado.
5. Worker acepta y ejecuta.
6. Se validan contribuciones.
7. Company Cargo se deposita si procede.
8. Assignment termina.
9. Worker cobra.
10. Ledger registra el pago.

### 13.5 Personal Purchase

1. Usuario abre Supply Market.
2. Selecciona Personal payer.
3. Elige items/cantidad.
4. Purchase Review muestra fondos y capacidad.
5. Completa físicamente.
6. Items entran como propiedad personal.
7. Treasury no cambia.

### 13.6 Company Procurement

1. Usuario autorizado abre Company Procurement.
2. Selecciona items permitidos.
3. Review muestra Company payer.
4. Se validan role, budget, stock y Treasury.
5. Completa físicamente.
6. Items llegan como company-owned material.
7. Ledger registra buyer, items, coste y contexto.

### 13.7 Company Cargo

1. Acción autorizada genera producto empresarial.
2. Entra al inventario como Company Cargo.
3. Today muestra destination.
4. El jugador transporta físicamente.
5. Deposita en Warehouse.
6. Warehouse actualiza stock/reservas.
7. Work relacionado actualiza progreso.

### 13.8 Buyer Order

1. Management revisa Orders.
2. Compara demanda con Warehouse/Fields.
3. Acepta.
4. Se reserva stock.
5. Se crean Assignments para faltantes.
6. Producción se deposita.
7. Warehouse prepara pedido.
8. Se entrega.
9. Payment entra en Treasury.
10. Order queda completed.

### 13.9 Venta al mayorista bot

1. Management selecciona stock disponible no reservado.
2. Mayorista muestra precio inferior garantizado.
3. Se revisan quantity, quality y payout.
4. Se confirma.
5. Stock sale del Warehouse.
6. Treasury recibe dinero.
7. Ledger registra la venta.

### 13.10 Lease e impago

1. Management evalúa un field.
2. Revisa coste, capacity y restrictions.
3. Confirma Lease.
4. Field pasa a active.
5. UI avisa antes del siguiente pago.
6. Impago inicia 24h Grace Period.
7. Se bloquea planting; care/harvest continúan.
8. Management paga o termina.
9. Si expira, field deja de operar.

### 13.11 Venta de empresa

1. Owner abre Business Sale.
2. Revisa activos, obligaciones, Staff y valuation.
3. Define asking price.
4. Revisa listing.
5. Publica.
6. Buyer deposita fondos mediante escrow.
7. Se revalidan listing, activos y fondos.
8. Mutaciones empresariales se bloquean brevemente.
9. Ownership y payment cambian atómicamente.
10. Staff permanece.
11. Former Owner sale.
12. New Owner recibe acceso.

---

## 14. Reglas de negocio visibles

### Empresa y propiedad

- Una única empresa.
- Primer comprador usa dinero personal.
- Un solo Owner.
- Reventa mediante listing + escrow.
- Se transfiere empresa completa.
- Staff permanece.
- Former Owner sale.

### Public Contracts

- Los crea Staff mediante plantillas.
- Reward queda reservado al publicar.
- Un Contractor por contrato.
- Contractor usa materiales propios.
- Acceso limitado al ámbito del contrato.

### Assignments

- Trabajo interno.
- Asignadas a empleados.
- Pago por resultado validado, no por tiempo online.

### Procurement

- Personal funds y Treasury son distintos.
- Company Procurement exige permission y budget.
- Item puede entrar al inventario autorizado.
- Sigue siendo company-owned.
- Todo queda auditado.

### Supplier Stock

- Planting materials esenciales permanecen disponibles sin límite operativo.
- Tools y consumibles especiales pueden tener stock limitado.
- El stock limitado muestra cantidad, estado y restock cuando se conozca.
- Una categoría futura no aparece hasta que sus items tengan uso real.

### Cargo

- Producto de company fields pertenece a la empresa.
- Worker es custodio.
- Debe depositarse.
- No parece inventario personal comerciable.

### Buyer Orders

- NPC/system y future real business usan el mismo concepto.
- El futuro business buyer crea orders mediante otra UI/API.
- Farm Hub no requiere rediseño para integrarlos.

### Mayorista

- Siempre disponible.
- Paga menos que Buyer Orders.
- Salida de excedente, no estrategia óptima.

### Leases

- Starter Field incluido.
- Expansión mediante arrendamiento.
- 24h Grace Period.
- En gracia: no planting, sí care/harvest.

### Identidad

- First Owner define nombre.
- Rename con coste y cooldown.
- Sin logo/theme custom.

---

## 15. Estados globales

### Loading

No mostrar datos falsos. Copy:

- **Loading farm data…**
- **Loading company records…**

### Empty

Explicar ausencia y siguiente paso:

- **No work assigned**
- **No public contracts available**
- **Warehouse is empty**
- **No applications waiting**

### Restricted

Indicar action bloqueada, permission y quién puede resolver.

### Unavailable

La función existe, pero no puede utilizarse temporalmente.

### Insufficient Funds

Distinguir:

- **Insufficient personal funds**
- **Insufficient company funds**
- **Procurement budget exceeded**

### Inventory Full

Indicar espacio necesario, operación no ejecutada y confirmar que no se cobró.

### Expired

Mostrar deadline y efecto.

### Sold Out

Mostrar restock cuando se conozca.

### Contract Reserved

No exponer identidad privada del otro Contractor.

### Contract Failed / Completed

Mostrar result, recognized requirements, economic effect y cargo/materials.

### Lease Grace Period

Mostrar deadline, amount, planting suspended y acciones permitidas.

### Business Sale Pending / Completed

Pending muestra bloqueo y escrow. Completed confirma Owner, payment y permission
refresh.

### Connection / Service Unavailable

Copy:

- **Farm service is unavailable**
- **Connection lost. No changes were submitted.**

---

## 16. Vocabulario canónico

Usar:

- Farm Business Hub
- Office Terminal
- Farm Tablet
- Company
- Owner
- Manager
- Supervisor
- Procurement
- Worker
- Visitor
- Contractor
- Public Contract
- Active Contract
- Assignment
- Buyer Order
- Supply Market
- Personal Purchase
- Company Procurement
- Issued Materials
- Company Cargo
- Warehouse
- Treasury
- Transaction Ledger
- Lease
- Grace Period
- Business for Sale
- Sale Listing
- Escrow

No intercambiar:

- Contract y Assignment;
- Buyer Order y Public Contract;
- personal item y company-owned item;
- Treasury y company valuation;
- Warehouse stock y player inventory.

### Acciones

- View
- Review
- Accept
- Assign
- Submit
- Publish
- Confirm
- Deposit
- Collect
- Set Route
- Buy
- Sell
- Hire
- Reject
- Withdraw
- Cancel
- Close

Evitar **Proceed**, **OK** para finanzas y **Manage** cuando exista un verbo más
específico.

---

## 17. Datos simulados para el prototipo

Los datos son ficticios y no constituyen balance económico final.

### Empresa

- Company: Grapeseed Farm Co.
- Status: Operating
- Owner: Elijah Mercer
- Treasury available: 24,680
- Escrow reserved: 2,400
- Warehouse valuation: 18,950
- Active fields: 2
- Active staff: 6

### Staff

- Elijah Mercer — Owner
- Maya Collins — Manager
- Jordan Tate — Supervisor
- Lena Brooks — Procurement
- Noah Reed — Worker
- Sofia Bennett — Worker

### East Field

- Status: Active
- Lease: Starter Field
- Capacity: 48 plots
- Crops: Tomato, Lettuce
- Attention: 6 tomato plots need water

### North Beds

- Status: Grace Period
- Payment deadline: Today, 18:00
- Capacity: 24 plots
- Crops: Carrot, Potato
- Restriction: Planting suspended

### Assignment

- Title: Irrigate Tomato Row C
- Assignee: Noah Reed
- Field: East Field
- Deadline: Today, 18:20
- Pay: 180
- Status: In Progress
- Verified: 4 of 10 plots
- Issued material: Watering Can

### Public Contract

- Title: Prepare Tomato Row D
- Type: Planting
- Field: East Field
- Required: 8 tomato seedlings
- Materials: Contractor provided
- Deadline: Tomorrow, 16:00
- Reward: 640
- Escrow: Funded
- Status: Available

### Buyer Order

- Buyer: County Produce Depot
- Source: System Buyer
- Product: Tomato Crates
- Quantity: 18
- Minimum quality: Fine
- Deadline: Today, 19:00
- Payment: 4,860
- Status: In Progress
- Warehouse reserved: 11 of 18

### Supply Market

- Tomato Seedling: 18 each, base stock unlimited
- Lettuce Seedling: 12 each, base stock unlimited
- Carrot Seed Packet: 9 each, base stock unlimited
- Seed Potato: 14 each, base stock unlimited
- Watering Can: 240, limited stock 4

### Business Sale

- Asking price: 180,000
- Treasury included: 24,680
- Warehouse valuation: 18,950
- Active Leases: 1 paid, 1 in Grace Period
- Staff retained: 6
- Active obligations: 7,200
- Sale fee: 5 percent
- Listing status: Draft

---

## 18. Funciones futuras reconocidas, pero ocultas

La arquitectura contempla:

- Buyer Orders creados por restaurantes/tiendas reales;
- parcelas privadas adicionales;
- maquinaria;
- business integrations;
- tech tree;
- farmer progression;
- analytics avanzados;
- eventos;
- múltiples empresas si la visión cambia.

No aparecen como tabs vacías, botones disabled o **Coming Soon**.

---

## 19. Fuera de alcance

Este documento no define:

- minigames;
- diseño visual;
- colores o theme;
- tipografías;
- iconografía;
- layout;
- componentes;
- visual animation;
- schemas SQL;
- callbacks Lua;
- NUI events;
- fórmulas finales de precios;
- XP, levels o tech tree;
- machinery;
- salary by time;
- multiple farm companies;
- branding uploads;
- player marketplace.

---

## 20. Criterios de aceptación del prototipo

El prototipo debe permitir revisar:

1. empresa sin Owner y compra inicial;
2. Visitor con profile, market, contracts y application;
3. Contractor con Active Contract y completion;
4. Worker con Today, Field, Assignment y Company Cargo;
5. Procurement con Personal/Company purchase;
6. Supervisor creando Assignment;
7. Manager administrando Order, Contract, Staff y Lease;
8. Owner gestionando permissions, name y Business Sale;
9. diferencias Office Terminal / Farm Tablet;
10. loading, empty, restricted, unavailable y error;
11. compra personal;
12. compra empresarial;
13. contrato financiado por escrow;
14. Buyer Order y mayorista;
15. Lease en Grace Period;
16. transferencia de propiedad completada.

El prototipo no necesita backend real, pero ninguna transición puede contradecir
este documento.

---

## 21. Checklist del designer

Antes de cerrar una vista:

- ¿Está claro quién la usa?
- ¿Está claro si es Office o Tablet?
- ¿La acción principal responde al propósito?
- ¿Se distingue personal money de company money?
- ¿Se distinguen Contract, Assignment y Buyer Order?
- ¿La propiedad de items/cargo es inequívoca?
- ¿Existe empty state?
- ¿Existe restricted state?
- ¿Existe unavailable/error state?
- ¿Los deadlines tienen contexto?
- ¿Las confirmaciones explican el efecto?
- ¿Las funciones futuras están ocultas?
- ¿El copy visible está en inglés?
- ¿Se evitó inventar contenido no definido?
