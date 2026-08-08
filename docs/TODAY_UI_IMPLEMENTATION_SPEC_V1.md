# Today — Implementation Specification v1

> **Nota de implementación — Fase 1:** la geometría fullscreen descrita en este
> documento queda sustituida por un canvas lógico opaco de **1440 × 810**.
> Office Terminal y Farm Tablet escalan ese canvas uniformemente dentro de su
> marco físico. El mundo FiveM solo puede verse alrededor del dispositivo y
> nunca a través del fondo de la interfaz. Esta sustitución afecta a geometría y
> responsive; la jerarquía, contenido y dirección visual de Today siguen vigentes.

> - Estado: propuesta cerrada para aprobación del Product Owner
> - Superficie maestra: Office Terminal
> - Contexto maestro: Worker con Assignment activa
> - Fuente visual: ChatGPT Image 8 ago 2026, 16_15_37.png, 1672 × 941
> - Fuente funcional: FARM_BUSINESS_HUB_PRODUCT_SPEC.md
> - Idioma del documento: español
> - Copy visible de interfaz: inglés

---

## 1. Objetivo

Este documento convierte la opción visual aprobada de Today en un contrato
implementable con React, Tailwind y TypeScript dentro de una NUI de FiveM.

Su objetivo es eliminar decisiones abiertas antes de programar:

- geometría y jerarquía;
- comportamiento por resolución;
- tokens visuales;
- composición React;
- contenido;
- estados;
- navegación;
- permisos;
- validación visual y funcional.

La pantalla responde a una sola pregunta:

**What needs my attention now?**

Today no es un dashboard de estadísticas. Presenta una prioridad dominante y una
cola breve de asuntos accionables.

### 1.1 Resultado de esta fase

Después de aprobar este documento se puede construir la pantalla sin redefinir
su diseño durante la implementación.

Esta fase no incluye:

- código React o Tailwind;
- callbacks Lua o eventos NUI definitivos;
- backend o esquema SQL;
- diseño de Farm Tablet;
- Field Detail;
- Assignment Detail;
- minijuegos;
- assets de cultivos;
- módulos futuros.

### 1.2 Orden de autoridad

Si aparece una contradicción, se aplica este orden:

1. FARM_BUSINESS_HUB_PRODUCT_SPEC.md para reglas de negocio, roles y vocabulario;
2. este documento para comportamiento, geometría y presentación de Today;
3. la captura maestra para art direction, composición y peso visual.

La captura es una referencia visual. No es un asset que se incrustará en la NUI.

---

## 2. Lectura oficial de la pantalla maestra

La captura representa este escenario:

- superficie: Office Terminal;
- empresa: operativa;
- usuario: Worker;
- ruta activa: Today;
- Assignment: In Progress;
- trabajo actual: Water North Field;
- progreso verificado: 3 of 8 rows;
- Company Cargo pendiente: 12 Tomato Crates;
- Field Attention: North Field con nivel de agua bajo;
- Next Work: Harvest Greenhouse 2;
- fecha: Saturday, 8 Aug 2026.

### 2.1 Jerarquía obligatoria

El orden perceptivo debe ser:

1. trabajo actual y su acción principal;
2. Company Cargo;
3. Field Attention;
4. Next Work;
5. navegación y contexto;
6. información secundaria.

El escenario de FiveM debe seguir siendo visible. La interfaz organiza la
atención alrededor del mundo, no lo sustituye con un dashboard opaco.

### 2.2 Decisiones visuales inmutables para v1

- Fondo raíz transparente en runtime FiveM.
- Negro carbón y paneles oscuros translúcidos.
- Amarillo cálido reservado para selección, estado urgente y acción principal.
- Barlow Condensed para títulos, navegación, estados y acciones.
- Source Sans 3 para descripciones e instrucciones.
- Phosphor para iconos funcionales.
- Contenido principal en el lado izquierdo.
- Cola de prioridades en el perímetro derecho.
- Centro visual despejado para conservar presencia del mundo.
- Viñeta y gradientes de contraste, sin desenfoque pesado del mundo.
- Bordes discretos, sin glassmorphism brillante.
- Animaciones breves y materiales.
- Ningún bloque de KPIs.

### 2.3 Fondo en FiveM y fondo de desarrollo

En FiveM, el mundo se ve a través de la NUI transparente. La implementación no
debe cargar una imagen agrícola como fondo de producción.

En navegador local puede existir un BackgroundFixture intercambiable para
comparación visual. Debe estar aislado del bundle de producción o desactivado
por configuración. No se permite recrear el escenario con CSS, SVG improvisado
o un placeholder genérico.

---

## 3. Sistema de coordenadas

### 3.1 Referencia

La captura fuente mide 1672 × 941 y tiene una relación de aspecto efectiva de
1.777, equivalente a 16:9.

La implementación se define sobre un canvas canónico de 1920 × 1080. El factor
de conversión desde la captura es 1.1483.

Las medidas canónicas son el objetivo de 1920 × 1080. En otras resoluciones se
aplican las reglas responsive de la sección 5; no se escala toda la aplicación
con transform.

### 3.2 Capas

De atrás hacia delante:

1. mundo FiveM;
2. tint global transparente;
3. gradientes laterales, superior e inferior;
4. header;
5. introducción de pantalla;
6. Hero Priority;
7. Priority Rail;
8. diálogos y popovers;
9. toasts de sistema.

Z-index semántico:

- world overlay: 0;
- page content: 10;
- header: 30;
- modal backdrop: 50;
- modal: 60;
- toast: 70.

No deben utilizarse valores arbitrarios fuera de esta escala.

---

## 4. Layout canónico — 1920 × 1080

### 4.1 Header

- Posición: top 0, left 0, right 0.
- Altura: 88 px.
- Padding horizontal: 28 px.
- Fondo: carbón translúcido.
- Borde inferior: 1 px.
- Contenido alineado verticalmente al centro.
- El fondo y el borde ocupan todo el ancho físico.
- El contenido usa el mismo Safe Canvas descrito en 5.4.

Orden horizontal:

