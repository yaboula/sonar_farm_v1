import { cloneFieldFixtures } from "../data/fieldFixtures";
import type {
  CropPlan,
  CropPlanInput,
  FarmRole,
  FieldDelta,
  FieldDeltaListener,
  FieldDetail,
  FieldOverview,
  FieldScopeRef,
  FieldsOverviewData,
  HubContextModel,
  IntentResult,
} from "../types";

type Subscriber = {
  context: HubContextModel;
  listener: FieldDeltaListener;
};

const MANAGEMENT_ROLES: FarmRole[] = ["supervisor", "manager", "owner"];
const NORTH_ASSIGNED = ["north-r04", "north-r05", "north-r06", "north-r07", "north-r08"];
const GREENHOUSE_ASSIGNED = ["green-ra", "green-rb", "green-rc", "green-rd", "green-re", "green-rf"];
const CONTRACT_ROWS = ["east-rd"];

function assignedRows(role: FarmRole, fieldId: string) {
  if (MANAGEMENT_ROLES.includes(role)) return undefined;
  if (role === "contractor") return fieldId === "east-field" ? CONTRACT_ROWS : [];
  if (["worker", "procurement"].includes(role)) {
    if (fieldId === "north-field") return NORTH_ASSIGNED;
    if (fieldId === "greenhouse-2") return GREENHOUSE_ASSIGNED;
  }
  return [];
}

function isActivePlan(plan: CropPlan) {
  return ["reserved", "in_execution"].includes(plan.status);
}

function scopeIntersects(plan: CropPlan, rowIds: string[]) {
  return plan.rowIds.some((rowId) => rowIds.includes(rowId));
}

export class FieldFixtureRepository {
  private fields = cloneFieldFixtures();
  private planSequence = 205;
  private subscribers = new Map<string, Set<Subscriber>>();

  reset() {
    this.fields = cloneFieldFixtures();
    this.planSequence = 205;
    this.subscribers.clear();
  }

  private overviewOf(field: FieldDetail, context: HubContextModel): FieldOverview {
    const safe: FieldOverview = {
      id: field.id,
      name: field.name,
      location: field.location,
      status: field.status,
      statusLabel: field.statusLabel,
      ownership: field.ownership,
      leaseExpiresAt: field.leaseExpiresAt,
      restriction: field.restriction,
      occupied: field.occupied,
      planned: field.planned,
      capacity: field.capacity,
      cropSummary: field.cropSummary,
      attentionCount: field.attentionCount,
      criticalCount: field.criticalCount,
      activeAssignments: field.activeAssignments,
      nextMilestone: field.nextMilestone,
    };
    if (context.capabilities.viewFieldEconomics) safe.yieldForecast = field.yieldForecast;
    if (context.capabilities.viewFieldMaterialDemand) safe.materialDemand = field.materialDemand;
    const allowed = assignedRows(context.role, field.id);
    if (allowed) safe.permittedRowIds = allowed;
    return safe;
  }

  loadOverview(context: HubContextModel): FieldsOverviewData | null {
    if (!context.capabilities.viewFieldPortfolio) return null;
    const fields = context.role === "contractor"
      ? this.fields.filter((field) => field.id === "east-field")
      : this.fields;
    const landing: FieldsOverviewData["landing"] = context.role === "contractor"
      ? "contract"
      : context.role === "worker"
        ? "assignment"
        : context.role === "procurement"
          ? "materials"
          : "attention";
    const headline = landing === "contract"
      ? "Contract access is limited to East Field · Row D."
      : landing === "assignment"
        ? "ASG-1048 makes North Field · Rows 4–8 your first operating scope."
        : landing === "materials"
          ? "Two active scopes have declared material demand."
          : "Two Fields require a decision before their safe action window closes.";
    const activeScope = landing === "contract"
      ? { fieldId: "east-field", rowIds: CONTRACT_ROWS }
      : landing === "assignment"
        ? { fieldId: "north-field", rowIds: NORTH_ASSIGNED }
        : undefined;
    return { fields: fields.map((field) => this.overviewOf(field, context)), landing, activeScope, headline };
  }

