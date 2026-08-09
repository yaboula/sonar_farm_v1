import type {
  CropPlan,
  FieldDetail,
  FieldDiagnostic,
  FieldEvent,
  FieldOperationalStatus,
  FieldRow,
  FieldSlot,
  PlantState,
} from "../types";

type RowSeed = {
  id: string;
  label: string;
  slotCount?: number;
  crop?: string;
  cropLabel?: string;
  occupied: number;
  plannedCrop?: string;
  plannedLabel?: string;
  water?: number;
  health?: number;
  progress?: number;
  readiness?: PlantState["readiness"];
  assignmentIds?: string[];
  contractIds?: string[];
  materialDemand?: string;
};

type FieldSeed = {
  id: string;
  name: string;
  location: string;
  status: FieldOperationalStatus;
  statusLabel: string;
  ownership: string;
  leaseExpiresAt?: string;
  restriction?: string;
  orientation: number;
  slotsPerRow: number;
  rows: RowSeed[];
  cropSummary: string;
  nextMilestone: string;
  yieldForecast?: string;
  diagnostics: FieldDiagnostic[];
  events: FieldEvent[];
  cropPlans?: CropPlan[];
  linkedWork: FieldDetail["linkedWork"];
  materialNeeds?: FieldDetail["materialNeeds"];
};

const diagnostic = (
  id: string,
  kind: FieldDiagnostic["kind"],
  severity: FieldDiagnostic["severity"],
  scope: FieldDiagnostic["scope"],
  scopeId: string,
  title: string,
  cause: string,
  evidence: string,
  window: string,
  impact: string,
  recommendedAction: string,
  availableAction?: FieldDiagnostic["availableAction"],
): FieldDiagnostic => ({
  id,
  kind,
  severity,
  scope,
  scopeId,
  title,
  cause,
  evidence,
  window,
  impact,
  recommendedAction,
  availableAction,
});

const event = (
  id: string,
  type: FieldEvent["type"],
  at: string,
  actor: string,
  title: string,
  detail: string,
  rowId?: string,
  slotId?: string,
): FieldEvent => ({ id, type, at, actor, title, detail, rowId, slotId });

function makePlant(seed: RowSeed, fieldId: string, rowId: string, column: number): PlantState | undefined {
  if (!seed.crop) return undefined;
  const progress = Math.max(0, Math.min(100, (seed.progress ?? 50) + ((column % 3) - 1) * 3));
  const readiness = seed.readiness ?? (progress >= 96 ? "ready" : "growing");
  return {
    id: `plant-${fieldId}-${rowId}-${String(column + 1).padStart(2, "0")}`,
    crop: seed.crop,
    cropLabel: seed.cropLabel ?? seed.crop,
    stage: readiness === "ready" ? "Mature" : progress >= 65 ? "Developing" : "Established",
    progress,
    water: Math.max(0, Math.min(100, (seed.water ?? 70) + ((column % 4) - 2) * 2)),
    health: Math.max(0, Math.min(100, (seed.health ?? 92) + ((column % 5) - 2))),
    spoilage: readiness === "ready" ? Math.max(0, (column % 4) * 3) : 0,
    plantedAt: "28 Jul, 08:10",
    maturesAt: readiness === "ready" ? "Ready now" : "Tomorrow, 07:40",
    lastCareAt: "Today, 11:24",
    readiness,
  };
}