1. Brand;
2. divisor vertical;
3. Surface Label;
4. divisor corto;
5. Role Label;
6. navegación primaria centrada;
7. fecha alineada a la derecha.

Medidas:

- Brand: ancho reservado 216 px.
- Divisor posterior al Brand: 1 × 54 px.
- Gap Brand–divisor: 20 px.
- Gap divisor–Surface Label: 22 px.
- Gap Surface Label–divisor corto: 16 px.
- Divisor corto: 1 × 24 px.
- Gap divisor corto–Role Label: 16 px.
- Navegación: gap de 48 px.
- Fecha: ancho máximo 250 px y alineación derecha.

El logo final debe ser un asset aprobado. Hasta disponer de él, el prototipo
puede usar el wordmark y símbolo existentes en el material aprobado, pero no un
icono inventado.

### 4.2 Área principal

- Top: 88 px.
- Left: 0.
- Right: 0.
- Bottom: 0.
- Altura: calc(100vh - 88px).
- Overflow global: hidden.

El área principal no crea una tarjeta general. Solo los elementos que necesitan
separación funcional reciben superficie.

### 4.3 Screen Intro

Coordenadas canónicas:

- left: 54 px;
- top: 151 px desde viewport;
- ancho máximo: 520 px.

Contenido:

- título: TODAY;
- subtítulo: What needs my attention now?

Separación:

- título a subtítulo: 12 px;
- no existe eyebrow, breadcrumb ni métrica sobre el título.

### 4.4 Hero Priority

La captura maestra usa la variante Assignment.

Geometría canónica:

- left: 58 px;
- bottom: 60 px;
- width: 760 px;
- height objetivo: 506 px;
- min-height: 470 px;
- max-height: 520 px;
- padding exterior: 36 px;
- radio: 8 px;
- borde: 1 px;

El panel se divide en:

1. status row;
2. identity row;
3. progress block;
4. deadline row;
5. related entity row;
6. primary action.

Medidas internas:

- status pill: altura 44 px;
- status a identity: 24 px;
- icon column: 116 px;
- icon funcional: 72 px;
- gap icon–content: 24 px;
- progress track: 100% del content column;
- progress track height: 12 px;
- deadline a separator: 20 px;
- separator: 1 px;
- related entity row: altura mínima 56 px;
- botón principal: altura 68 px;
- botón al borde inferior: 0 dentro del flujo del panel.

El título puede ocupar dos líneas solo en resoluciones compactas. En 1920 × 1080
Water North Field debe permanecer en una línea.

### 4.5 Priority Rail

Geometría canónica:

- right: 42 px;
- top: 244 px;
- width: 430 px;
- bottom mínimo: 80 px;
- máximo de items visibles: 3;
- sin tarjeta envolvente opaca;
- separación entre items mediante divider horizontal.

Cada Priority Item utiliza una grid de tres columnas:

- ordinal: 48 px;
- icono: 62 px;
- contenido: minmax(0, 1fr).

Gaps:

- ordinal a icono: 18 px;
- icono a contenido: 20 px.

El ordinal es un círculo de 42 px. El primer item usa borde amarillo; los demás
usan borde neutral. Los números 1–3 representan el orden visible de la cola
después del Hero, no un identificador persistente ni una prioridad de backend.

Alturas objetivo:

- Company Cargo: 218 px;
- Field Attention: 210 px;
- Next Work: 164 px;

Los dos primeros items tienen acción textual y divider interno. Next Work es
informativo en la captura maestra y no muestra CTA.

### 4.6 Zona visual preservada

En 1920 × 1080 debe quedar libre de paneles permanentes una franja aproximada
entre:

- x: 850–1430 px;
- y: 140–760 px.

Esta regla evita cubrir el escenario y mantiene el mundo como parte de la
composición. No impide que un modal temporal ocupe el centro.

---

## 5. Responsive para FiveM

### 5.1 Principio

La interfaz se adapta por ancho, alto y aspect ratio. No asume móvil y no usa
breakpoints de teléfono.

No se permite:

- aplicar transform: scale a toda la aplicación;
- reducir texto por debajo del mínimo legible;
- mover la cola derecha sobre el Hero;
- añadir scroll horizontal;
- deformar el header para conservar contenido no esencial.

### 5.2 Resoluciones de validación

La implementación debe probarse como mínimo en:

- 1280 × 720;
- 1680 × 1050;
- 1920 × 1080;
- 2560 × 1440;
- 3440 × 1440.

También debe mantenerse funcional a 1152 × 648. Por debajo de esa resolución no
es un objetivo visual de v1, pero la NUI no debe bloquear el cierre con Escape.

### 5.3 Reference mode

Condición:

- width entre 1600 y 2199 px;
- height igual o superior a 900 px;
- aspect ratio igual o superior a 1.55.

Comportamiento:

- usa las medidas de 1920 × 1080 mediante tokens fluidos;
- el Hero se mantiene entre 700 y 760 px;
- el rail se mantiene entre 390 y 430 px;
- el título permanece visible;
- no existe scroll.

### 5.4 Safe Canvas y ultrawide

Para width igual o superior a 2200 px:

- overlays de viñeta ocupan todo el viewport;
- header background ocupa todo el viewport;
- contenido funcional se coloca dentro de un Safe Canvas de máximo 1920 px;
- el Safe Canvas se centra horizontalmente;
- Hero y Screen Intro se anclan a su borde izquierdo;
- Priority Rail se ancla a su borde derecho;
- no se envían controles a los extremos físicos de un monitor ultrawide.

El Safe Canvas acepta un inset adicional configurable para respetar safe-zone
del jugador. Valor por defecto: 0 px. Rango admitido: 0–48 px.

### 5.5 Compact mode

Condición:

- width entre 1152 y 1599 px; o
- height entre 648 y 899 px;
- aspect ratio igual o superior a 1.55.

Cambios:

- header: 64–72 px;
- padding horizontal de header: 20–24 px;
- Brand: ancho reservado 170–190 px;
- navegación: gap 26–34 px;
- fecha desaparece antes que cualquier módulo autorizado;
- Screen Intro: left 32–40 px y top 96–112 px;
- título: 42–48 px;
- Hero: left 32–40 px, bottom 32–40 px;
- Hero width: clamp(520px, 55vw, 650px);
- Hero padding: 24–30 px;
- Hero icon column: 80–94 px;
- botón principal: 56–60 px;
- Priority Rail: right 24–32 px;
- Priority Rail width: clamp(300px, 29vw, 350px);
- body text no baja de 14 px;
- elementos secundarios pueden truncar a dos líneas.

En 1280 × 720 el Hero no puede superar 55% del ancho y el rail no puede superar
30%. Debe conservarse un gap mínimo de 24 px entre ambos.

### 5.6 Narrow aspect mode

Condición:

- aspect ratio menor que 1.55; o
- width menor que 1152 px.

Comportamiento:

- Hero conserva la prioridad y ocupa el ancho disponible menos 48 px;
- Priority Rail se oculta del canvas principal;
- aparece un botón periférico Attention Queue con el número de items;
- el botón abre un drawer derecho de ancho min(420px, 92vw);
- el drawer conserva el orden y acciones del rail;
- header oculta fecha y Surface Label;
- el Role Label permanece;
- la navegación autorizada usa gaps reducidos y nunca muestra rutas futuras;
- el mundo sigue visible alrededor del Hero;
- Escape cierra primero el drawer y después la NUI.

No se convierte Today en una lista vertical genérica.

### 5.7 Altura limitada

Si el ancho permite Reference mode pero la altura es inferior a 760 px:

- Screen Intro reduce su margen superior;
- Hero usa su variante compacta;
- se reduce espacio interno, no tamaño mínimo de texto;
- related entity puede truncarse en una línea;
- el rail mantiene máximo tres items;
- si todavía no cabe, el rail utiliza el drawer de Narrow aspect mode.

### 5.8 Texto largo y localización

Aunque v1 usa copy inglés:

- títulos de Assignment: máximo dos líneas;
- nombres de campo: máximo dos líneas;
- nombres de producto: máximo dos líneas;
- identificadores como BO-204 nunca se dividen;
- horas y cantidades usan números tabulares;
- truncado con ellipsis requiere title accesible o descripción equivalente.

---

## 6. Tokens oficiales de Today

Todos los valores deben exponerse como CSS custom properties y mapearse al theme
de Tailwind. No se permiten hex o rgba aislados dentro de componentes.

### 6.1 Color

Base:

- color-carbon-950: #080A09;
- color-carbon-900: #0D100E;
- color-carbon-850: #121512;
- color-carbon-800: #191C18.

Paneles:

- surface-header: rgba(8, 10, 9, 0.86);
- surface-panel-strong: rgba(10, 12, 11, 0.92);
- surface-panel-soft: rgba(12, 15, 13, 0.78);
- surface-hover: rgba(244, 195, 40, 0.08).

Amarillo:

- color-accent: #F5C331;
- color-accent-hover: #FFD45A;
- color-accent-pressed: #D9A91F;
- color-on-accent: #0A0C0B;

Texto:

- text-primary: #F2F0E9;
- text-secondary: #B8BAB4;
- text-muted: #898D86;
- text-disabled: #62665F.

Secundarios:

- color-earth: #76573F;
- color-plant: #74885B;
- color-olive: #6E7565;
- color-success: #83A06A;
- color-error: #D46C56.

Líneas:

- border-neutral: rgba(235, 235, 225, 0.16);
- border-subtle: rgba(235, 235, 225, 0.10);
- border-accent: rgba(245, 195, 49, 0.34);
- focus-ring: #F5C331.

### 6.2 Overlays del mundo

Los overlays se combinan; no se aplica un bloque negro uniforme.

- global tint: rgba(5, 7, 6, 0.18);
- top gradient: carbón 0.52 a transparente en 300 px;
- left gradient: carbón 0.54 a transparente antes del 58% del ancho;
- right gradient: carbón 0.76 a transparente hacia el 68% del ancho;
- bottom gradient: carbón 0.62 a transparente hacia el 58% de la altura;
- vignette exterior: máximo equivalente a 0.32 de opacidad.

El rail necesita contraste local mayor que el centro. El mundo central no debe
quedar lavado ni completamente negro.

### 6.3 Tipografía

Fuentes:

- Display: Barlow Condensed;
- Body: Source Sans 3.

Las fuentes se sirven localmente como WOFF2. No dependen de Google Fonts ni de
red externa.

Pesos admitidos:

- Barlow Condensed: 600 y 700;
- Source Sans 3: 400 y 600.

Escala canónica:

- display-screen: 56 px / 0.96 / 700 / tracking 0.01em;
- display-hero: 48 px / 1.00 / 700 / tracking 0.015em;
- heading-item: 27 px / 1.05 / 700 / tracking 0.015em;
- heading-small: 20 px / 1.10 / 600 / tracking 0.04em;
- action: 21 px / 1.00 / 700 / tracking 0.07em;
- nav: 19 px / 1.00 / 600 / tracking 0.035em;
- body-large: 21 px / 1.35 / 400;
- body: 18 px / 1.40 / 400;
- body-small: 16 px / 1.35 / 400;
- meta: 15 px / 1.30 / 600.

Títulos, tabs, status y acciones usan uppercase. Descripciones y nombres propios
mantienen capitalización natural.

### 6.4 Espaciado

Escala única:

- space-1: 4 px;
- space-2: 8 px;
- space-3: 12 px;
- space-4: 16 px;
- space-5: 20 px;
- space-6: 24 px;
- space-8: 32 px;
- space-10: 40 px;
- space-12: 48 px;
- space-16: 64 px.

No introducir valores nuevos salvo las coordenadas maestras documentadas.

### 6.5 Bordes, radio y sombra

- border-width: 1 px;
- radius-panel: 8 px;
- radius-control: 5 px;
- radius-pill: 4 px;
- radius-round: 999 px;
- panel shadow: 0 18px 50px rgba(0, 0, 0, 0.30);
- focus ring: 2 px exterior con offset de 3 px carbón.