  loadField(fieldId: string, context: HubContextModel): FieldDetail | null | "restricted" {
    if (!context.capabilities.viewFieldPortfolio) return "restricted";
    const field = this.fields.find((item) => item.id === fieldId);
    if (!field) return null;
    if (context.role === "contractor" && fieldId !== "east-field") return "restricted";

    const safe = structuredClone(field);
    const visibleRows = assignedRows(context.role, fieldId);
    if (visibleRows) {
      safe.permittedRowIds = visibleRows;
      safe.topology.rows = safe.topology.rows.map((row) => ({
        ...row,
        visibleDetail: visibleRows.includes(row.id),
      }));
      safe.topology.slots = safe.topology.slots
        .filter((slot) => context.role !== "contractor" || visibleRows.includes(slot.rowId))
        .map((slot) => visibleRows.includes(slot.rowId)
          ? slot
          : { ...slot, visible: false, plant: undefined, diagnosticIds: [], assignmentId: undefined, contractId: undefined });
      safe.diagnostics = safe.diagnostics.filter((item) => item.scope === "field" || visibleRows.includes(item.scopeId) || safe.topology.slots.some((slot) => slot.id === item.scopeId && visibleRows.includes(slot.rowId)));
      safe.events = safe.events.filter((item) => !item.rowId || visibleRows.includes(item.rowId));
      safe.cropPlans = safe.cropPlans.filter((plan) => plan.rowIds.some((rowId) => visibleRows.includes(rowId)));
      safe.linkedWork = safe.linkedWork.filter((item) => context.role !== "contractor" || item.kind === "contract");
    }

    if (!context.capabilities.viewFieldEconomics) safe.yieldForecast = undefined;
    if (!context.capabilities.viewFieldMaterialDemand) {
      safe.materialDemand = undefined;
      safe.materialNeeds = [];
    }
    if (!context.capabilities.viewFieldHistory) safe.events = [];
    const plantingAllowed = !["grace", "planting_suspended", "lease_expired", "inaccessible", "unavailable"].includes(safe.status);
    safe.availableActions = [
      ...(context.capabilities.createCropPlans && plantingAllowed ? ["create_plan" as const] : []),
      ...(context.capabilities.createFieldAssignments ? ["create_assignment" as const] : []),
      ...(context.capabilities.createFieldContracts ? ["create_contract" as const] : []),
      ...(context.capabilities.setFieldRoute ? ["set_route" as const] : []),
    ];
    return safe;
  }