function buildField(seed: FieldSeed): FieldDetail {
  const slots: FieldSlot[] = [];
  const rowCount = seed.rows.length;
  let legacyIndex = 0;

  const rows: FieldRow[] = seed.rows.map((rowSeed, rowIndex) => {
    const slotCount = rowSeed.slotCount ?? seed.slotsPerRow;
    if (!Number.isInteger(slotCount) || slotCount < 2 || slotCount > 20) {
      throw new Error(`${seed.id}/${rowSeed.id} must define between 2 and 20 slots.`);
    }
    if (rowSeed.occupied < 0 || rowSeed.occupied > slotCount) {
      throw new Error(`${seed.id}/${rowSeed.id} occupied count exceeds its ${slotCount}-slot topology.`);
    }
    const slotIds: string[] = [];
    for (let column = 0; column < slotCount; column += 1) {
      const id = `${seed.id}:${rowSeed.id}:s${String(column + 1).padStart(2, "0")}`;
      slotIds.push(id);
      const occupied = column < rowSeed.occupied;
      const planned = !occupied && Boolean(rowSeed.plannedCrop);
      const plant = occupied ? makePlant(rowSeed, seed.id, rowSeed.id, column) : undefined;
      const diagnosticIds = seed.diagnostics
        .filter((item) => item.scopeId === id || (item.scope === "row" && item.scopeId === rowSeed.id))
        .map((item) => item.id);
      slots.push({
        id,
        legacyIndex: ++legacyIndex,
        rowId: rowSeed.id,
        label: `${rowSeed.label} · Slot ${column + 1}`,
        position: {
          x: 8 + (column * 84) / (slotCount - 1),
          y: rowCount === 1 ? 50 : 8 + (rowIndex * 84) / (rowCount - 1),
        },
        status: occupied ? "occupied" : planned ? "planned" : "empty",
        plant,
        plannedCrop: planned ? rowSeed.plannedCrop : undefined,
        diagnosticIds,
        assignmentId: rowSeed.assignmentIds?.[0],
        contractId: rowSeed.contractIds?.[0],
        visible: true,
      });
    }

    const available = slotCount - rowSeed.occupied - (rowSeed.plannedCrop ? slotCount - rowSeed.occupied : 0);
    const rowDiagnostics = seed.diagnostics.filter((item) => item.scopeId === rowSeed.id);
    const criticalCount = rowDiagnostics.filter((item) => item.severity === "critical").length;
    const readyCount = rowSeed.readiness === "ready" ? rowSeed.occupied : 0;
    return {
      id: rowSeed.id,
      label: rowSeed.label,
      order: rowIndex + 1,
      slotIds,
      plannedCrop: rowSeed.plannedCrop,
      cropLabel: rowSeed.cropLabel ?? rowSeed.plannedLabel ?? "Unassigned",
      occupied: rowSeed.occupied,
      planned: rowSeed.plannedCrop ? slotCount - rowSeed.occupied : 0,
      available: Math.max(0, available),
      averageWater: rowSeed.occupied ? rowSeed.water : undefined,
      averageHealth: rowSeed.occupied ? rowSeed.health : undefined,
      averageGrowth: rowSeed.occupied ? rowSeed.progress : undefined,
      readyCount,
      criticalCount,
      status: criticalCount
        ? "attention"
        : rowSeed.contractIds?.length
          ? "planned"
          : readyCount
            ? "ready"
            : rowSeed.occupied
              ? "growing"
              : rowSeed.plannedCrop
                ? "planned"
                : "empty",
      assignmentIds: rowSeed.assignmentIds ?? [],
      contractIds: rowSeed.contractIds ?? [],
      materialDemand: rowSeed.materialDemand,
      visibleDetail: true,
    };
  });

  const occupied = rows.reduce((sum, row) => sum + row.occupied, 0);
  const planned = rows.reduce((sum, row) => sum + row.planned, 0);
  const criticalCount = seed.diagnostics.filter((item) => item.severity === "critical").length;

  return {
    id: seed.id,
    name: seed.name,
    location: seed.location,
    status: seed.status,
    statusLabel: seed.statusLabel,
    ownership: seed.ownership,
    leaseExpiresAt: seed.leaseExpiresAt,
    restriction: seed.restriction,
    occupied,
    planned,
    capacity: rows.reduce((sum, row) => sum + row.slotIds.length, 0),
    cropSummary: seed.cropSummary,
    attentionCount: seed.diagnostics.length,
    criticalCount,
    activeAssignments: seed.linkedWork.filter((item) => item.kind === "assignment" && item.status !== "Completed").length,
    materialDemand: seed.materialNeeds?.map((item) => item.quantity).join(" · "),
    nextMilestone: seed.nextMilestone,
    yieldForecast: seed.yieldForecast,
    topology: {
      fieldId: seed.id,
      topologyRevision: `${seed.id}-topology-v1`,
      orientation: seed.orientation,
      rows,
      slots,
      bounds: { width: 100, height: 100 },
    },
    diagnostics: seed.diagnostics,
    events: seed.events,
    cropPlans: seed.cropPlans ?? [],
    linkedWork: seed.linkedWork,
    materialNeeds: seed.materialNeeds ?? [],
    serverTime: "2026-08-08T16:32:00+02:00",
    stateRevision: `${seed.id}-state-v1`,
    sequence: 18,
    availableActions: ["create_plan", "create_assignment", "create_contract", "set_route"],
  };
}