No usar radios grandes de aplicación móvil ni sombras luminosas.

### 6.6 Iconografía

Librería: Phosphor Icons para React.

Peso por defecto: regular. El estado activo puede usar medium si el wrapper lo
permite, sin mezclar estilos dentro del mismo grupo.

Mapeo inicial:

- Company Cargo: Package;
- Field Attention y Water Assignment: Drop;
- Next Work: Plant;
- Deadline: Clock;
- Related Buyer Order: FileText;
- Forward action: CaretRight;
- Retry: ArrowClockwise;
- Restricted: LockKey;
- Service unavailable: CloudSlash.

Tamaños:

- hero icon: 72 px;
- rail icon: 50 px;
- inline icon: 24 px;
- nav/context icon: 22 px;

No dibujar iconos funcionales manualmente.

### 6.7 Motion

- hover: 120 ms;
- press: 80 ms;
- state transition: 180 ms;
- panel/drawer: 220 ms;
- easing: cubic-bezier(0.2, 0.8, 0.2, 1).

Feedback del botón principal:

- hover: amarillo hover y translateY(-1px);
- pressed: amarillo pressed y translateY(1px);
- focus: focus ring visible;
- disabled: sin transform, cursor default y contraste atenuado.

El progreso puede animar una sola vez al recibir datos, máximo 240 ms. No hay
loops decorativos. prefers-reduced-motion elimina desplazamientos y transiciones
no esenciales.

---

## 7. Arquitectura React

### 7.1 Árbol

~~~text
TodayRoute
└── PermissionBoundary
    └── TodayStateBoundary
        └── FarmBusinessShell
            ├── WorldContrastLayer
            ├── OfficeHeader
            │   ├── FarmBrand
            │   ├── SurfaceContext
            │   ├── RoleContext
            │   ├── PrimaryNavigation
            │   │   └── PrimaryNavItem
            │   └── ServerDate
            ├── TodayMain
            │   ├── ScreenIntro
            │   ├── HeroPriority
            │   │   ├── PriorityStatus
            │   │   ├── PriorityIdentity
            │   │   ├── VerifiedProgress
            │   │   ├── DeadlineSummary
            │   │   ├── RelatedEntitySummary
            │   │   └── PrimaryAction
            │   └── PriorityRail
            │       └── PriorityItem
            │           ├── PriorityOrdinal
            │           ├── PriorityIcon
            │           ├── PriorityContent
            │           └── PriorityAction
            ├── AttentionQueueDrawer
            ├── ConfirmDialogHost
            └── ToastRegion
~~~

### 7.2 Responsabilidad de componentes

TodayRoute:

- obtiene el TodayViewModel del adapter;
- no decide permisos ni orden visual con datos sin normalizar;
- emite intents de navegación;
- conserva el último focus al volver desde una subvista.

PermissionBoundary:

- valida today.view;
- cambia a Restricted si el permiso se pierde con la vista abierta;
- nunca renderiza datos privados antes de validar.

TodayStateBoundary:

- selecciona loading, ready, empty, error, restricted o unavailable;
- no mezcla skeleton con datos reales;
- permite error parcial del rail sin romper el Hero.

FarmBusinessShell:

- monta header, overlays y portal roots;
- controla apertura/cierre de NUI;
- no contiene reglas de negocio de Today.

OfficeHeader:

- recibe rutas ya filtradas;
- no renderiza tabs disabled para permisos ausentes;
- muestra surface, role y fecha.

HeroPriority:

- renderiza el primer asunto accionable;
- admite variantes assignment, cargo, field, buyerOrder, approval y nextWork;
- la variante assignment es la maestra de v1.

VerifiedProgress:

- recibe current y total ya validados;
- limita el porcentaje entre 0 y 100;
- muestra valor textual además de barra;
- nunca incrementa progreso de forma optimista.

PriorityRail:

- recibe máximo tres items;
- mantiene el orden del view model;
- no reordena en cliente por color, tipo o deadline;
- cambia a drawer según layout.

ConfirmDialogHost:

- existe a nivel shell para reutilización futura;
- Today no lo abre para navegación o Continue Assignment.

ToastRegion:

- anuncia conexión, fallo de navegación y cambios externos;
- no sustituye un error persistente de página.

### 7.3 Separación de capas

La implementación debe separar:

- domain types;
- view-model normalizado;
- componentes presentacionales;
- adapter de transporte NUI;
- fixtures de desarrollo.

Los componentes no llaman fetch, GetParentResourceName ni callbacks Lua
directamente. El adapter será la única frontera de transporte cuando se diseñe
el backend.

---

## 8. Contrato de datos frontend

Los nombres siguientes son contratos de frontend. No fijan nombres de tablas,
callbacks Lua ni eventos de red.

~~~ts
type FarmRole =
  | 'visitor'
  | 'contractor'
  | 'worker'
  | 'procurement'
  | 'supervisor'
  | 'manager'
  | 'owner'

type TodayPageState =
  | 'loading'
  | 'ready'
  | 'empty'
  | 'error'
  | 'restricted'
  | 'unavailable'

type PriorityKind =
  | 'assignment'
  | 'cargo'
  | 'field'
  | 'buyerOrder'
  | 'approval'
  | 'nextWork'

type PriorityStatus =
  | 'available'
  | 'accepted'
  | 'inProgress'
  | 'blocked'
  | 'waitingApproval'
  | 'completed'
  | 'failed'
  | 'expired'

interface ViewerContext {
  role: FarmRole
  roleLabel: string
  surface: 'office'
  surfaceLabel: 'Office Terminal'
  companyName: string
  serverDateIso: string
  locale: string
}

interface NavigationItem {
  id: 'today' | 'fields' | 'work' | 'supplies' | 'company'
  label: string
  visible: boolean
  active: boolean
}

interface ProgressSummary {
  current: number
  total: number
  unitSingular: string
  unitPlural: string
  verified: boolean
}

interface RelatedEntity {
  kind: 'buyerOrder' | 'assignment' | 'contract'
  id: string
  label: string
  deadlineIso?: string
}