  createPlan(input: CropPlanInput, context: HubContextModel): IntentResult {
    if (!context.capabilities.createCropPlans) return { ok: false, message: "Crop Plan creation is not permitted." };
    const field = this.fields.find((item) => item.id === input.fieldId);
    if (!field || !input.rowIds.length) return { ok: false, message: "Choose at least one valid Row." };
    const rows = field.topology.rows.filter((row) => input.rowIds.includes(row.id));
    if (rows.length !== input.rowIds.length) return { ok: false, message: "One or more Rows are no longer available." };
    if (["grace", "lease_expired", "inaccessible", "planting_suspended"].includes(field.status)) {
      return { ok: false, message: "Planting is suspended for this Field." };
    }
    if (field.cropPlans.some((plan) => isActivePlan(plan) && scopeIntersects(plan, input.rowIds))) {
      return { ok: false, message: "A selected Row is already reserved by an active Crop Plan." };
    }
    const incompatible = rows.find((row) => row.occupied > 0 && row.cropLabel.toLowerCase() !== `${input.crop.toLowerCase()}s` && row.cropLabel.toLowerCase() !== input.crop.toLowerCase());
    if (incompatible) return { ok: false, message: `${incompatible.label} already contains ${incompatible.cropLabel}.` };

    const excludedSlots = field.topology.slots
      .filter((slot) => input.rowIds.includes(slot.rowId) && slot.status === "occupied")
      .map((slot) => ({ slotId: slot.id, reason: "Already occupied" }));
    const eligibleSlots = field.topology.slots.filter((slot) => input.rowIds.includes(slot.rowId) && slot.status === "empty").length;
    if (!eligibleSlots) return { ok: false, message: "The selected Rows have no eligible empty slots." };

    const id = `plan-${this.planSequence++}`;
    const cropLabel = input.crop === "tomato" ? "Tomatoes" : input.crop === "lettuce" ? "Lettuce" : input.crop === "potato" ? "Potatoes" : "Carrots";
    const plan: CropPlan = {
      id,
      reference: `CP-${id.split("-")[1]}`,
      fieldId: field.id,
      rowIds: [...input.rowIds],
      crop: input.crop,
      cropLabel,
      status: "reserved",
      statusLabel: "Reserved",
      eligibleSlots,
      excludedSlots,
      materialEstimate: [`${cropLabel} seedlings ×${eligibleSlots}`, `Initial water ×${eligibleSlots}`],
      createdAt: "Just now",
      updatedAt: "Just now",
    };
    field.cropPlans.unshift(plan);
    for (const row of field.topology.rows.filter((item) => input.rowIds.includes(item.id))) {
      row.plannedCrop = input.crop;
      row.cropLabel = cropLabel;
      row.planned = row.available;
      row.available = 0;
      row.status = "planned";
    }
    for (const slot of field.topology.slots.filter((item) => input.rowIds.includes(item.rowId) && item.status === "empty")) {
      slot.status = "planned";
      slot.plannedCrop = input.crop;
    }
    field.planned += eligibleSlots;
    field.sequence += 1;
    field.stateRevision = `${field.id}-state-${field.sequence}`;
    field.events.unshift({ id: `evt-${id}`, type: "plan_changed", at: "Just now", actor: "Jordan Tate", title: `${plan.reference} reserved`, detail: `${cropLabel} reserved for ${rows.map((row) => row.label).join(", ")}.`, rowId: rows.length === 1 ? rows[0].id : undefined });
    this.emit(field, { kind: "plan_upsert", fieldId: field.id, topologyRevision: field.topology.topologyRevision, sequence: field.sequence, plan });
    return { ok: true, changed: true, entityId: id, invalidated: [field.id], message: `${plan.reference} reserved ${eligibleSlots} planting slots.` };
  }

  updatePlan(planId: string, input: CropPlanInput, context: HubContextModel): IntentResult {
    if (!context.capabilities.createCropPlans) return { ok: false, message: "Crop Plan management is not permitted." };
    const owner = this.fields.find((field) => field.cropPlans.some((plan) => plan.id === planId));
    const plan = owner?.cropPlans.find((item) => item.id === planId);
    if (!owner || !plan || plan.status !== "reserved" || plan.linkedAssignmentId || plan.linkedContractId) {
      return { ok: false, message: "This Crop Plan is locked or no longer available." };
    }
    if (input.fieldId !== owner.id || input.rowIds.join("|") !== plan.rowIds.join("|") || input.crop !== plan.crop) {
      return { ok: false, message: "Changing reserved scope requires cancelling and creating a new Crop Plan." };
    }
    plan.updatedAt = "Just now";
    owner.sequence += 1;
    this.emit(owner, { kind: "plan_upsert", fieldId: owner.id, topologyRevision: owner.topology.topologyRevision, sequence: owner.sequence, plan });
    return { ok: true, changed: true, invalidated: [owner.id], message: `${plan.reference} reviewed with no scope changes.` };
  }