const northRows: RowSeed[] = Array.from({ length: 12 }, (_, index) => {
  const number = index + 1;
  const needsWater = number >= 4 && number <= 8;
  const occupied = number <= 10 ? 8 : number === 11 ? 4 : 0;
  return {
    id: `north-r${String(number).padStart(2, "0")}`,
    label: `Row ${number}`,
    crop: occupied ? "tomato" : undefined,
    cropLabel: occupied ? "Tomatoes" : undefined,
    occupied,
    water: needsWater ? (number === 7 ? 24 : 38 + number) : 68,
    health: number === 7 ? 66 : 91,
    progress: 62,
    assignmentIds: needsWater ? ["asg-1048"] : [],
    materialDemand: needsWater ? "Watering Can · assigned" : undefined,
  };
});

const northDiagnostics = [
  diagnostic("diag-north-water", "water_low", "critical", "row", "north-r07", "Row 7 is entering drought stress", "Tomato water decays faster than the current care interval.", "Average water 24% · 8 affected slots", "Safe action window: 1h 20m", "Health loss begins before the Assignment deadline.", "Resume ASG-1048 and water Row 7 first.", "open_assignment"),
  diagnostic("diag-north-r06", "water_low", "warning", "row", "north-r06", "Row 6 needs water", "Water has fallen below the verified operating band.", "Average water 44% · no health loss", "Action recommended today", "Yield is protected if care happens before 18:30.", "Continue ASG-1048 in sequence.", "open_assignment"),
  diagnostic("diag-north-deadline", "work_deadline", "warning", "field", "north-field", "Assignment deadline is approaching", "Five assigned rows are not fully verified.", "ASG-1048 · 3 of 8 checks complete", "Due today, 18:30", "Reserved pay and Buyer Order timing depend on completion.", "Open the active Assignment.", "open_assignment"),
];

const greenhouseRows: RowSeed[] = ["A", "B", "C", "D", "E", "F"].map((letter, index) => ({
  id: `green-r${letter.toLowerCase()}`,
  label: `Row ${letter}`,
  crop: "tomato",
  cropLabel: "Tomatoes",
  occupied: 8,
  water: 73,
  health: 95,
  progress: index === 1 ? 100 : 97,
  readiness: "ready",
  assignmentIds: ["asg-1052"],
}));

const eastRows: RowSeed[] = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"].map((letter, index) => {
  const contractRow = letter === "D";
  const occupied = contractRow ? 0 : index < 8 ? 8 : letter === "I" ? 4 : 0;
  return {
    id: `east-r${letter.toLowerCase()}`,
    label: `Row ${letter}`,
    crop: occupied ? "lettuce" : undefined,
    cropLabel: occupied ? "Lettuce" : undefined,
    occupied,
    plannedCrop: contractRow ? "tomato" : undefined,
    plannedLabel: contractRow ? "Tomatoes" : undefined,
    water: 67,
    health: 93,
    progress: 46,
    contractIds: contractRow ? ["pc-083"] : [],
    materialDemand: contractRow ? "Tomato Seedlings ×8 · contractor supplied" : undefined,
  };
});

const eastPlan: CropPlan = {
  id: "plan-east-d",
  reference: "CP-204",
  fieldId: "east-field",
  rowIds: ["east-rd"],
  crop: "tomato",
  cropLabel: "Tomatoes",
  status: "in_execution",
  statusLabel: "In Execution",
  eligibleSlots: 8,
  excludedSlots: [],
  materialEstimate: ["Tomato Seedlings ×8", "Initial water ×8"],
  linkedContractId: "pc-083",
  createdAt: "Yesterday, 14:20",
  updatedAt: "Today, 15:42",
};

const orchardRows: RowSeed[] = Array.from({ length: 8 }, (_, index) => ({
  id: `orchard-r${String(index + 1).padStart(2, "0")}`,
  label: `Row ${index + 1}`,
  occupied: 0,
}));