interface ActionIntent {
  id: string
  label: string
  target:
    | 'assignmentDetail'
    | 'activeContract'
    | 'companyCargo'
    | 'fieldDetail'
    | 'buyerOrderDetail'
    | 'approvals'
    | 'work'
  entityId?: string
  enabled: boolean
  disabledReason?: string
}

interface TodayPriority {
  id: string
  kind: PriorityKind
  status: PriorityStatus
  title: string
  primaryLine?: string
  secondaryLine?: string
  tertiaryLine?: string
  cropName?: string
  fieldName?: string
  deadlineIso?: string
  progress?: ProgressSummary
  relatedEntity?: RelatedEntity
  action?: ActionIntent
}

interface TodayCapabilities {
  viewToday: boolean
  viewOwnAssignments: boolean
  viewAuthorizedCargo: boolean
  viewAuthorizedFields: boolean
  viewAvailableWork: boolean
  viewScopedApprovals: boolean
}

interface TodayViewModel {
  state: TodayPageState
  context: ViewerContext
  navigation: NavigationItem[]
  capabilities: TodayCapabilities
  hero?: TodayPriority
  queue: TodayPriority[]
  errorCode?: string
  requiredPermission?: string
}
~~~

### 8.1 Invariantes

- queue contiene de 0 a 3 items.
- hero existe solo en ready.
- empty no contiene hero.
- visitor nunca recibe datos privados de Today.
- current y total son enteros no negativos.
- si total es 0, no se renderiza progress.
- deadlineIso es ISO 8601; el cliente formatea la presentación.
- fechas de ejemplo no se hardcodean en componentes.
- enabled false requiere disabledReason.
- toda acción apunta a una ruta autorizada y existente.
- datos no autorizados se omiten en origen; no basta ocultarlos con CSS.

---

## 9. Selección de prioridades

El view model se entrega ya ordenado. La pantalla no calcula importancia a
partir de estilos.

Orden de producto:

1. active Assignment o Active Contract;
2. Company Cargo pendiente;
3. Field o crop atendible;
4. Buyer Order deadline relacionado;
5. approval o exception pendiente;
6. next work.

### 9.1 Hero

El primer asunto accionable se convierte en Hero.

- Assignment activa: Continue Assignment.
- Active Contract de Contractor: Continue Contract.
- Cargo sin Assignment activa: View Cargo.
- Field Attention sin prioridades anteriores: View Field.
- Buyer Order accionable: View Buyer Order.
- Approval: Review.
- Next Work: View Assignment si ya existe una Assignment visible.

Una Assignment bloqueada sigue siendo Hero. Cambia status a Blocked y su acción
a View Assignment o View Blocker. No se oculta porque explique un problema.

### 9.2 Queue

Los siguientes tres asuntos se muestran en Priority Rail.

- El ordinal comienza siempre en 1.
- No se muestra contador de asuntos ocultos en Reference mode.
- El resto sigue disponible en Fields, Work, Supplies o Company.
- No se añaden badges rojos para forzar urgencia.
- Un item sin acción puede ser informativo, como Next Work en la captura.

### 9.3 Empates

Si existen varios asuntos del mismo tipo:

1. deadline más próximo;
2. severidad operativa;
3. fecha de creación;
4. id estable como último desempate.

La ordenación debe proceder del dominio o normalizador, no de un componente.

---

## 10. Contenido maestro

### 10.1 Header

- Brand: SONAR FARM
- Surface: OFFICE TERMINAL
- Role: WORKER
- Tabs: TODAY, FIELDS, WORK, SUPPLIES, COMPANY
- Date: SATURDAY, 8 AUG 2026

La fecha se genera a partir de serverDateIso. Este texto es solo el fixture.

### 10.2 Screen Intro

- Title: TODAY
- Subtitle: What needs my attention now?

### 10.3 Assignment Hero

- Status: IN PROGRESS
- Title: WATER NORTH FIELD
- Context: Tomatoes · Rows 4–8
- Progress: 3 OF 8 ROWS VERIFIED
- Deadline: DUE TODAY, 18:30
- Related: Buyer Order BO-204 · Today, 21:00
- Action: CONTINUE ASSIGNMENT

### 10.4 Priority Rail

Item 1:

- Title: COMPANY CARGO
- Primary: 12 Tomato Crates
- Secondary: Deliver to Farm Warehouse
- Tertiary: Owned by Sonar Farm
- Action: VIEW CARGO

Item 2:

- Title: FIELD ATTENTION
- Primary: North Field
- Secondary: Water level low
- Action: VIEW FIELD

Item 3:

- Title: NEXT WORK
- Primary: Harvest Greenhouse 2
- Secondary: Tomorrow, 09:00
- Sin CTA en la variante maestra.

### 10.5 Fixture TypeScript