  cancelPlan(planId: string, context: HubContextModel): IntentResult {
    if (!context.capabilities.createCropPlans) return { ok: false, message: "Crop Plan management is not permitted." };
    const field = this.fields.find((item) => item.cropPlans.some((plan) => plan.id === planId));
    const plan = field?.cropPlans.find((item) => item.id === planId);
    if (!field || !plan || plan.status !== "reserved" || plan.linkedAssignmentId || plan.linkedContractId) {
      return { ok: false, message: "This Crop Plan is locked or no longer available." };
    }
    plan.status = "cancelled";
    plan.statusLabel = "Cancelled";
    plan.updatedAt = "Just now";
    for (const row of field.topology.rows.filter((item) => plan.rowIds.includes(item.id))) {
      row.plannedCrop = undefined;
      row.planned = 0;
      row.available = row.slotIds.length - row.occupied;
      row.cropLabel = row.occupied ? row.cropLabel : "Unassigned";
      row.status = row.occupied ? "growing" : "empty";
    }
    for (const slot of field.topology.slots.filter((item) => plan.rowIds.includes(item.rowId) && item.status === "planned")) {
      slot.status = "empty";
      slot.plannedCrop = undefined;
    }
    field.planned = Math.max(0, field.planned - plan.eligibleSlots);
    field.sequence += 1;
    this.emit(field, { kind: "plan_upsert", fieldId: field.id, topologyRevision: field.topology.topologyRevision, sequence: field.sequence, plan });
    return { ok: true, changed: true, invalidated: [field.id], message: `${plan.reference} cancelled and its Rows released.` };
  }

  linkPlanToWork(planId: string, kind: "assignment" | "contract", workId: string) {
    const field = this.fields.find((item) => item.cropPlans.some((plan) => plan.id === planId));
    const plan = field?.cropPlans.find((item) => item.id === planId);
    if (!field || !plan || plan.status !== "reserved") return false;
    plan.status = "in_execution";
    plan.statusLabel = "In Execution";
    plan.updatedAt = "Just now";
    if (kind === "assignment") plan.linkedAssignmentId = workId;
    else plan.linkedContractId = workId;
    field.sequence += 1;
    field.events.unshift({ id: `evt-link-${workId}`, type: "work_linked", at: "Just now", actor: "Jordan Tate", title: `${workId.toUpperCase()} linked`, detail: `${plan.reference} moved into execution.`, rowId: plan.rowIds.length === 1 ? plan.rowIds[0] : undefined });
    this.emit(field, { kind: "plan_upsert", fieldId: field.id, topologyRevision: field.topology.topologyRevision, sequence: field.sequence, plan });
    return true;
  }

  setRoute(scope: FieldScopeRef, context: HubContextModel): IntentResult {
    if (!context.capabilities.setFieldRoute) return { ok: false, message: "Field routing is not permitted." };
    const detail = this.loadField(scope.fieldId, context);
    if (!detail || detail === "restricted") return { ok: false, message: "This Field scope is unavailable." };
    const allowed = detail.permittedRowIds;
    if (allowed && scope.rowIds?.some((rowId) => !allowed.includes(rowId))) return { ok: false, message: "The selected Row is outside your authorized scope." };
    return { ok: true, changed: false, closeSurface: true, handoff: { kind: "route", scope }, message: "Field route prepared for world handoff." };
  }

  subscribe(fieldId: string, _afterSequence: number, context: HubContextModel, listener: FieldDeltaListener) {
    const detail = this.loadField(fieldId, context);
    if (!detail || detail === "restricted") return () => undefined;
    const subscriber = { context, listener };
    const bucket = this.subscribers.get(fieldId) ?? new Set<Subscriber>();
    bucket.add(subscriber);
    this.subscribers.set(fieldId, bucket);
    return () => {
      bucket.delete(subscriber);
      if (!bucket.size) this.subscribers.delete(fieldId);
    };
  }

  private emit(field: FieldDetail, delta: FieldDelta) {
    for (const subscriber of this.subscribers.get(field.id) ?? []) {
      const detail = this.loadField(field.id, subscriber.context);
      if (!detail || detail === "restricted") continue;
      if (delta.kind === "plan_upsert" && detail.permittedRowIds && !delta.plan.rowIds.some((rowId) => detail.permittedRowIds?.includes(rowId))) continue;
      subscriber.listener(structuredClone(delta));
    }
  }
}