const fieldSeeds: FieldSeed[] = [
  {
    id: "north-field",
    name: "North Field",
    location: "Grapeseed · North access gate",
    status: "attention",
    statusLabel: "Needs Attention",
    ownership: "Company owned",
    orientation: 6,
    slotsPerRow: 8,
    rows: northRows,
    cropSummary: "Tomatoes · 11 active Rows",
    nextMilestone: "Watering due today, 18:30",
    yieldForecast: "248–318 units",
    diagnostics: northDiagnostics,
    events: [
      event("evt-north-1", "watered", "Today, 16:21", "Noah Reed", "Row 6 verification recorded", "Eight moisture checks accepted by the farm service.", "north-r06"),
      event("evt-north-2", "work_linked", "Today, 14:05", "Jordan Tate", "ASG-1048 moved in progress", "Rows 4–8 reserved for internal irrigation work."),
      event("evt-north-3", "inspected", "Today, 11:24", "Sofia Bennett", "North Field inspected", "No pest or support conditions recorded."),
    ],
    linkedWork: [
      { id: "asg-1048", kind: "assignment", title: "Water North Field", status: "In Progress", scope: "Rows 4–8" },
      { id: "bo-204", kind: "buyer_order", title: "Paleto Fresh Tomato Order", status: "Accepted", scope: "Forecast demand · 12 crates" },
    ],
    materialNeeds: [{ id: "need-north-water", item: "Watering Cans", quantity: "2 issued", status: "Available" }],
  },
  {
    id: "greenhouse-2",
    name: "Greenhouse 2",
    location: "Grapeseed · Service door",
    status: "ready",
    statusLabel: "Harvest Ready",
    ownership: "Company owned",
    orientation: -4,
    slotsPerRow: 8,
    rows: greenhouseRows,
    cropSummary: "Tomatoes · 6 mature Rows",
    nextMilestone: "Harvest window open now",
    yieldForecast: "168–226 Fine units",
    diagnostics: [
      diagnostic("diag-green-ready", "harvest_ready", "warning", "field", "greenhouse-2", "All six Rows are harvest ready", "Tomatoes reached mature growth and quality is currently stable.", "48 ready plants · 3 showing early spoilage", "Best window: next 4h", "BO-204 requires Fine quality tomorrow morning.", "Begin ASG-1052 before spoilage increases.", "open_assignment"),
      diagnostic("diag-green-spoil", "spoilage_risk", "critical", "row", "green-rb", "Row B quality window is narrowing", "Mature fruit has remained unharvested longer than adjacent Rows.", "Peak spoilage 9% · 3 affected slots", "Critical in 2h 10m", "Fine quality may fall below Buyer Order terms.", "Harvest Row B first.", "open_assignment"),
    ],
    events: [
      event("evt-green-1", "inspected", "Today, 15:10", "Jordan Tate", "Harvest readiness verified", "Fine quality remains achievable across Rows A–F."),
      event("evt-green-2", "work_linked", "Today, 09:00", "Jordan Tate", "ASG-1052 issued", "Harvest scope linked to BO-204."),
    ],
    linkedWork: [
      { id: "asg-1052", kind: "assignment", title: "Harvest Greenhouse 2", status: "Assigned", scope: "Rows A–F" },
      { id: "bo-204", kind: "buyer_order", title: "Paleto Fresh Tomato Order", status: "Accepted", scope: "12 Fine crates" },
    ],
    materialNeeds: [{ id: "need-green-crates", item: "Company Crates", quantity: "12 required", status: "8 available" }],
  },
  {
    id: "east-field",
    name: "East Field",
    location: "Grapeseed · East service track",
    status: "active",
    statusLabel: "Active",
    ownership: "Lease · 12 days left",
    leaseExpiresAt: "20 Aug, 06:00",
    orientation: 18,
    slotsPerRow: 8,
    rows: eastRows,
    cropSummary: "Lettuce · Tomato Row planned",
    nextMilestone: "Contract Row D due today, 20:15",
    yieldForecast: "122–176 lettuce units",
    diagnostics: [
      diagnostic("diag-east-plan", "planned_empty", "warning", "row", "east-rd", "Row D is reserved but remains empty", "CP-204 is in execution under Public Contract PC-083.", "0 of 8 tomato slots established", "Due today, 20:15", "Contract escrow remains reserved until verification.", "Open the active contract or review its progress.", "set_route"),
      diagnostic("diag-east-material", "material_shortage", "info", "row", "east-rd", "Contractor supplies required materials", "Company inventory is not allocated to this contract.", "8 seedlings · hand trowel · watering can", "Before field handoff", "No company procurement cost is expected.", "Confirm contractor materials at the field gate."),
    ],
    events: [
      event("evt-east-1", "work_linked", "Today, 15:42", "Avery Cole", "PC-083 field access opened", "Row D reserved for the active Contractor.", "east-rd"),
      event("evt-east-2", "plan_changed", "Yesterday, 14:20", "Jordan Tate", "CP-204 reserved", "Row D assigned to Tomatoes for contract planting.", "east-rd"),
    ],
    cropPlans: [eastPlan],
    linkedWork: [{ id: "pc-083", kind: "contract", title: "Establish East Field Row D", status: "Active", scope: "Row D · 8 slots" }],
    materialNeeds: [{ id: "need-east-seedlings", item: "Tomato Seedlings", quantity: "8 contractor supplied", status: "Declared" }],
  },
  {
    id: "orchard-annex",
    name: "Orchard Annex",
    location: "Grapeseed · Annex gate",
    status: "grace",
    statusLabel: "Lease Grace Period",
    ownership: "Lease · payment overdue",
    leaseExpiresAt: "Tomorrow, 11:30",
    restriction: "Planting suspended · care and harvest remain permitted",
    orientation: -12,
    slotsPerRow: 8,
    rows: orchardRows,
    cropSummary: "Unassigned · prepared soil",
    nextMilestone: "Grace Period ends in 19h",
    diagnostics: [
      diagnostic("diag-orchard-access", "access_restriction", "critical", "field", "orchard-annex", "Planting is suspended", "The recurring Lease payment entered its 24-hour Grace Period.", "64 empty slots · no active crops", "Resolve before tomorrow, 11:30", "The Lease ends and the Field becomes inaccessible after expiry.", "Resolve the Lease obligation from Company."),
    ],
    events: [event("evt-orchard-1", "restriction_applied", "Today, 11:30", "Farm Service", "Grace Period started", "New planting was suspended for 24 hours.")],
    linkedWork: [],
  },
];