~~~ts
export const workerTodayFixture: TodayViewModel = {
  state: 'ready',
  context: {
    role: 'worker',
    roleLabel: 'Worker',
    surface: 'office',
    surfaceLabel: 'Office Terminal',
    companyName: 'Sonar Farm',
    serverDateIso: '2026-08-08T10:00:00+02:00',
    locale: 'en-GB',
  },
  navigation: [
    { id: 'today', label: 'Today', visible: true, active: true },
    { id: 'fields', label: 'Fields', visible: true, active: false },
    { id: 'work', label: 'Work', visible: true, active: false },
    { id: 'supplies', label: 'Supplies', visible: true, active: false },
    { id: 'company', label: 'Company', visible: true, active: false },
  ],
  capabilities: {
    viewToday: true,
    viewOwnAssignments: true,
    viewAuthorizedCargo: true,
    viewAuthorizedFields: true,
    viewAvailableWork: true,
    viewScopedApprovals: false,
  },
  hero: {
    id: 'assignment-asg-1048',
    kind: 'assignment',
    status: 'inProgress',
    title: 'Water North Field',
    primaryLine: 'Tomatoes · Rows 4–8',
    fieldName: 'North Field',
    cropName: 'Tomatoes',
    deadlineIso: '2026-08-08T18:30:00+02:00',
    progress: {
      current: 3,
      total: 8,
      unitSingular: 'row',
      unitPlural: 'rows',
      verified: true,
    },
    relatedEntity: {
      kind: 'buyerOrder',
      id: 'BO-204',
      label: 'Buyer Order BO-204',
      deadlineIso: '2026-08-08T21:00:00+02:00',
    },
    action: {
      id: 'continue-assignment-asg-1048',
      label: 'Continue Assignment',
      target: 'assignmentDetail',
      entityId: 'asg-1048',
      enabled: true,
    },
  },
  queue: [
    {
      id: 'cargo-cg-441',
      kind: 'cargo',
      status: 'inProgress',
      title: 'Company Cargo',
      primaryLine: '12 Tomato Crates',
      secondaryLine: 'Deliver to Farm Warehouse',
      tertiaryLine: 'Owned by Sonar Farm',
      action: {
        id: 'view-cargo-cg-441',
        label: 'View Cargo',
        target: 'companyCargo',
        entityId: 'cg-441',
        enabled: true,
      },
    },
    {
      id: 'field-north-attention',
      kind: 'field',
      status: 'available',
      title: 'Field Attention',
      primaryLine: 'North Field',
      secondaryLine: 'Water level low',
      action: {
        id: 'view-field-north',
        label: 'View Field',
        target: 'fieldDetail',
        entityId: 'north-field',
        enabled: true,
      },
    },
    {
      id: 'assignment-asg-1052',
      kind: 'nextWork',
      status: 'accepted',
      title: 'Next Work',
      primaryLine: 'Harvest Greenhouse 2',
      secondaryLine: 'Tomorrow, 09:00',
      deadlineIso: '2026-08-09T09:00:00+02:00',
    },
  ],
}
~~~

---

## 11. Estados de interfaz

Todos los estados conservan header, mundo, overlays y Screen Intro, salvo que la
sesión completa sea inválida.

### 11.1 Loading

Copy:

- LOADING FARM DATA…

Comportamiento:

- skeleton conserva la geometría del Hero y rail;
- no muestra cantidades, nombres o progreso falsos;
- no usa shimmer continuo;
- header muestra contexto conocido; los datos desconocidos usan bloques neutros;
- acciones no son enfocables;
- si tarda, no cambia automáticamente a error sin señal del adapter.

### 11.2 Ready — Assignment activa

Es el estado maestro de la captura.

- Hero Assignment;
- hasta tres queue items;
- acción principal habilitada;
- progreso y deadline visibles;
- no existe confirmación al continuar.

### 11.3 Empty — sin trabajo

Copy:

- Status: NO ACTIVE ASSIGNMENT
- Title: No work assigned
- Body: There is no active assignment for you right now.
- Action, si tiene permiso: VIEW AVAILABLE WORK

Reglas:

- Empty se refiere al Hero, no obliga a vaciar la queue;
- Company Cargo o Field Attention todavía pueden aparecer;
- si no existe ninguna prioridad, se añade: You're all caught up.
- no se inventan estadísticas para rellenar espacio.

### 11.4 Blocked

Ejemplos:

- BLOCKED BY SUPPLIES
- FIELD UNAVAILABLE
- WAITING FOR APPROVAL

El Hero conserva identidad, deadline, progreso verificado y motivo. La acción
principal pasa a VIEW ASSIGNMENT, VIEW BLOCKER o REVIEW, según permiso. No se
presenta Continue Assignment si el servidor impide continuar.

### 11.5 Error

Copy:

- Title: TODAY COULD NOT LOAD
- Body: We couldn't load your current farm priorities.
- Action: TRY AGAIN

Reglas:

- no muestra datos potencialmente obsoletos como actuales;
- conserva la posibilidad de cerrar NUI;
- el error code puede aparecer en texto secundario solo en Debug;
- TRY AGAIN emite un intent único y entra en loading.

### 11.6 Restricted

Copy:

- Status: ACCESS RESTRICTED
- Title: Today is not available for this role
- Body: This view requires Today access. A Manager or Owner can update your role.
- Action: VIEW COMPANY PROFILE, solo si la ruta está autorizada.

Debe mostrar el permiso requerido de forma legible, nunca datos privados detrás
de un overlay.

### 11.7 Service unavailable

Copy:

- Title: FARM SERVICE IS UNAVAILABLE
- Body: Your farm data could not be reached. No changes were submitted.
- Action: TRY AGAIN

No se confunde con Restricted ni con Empty.

### 11.8 Connection lost

Toast:

- Connection lost. No changes were submitted.

Acciones que aún no salieron del cliente permanecen sin confirmar. Al recuperar
conexión se solicita un refresh completo antes de habilitar navegación sensible.

### 11.9 Error parcial del rail

Si Hero cargó pero la cola falla:

- Hero permanece usable;
- rail muestra Attention queue unavailable;
- TRY AGAIN afecta solo a la cola;
- no se renumera con placeholders falsos.

---

## 12. Interacciones

### 12.1 Apertura

- NUI recibe contexto y view model.
- Monta el árbol una sola vez.
- Aplica focus al primer control accionable del Hero.
- Mouse y teclado quedan disponibles.
- No reproduce una animación de entrada superior a 220 ms.

### 12.2 Cierre

- Escape cierra primero dialog o drawer abierto.
- Un segundo Escape cierra la NUI.
- Si no hay overlay, Escape cierra la NUI inmediatamente.
- Cerrar no ejecuta acciones pendientes.
- El focus vuelve al juego.

### 12.3 Header

- Click en tab autorizado navega a su ruta raíz.
- Today activo no dispara una recarga al hacer click.
- Hover muestra amarillo solo en texto o indicador, no rellena el tab.
- Active usa texto amarillo y underline de 3 px.
- Tabs no autorizados o futuros no se renderizan.
- Si cambia el role, se recalculan rutas y se valida la ruta actual.

### 12.4 Continue Assignment

- Click abre Assignment Detail de la Assignment indicada.
- No requiere confirmación.
- No altera progreso.
- No marca la Assignment como aceptada.
- Si el permiso o estado cambió, la respuesta del adapter refresca Today y
  presenta el motivo.

### 12.5 View Cargo

- Abre Company Cargo para la carga indicada.
- La vista destino decide si Set Route to Warehouse está disponible.
- Today no deposita ni transfiere items.

### 12.6 View Field

- Abre Field Detail del field autorizado.
- Today no ejecuta riego al pulsar View Field.

### 12.7 Next Work

En la variante maestra es informativo. No se convierte todo el item en un botón
invisible. Si una variante futura añade acción, debe mostrar CTA explícita.

### 12.8 Confirmaciones

Today v1 no muestra confirmación para:

- navegación;
- Continue Assignment;
- View Cargo;
- View Field;
- abrir Attention Queue.

Las confirmaciones del producto se reservan para gasto, publicación, cancelación,
contratación, permisos, venta, lease, abandono o transferencia. Se presentan en
las vistas donde ocurre la acción.

### 12.9 Estados de control

Todo control tiene:

- default;
- hover;
- pressed;
- focus-visible;
- disabled;
- busy, cuando emite un intent no repetible.

Durante busy:

- el texto no cambia de ancho;
- aparece feedback discreto;
- no se permite doble envío;
- Escape sigue disponible.

---

## 13. Variantes por rol y permisos

### 13.1 Visitor

- Today no aparece en navegación.
- No se solicita TodayViewModel privado.
- Si llega por ruta antigua, muestra Restricted o redirige a Company Profile.
- No se renderiza Hero vacío como si fuera empleado.

### 13.2 Contractor

- Surface sigue indicando Office Terminal.
- Today resume Active Contract.
- Hero usa status, contract title, location, verified progress, deadline y reward
  solo si ya son datos autorizados en Active Contract.
- Acción: CONTINUE CONTRACT.
- Queue puede contener contract blocker, materials reminder y deadline.
- No muestra Company Cargo interno salvo cargo ligado y autorizado por contrato.
- Fields se limita a la ubicación contractual.

### 13.3 Worker

Es la variante maestra:

- Hero: su Assignment activa;
- queue: su Company Cargo, Field Attention autorizada y Next Work;
- Work contiene solo sus Assignments;
- Company se limita a información interna básica y Company Cargo.

### 13.4 Procurement

Hereda Worker.

Puede añadir a la queue:

- procurement exception;
- issued materials pendientes;
- purchase approval dentro de su scope.

No desplaza una Assignment activa. No muestra saldo de Treasury como KPI.

### 13.5 Supervisor

Mantiene las cinco áreas.

Today puede priorizar:

- su trabajo actual;
- Field Attention;
- Assignment bloqueada dentro de su ámbito;
- resultado esperando revisión;
- trabajo sin assignee.

Las acciones de management solo aparecen con permiso explícito.

### 13.6 Manager

Puede recibir:

- Buyer Order deadline;
- application o approval pendiente;
- warehouse exception;
- lease operativo que requiera decisión.

Today no se transforma en un resumen financiero. Treasury se abre desde Company
cuando existe una decisión asociada.

### 13.7 Owner

Hereda Manager y puede recibir:

- permission exception;
- Business Sale pendiente;
- Lease en Grace Period;
- ownership action pendiente.

Business valuation, Treasury balance o staff count no aparecen como KPIs sin una
acción concreta.

### 13.8 Pérdida de permiso en vivo

Si el usuario pierde acceso mientras Today está abierta:

1. se descartan datos privados del store;
2. se cierra drawer o modal;
3. se recalcula navegación;
4. se muestra Restricted o una ruta pública autorizada;
5. no se conserva contenido sensible en el DOM.

---

## 14. Accesibilidad y legibilidad

- Contraste de body text: mínimo 4.5:1 contra su superficie efectiva.
- Contraste de texto grande e iconos esenciales: mínimo 3:1.
- Amarillo nunca es la única señal de estado.
- Status incluye texto e icono cuando aporta significado.
- Target mínimo de mouse: 44 × 44 px.
- Navegación completa con Tab, Shift+Tab, Enter, Space y Escape.
- Focus visible en todos los controles.
- El orden de focus sigue header, Hero y rail.
- Drawer atrapa focus mientras está abierto y lo devuelve al trigger.
- Toasts usan una región aria-live polite.
- Error persistente usa role alert solo al aparecer.
- Los iconos decorativos tienen aria-hidden.
- Los botones tienen nombre accesible igual al copy visible.
- La barra de progreso expone current, total y unit.
- prefers-reduced-motion es obligatorio.

La interfaz no necesita cumplir patrones de móvil, pero sí ser operable sin
precisión extrema del mouse.

---

## 15. Reglas de implementación React y Tailwind

- TypeScript obligatorio.
- Tokens centralizados en CSS variables y Tailwind theme.
- Componentes no contienen colores raw.
- No usar estilos inline salvo valores de progreso y datos geométricos seguros.
- No usar transform scale en el root.
- Root NUI: width 100vw, min-height 100vh, background transparent.
- Usar 100dvh con fallback 100vh si el runtime lo permite.
- Evitar backdrop-filter sobre áreas grandes.
- No crear timers continuos cuando la NUI está cerrada.
- No registrar múltiples listeners al reabrir.
- Limpiar listeners al desmontar.
- Fixtures no se incluyen en producción.
- Fuentes e iconos se empaquetan localmente.
- Los assets visuales finales deben ser aprobados; no usar placeholders como
  resultado final.
- El adapter valida payload antes de entregarlo al view-model.
- Un payload inválido produce error seguro, no un render parcial incoherente.

### 15.1 Formato de fecha

- Fuente: serverDateIso.
- Locale de UI v1: en-GB.
- Header: SATURDAY, 8 AUG 2026.
- Deadline del mismo día: Today, 18:30.
- Deadline del día siguiente: Tomorrow, 09:00.
- Otro día: 12 Aug, 16:00.
- Expired: Expired · 8 Aug, 18:30.

No calcular deadlines críticos únicamente contra el reloj local del PC.

### 15.2 Progreso