const masterFields = fieldSeeds.map(buildField);

export function cloneFieldFixtures() {
  return structuredClone(masterFields);
}

export function createScaleFieldFixture(size = 20) {
  const rows: RowSeed[] = Array.from({ length: size }, (_, index) => ({
    id: `scale-r${String(index + 1).padStart(2, "0")}`,
    label: `Row ${index + 1}`,
    crop: "potato",
    cropLabel: "Potatoes",
    occupied: size,
    water: 72,
    health: 96,
    progress: 52,
  }));
  return buildField({
    id: "scale-field",
    name: "Scale Field",
    location: "QA topology",
    status: "active",
    statusLabel: "Active",
    ownership: "Company owned",
    orientation: 0,
    slotsPerRow: size,
    rows,
    cropSummary: "Potatoes",
    nextMilestone: "QA only",
    diagnostics: [],
    events: [],
    linkedWork: [],
  });
}

export function createLeasedFieldFixture(fieldId: string, name: string, location: string, capacity: number) {
  const rowCount = Math.max(1, Math.ceil(capacity / 8));
  const rows: RowSeed[] = Array.from({ length: rowCount }, (_, index) => ({
    id: `${fieldId}-r${String(index + 1).padStart(2, "0")}`,
    label: `Row ${index + 1}`,
    cropLabel: "Unassigned",
    occupied: 0,
    slotCount: Math.min(8, Math.max(2, capacity - index * 8)),
    water: 0,
    health: 0,
    progress: 0,
  }));
  return buildField({
    id: fieldId,
    name,
    location,
    status: "empty",
    statusLabel: "Lease Active",
    ownership: "Lease · newly activated",
    orientation: 0,
    slotsPerRow: 8,
    rows,
    cropSummary: "Unassigned · available for planning",
    nextMilestone: "Create the first Crop Plan",
    diagnostics: [],
    events: [event(`evt-${fieldId}-lease`, "access_changed", "Just now", "Farm Service", "Lease access activated", "The Field is now available for planning.")],
    linkedWork: [],
  });
}

export function createMixedSlotFieldFixture() {
  const slotCounts = [2, 7, 20, 4, 13, 6, 18, 3, 11, 9, 5, 16, 8, 14, 10, 19, 12, 17, 15, 2];
  const rows: RowSeed[] = slotCounts.map((slotCount, index) => ({
    id: `mixed-r${String(index + 1).padStart(2, "0")}`,
    label: `Row ${index + 1}`,
    slotCount,
    crop: "tomato",
    cropLabel: "Tomatoes",
    occupied: slotCount,
    water: 72,
    health: 96,
    progress: 52,
  }));
  return buildField({
    id: "mixed-field",
    name: "Mixed Topology Field",
    location: "QA topology",
    status: "active",
    statusLabel: "Active",
    ownership: "Company owned",
    orientation: 0,
    slotsPerRow: 8,
    rows,
    cropSummary: "Tomatoes",
    nextMilestone: "QA only",
    diagnostics: [],
    events: [],
    linkedWork: [],
  });
}