Fórmula visual:

- porcentaje = total mayor que 0 ? current / total × 100 : 0;
- clamp entre 0 y 100;
- redondeo visual a dos decimales como máximo;
- texto usa números enteros recibidos;
- verified false sustituye VERIFIED por REPORTED solo si producto lo autoriza.

V1 muestra únicamente progreso verificado.

---

## 16. Criterios de aceptación visual

La implementación visual se aprueba cuando:

1. A 1920 × 1080 reproduce la composición de la captura maestra.
2. El header mide 88 px y conserva la separación Brand–context–nav–date.
3. TODAY y su subtítulo aparecen en la posición y peso definidos.
4. El Hero domina la jerarquía y se ancla a left 58 px, bottom 60 px.
5. El Hero mide 760 × 506 px con tolerancia máxima de 4 px en Reference mode.
6. El rail se ancla al borde derecho del Safe Canvas y muestra tres items.
7. El centro del mundo permanece visualmente libre.
8. El amarillo se limita a tab activo, status relevante, progreso, deadline y
   acciones.
9. Barlow Condensed y Source Sans 3 cargan localmente sin fallback visible.
10. Los iconos son Phosphor y mantienen el mismo peso.
11. Paneles conservan transparencia; no parecen tarjetas blancas ni glass UI.
12. No hay degradados de color decorativos ajenos al sistema.
13. No hay scroll o clipping a 1280 × 720, 1680 × 1050, 1920 × 1080,
    2560 × 1440 y 3440 × 1440.
14. Ultrawide conserva el UI dentro del Safe Canvas.
15. Narrow aspect utiliza Attention Queue drawer sin cubrir permanentemente el
    Hero.
16. Hover, pressed y focus son perceptibles pero breves.
17. Loading, empty, error, restricted y unavailable pertenecen al mismo sistema.
18. Ningún estado introduce KPIs o módulos no definidos.

La comparación principal se realizará con captura a 1672 × 941 y a 1920 × 1080.
La tolerancia geométrica no autoriza cambiar jerarquía, copy o alineación.

---

## 17. Criterios de aceptación funcional

La implementación funcional se aprueba cuando:

1. Today renderiza exclusivamente datos del view model validado.
2. Continue Assignment abre la Assignment correcta una sola vez.
3. View Cargo abre la carga correcta.
4. View Field abre el campo correcto.
5. Today activo no provoca recargas innecesarias.
6. Navegación se filtra por permisos antes de renderizar.
7. Visitor no recibe ni conserva datos privados.
8. Perder permisos en vivo elimina datos y muestra Restricted.
9. Progreso nunca supera 100% ni produce división por cero.
10. Fechas se formatean desde ISO y respetan Today/Tomorrow.
11. Loading no presenta información falsa.
12. Empty conserva prioridades secundarias reales.
13. Error permite retry y cierre.
14. Service unavailable no se presenta como Empty.
15. Fallo parcial del rail no inutiliza el Hero.
16. Busy evita doble envío.
17. Escape cierra drawer/dialog antes de cerrar NUI.
18. Al cerrar, el focus vuelve al juego.
19. Todos los controles son accesibles por teclado.
20. prefers-reduced-motion elimina movimiento no esencial.
21. No quedan listeners, intervals o animaciones activas con la NUI cerrada.
22. No se ejecuta ninguna acción que requiera confirmación desde Today.
23. Texto largo no rompe paneles ni tapa controles.
24. No aparecen rutas futuras, tabs disabled o Coming Soon.

---

## 18. Matriz de validación manual

Ejecutar estos escenarios:

### Worker

- Assignment In Progress con fixture maestro.
- Assignment Blocked by Supplies.
- Assignment Waiting for Approval.
- Sin Assignment, con Company Cargo.
- Sin Assignment ni queue.
- Field unavailable.
- Company Cargo sin permiso.
- Nombre de Assignment largo.
- Progreso 0 of 8.
- Progreso 8 of 8.
- Deadline expired.

### Contractor

- Active Contract en progreso.
- Active Contract bloqueado por materiales propios.
- Contract completed.
- Sin contrato activo.

### Management

- Supervisor con Assignment esperando revisión.
- Manager con Buyer Order deadline.
- Owner con Lease Grace Period.
- Owner sin asuntos accionables.

### Sistema

- Loading.
- Payload inválido.
- Error completo.
- Error parcial del rail.
- Service unavailable.
- Connection lost.
- Cambio de role en vivo.
- Pérdida de permission en vivo.
- Reapertura repetida de NUI.
- Cierre con drawer abierto.

### Resolución

- 1280 × 720.
- 1680 × 1050.
- 1920 × 1080.
- 2560 × 1440.
- 3440 × 1440.
- 1152 × 648.
- aspect ratio inferior a 1.55.

---

## 19. Entregables de la siguiente fase

Después de aprobación, la construcción de Today debe producir:

- shell React + TypeScript;
- configuración Tailwind con tokens;
- fuentes locales;
- Phosphor icons;
- TodayRoute y componentes documentados;
- fixtures para todos los estados;
- adapter frontend simulado, sin fijar backend;
- modo de preview local con BackgroundFixture;
- build NUI transparente para FiveM;
- capturas de validación en las resoluciones obligatorias;
- informe de diferencias frente a la captura maestra.

Solo después de validar y corregir Today se extraen componentes compartidos para:

- Field Detail;
- Assignment Detail;
- Company Cargo;
- otros módulos del Farm Business Hub.

---

## 20. Definition of Done

Today v1 queda lista para expansión cuando:

- este documento está aprobado;
- la implementación pasa todos los criterios visuales y funcionales;
- la captura maestra puede reproducirse con el fixture Worker;
- los estados alternativos no rompen la composición;
- los permisos se aplican antes del render;
- el runtime FiveM mantiene el mundo visible y el focus correcto;
- no existe deuda visual escondida en valores hardcoded de componentes;
- los componentes extraídos conservan el lenguaje Sonar Farm;
- no se ha iniciado Field Detail, Assignment Detail ni minijuegos antes de cerrar
  la validación de Today.
