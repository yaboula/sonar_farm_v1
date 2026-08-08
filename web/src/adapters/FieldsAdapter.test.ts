import { describe, expect, it } from "vitest";
import { ACTOR_BY_ROLE, capabilitiesFor } from "../data/fixtures";
import { createMixedSlotFieldFixture, createScaleFieldFixture } from "../data/fieldFixtures";
import type { CropPlan, FieldDetail, FieldsOverviewData, FieldSyncState, HubContextModel } from "../types";
import { FixtureHubAdapter } from "./FixtureHubAdapter";
import { applyFieldDelta, createFieldSyncState, projectFieldDelta } from "./fieldSync";

const context = (role: HubContextModel["role"], surface: HubContextModel["surface"] = "office"): HubContextModel => ({
  actorId: ACTOR_BY_ROLE[role],
  role,
  surface,
  presence: surface === "office" ? "office" : "remote",
  capabilitiesRevision: 1,
  viewState: "ready",
  capabilities: capabilitiesFor(role, surface),
});

describe("Fields domain adapter", () => {
  it("builds stable identities for a 20 by 20 field", () => {
    const field = createScaleFieldFixture();
    const secondProjection = createScaleFieldFixture();
    expect(field.topology.rows).toHaveLength(20);
    expect(field.topology.slots).toHaveLength(400);
    expect(new Set(field.topology.slots.map((slot) => slot.id)).size).toBe(400);
    expect(field.topology.slots[399].id).toBe("scale-field:scale-r20:s20");
    expect(field.topology.slots.map((slot) => slot.position)).toEqual(secondProjection.topology.slots.map((slot) => slot.position));
    expect(field.topology.slots.every((slot) => slot.position.x >= 0 && slot.position.x <= 100 && slot.position.y >= 0 && slot.position.y <= 100)).toBe(true);
  });

  it("supports an independent deterministic 2-to-20 slot topology per Row", () => {
    const field = createMixedSlotFieldFixture();
    const counts = field.topology.rows.map((row) => row.slotIds.length);
    expect(counts).toEqual([2, 7, 20, 4, 13, 6, 18, 3, 11, 9, 5, 16, 8, 14, 10, 19, 12, 17, 15, 2]);
    expect(field.capacity).toBe(counts.reduce((total, count) => total + count, 0));
    expect(field.topology.slots).toHaveLength(field.capacity);
    expect(new Set(field.topology.slots.map((slot) => slot.id)).size).toBe(field.capacity);
    expect(field.topology.slots.map((slot) => slot.legacyIndex)).toEqual(Array.from({ length: field.capacity }, (_, index) => index + 1));
  });

  it("adapts the portfolio landing to role", async () => {
    const adapter = new FixtureHubAdapter(0);
    const worker = await adapter.load<FieldsOverviewData>({ kind: "fieldsOverview" }, context("worker"));
    const procurement = await adapter.load<FieldsOverviewData>({ kind: "fieldsOverview" }, context("procurement"));
    const owner = await adapter.load<FieldsOverviewData>({ kind: "fieldsOverview" }, context("owner"));
    expect(worker.data?.landing).toBe("assignment");
    expect(procurement.data?.landing).toBe("materials");
    expect(owner.data?.landing).toBe("attention");
  });

  it("redacts unassigned slot detail from a Worker", async () => {
    const adapter = new FixtureHubAdapter(0);
    const model = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "north-field" }, context("worker"));
    const assigned = model.data?.topology.slots.find((slot) => slot.rowId === "north-r04");
    const privateSlot = model.data?.topology.slots.find((slot) => slot.rowId === "north-r01");
    expect(assigned?.plant).toBeDefined();
    expect(privateSlot?.visible).toBe(false);
    expect(privateSlot?.plant).toBeUndefined();
    expect(model.data?.yieldForecast).toBeUndefined();
    expect(model.data?.criticalCount).toBeGreaterThanOrEqual(model.data?.topology.rows.reduce((total, row) => total + row.criticalCount, 0) ?? 0);
  });

  it("limits Contractor Fields to the active contract Row", async () => {
    const adapter = new FixtureHubAdapter(0);
    const overview = await adapter.load<FieldsOverviewData>({ kind: "fieldsOverview" }, context("contractor"));
    const field = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "east-field" }, context("contractor"));
    const denied = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "north-field" }, context("contractor"));
    expect(overview.data?.fields.map((item) => item.id)).toEqual(["east-field"]);
    expect(overview.data?.fields[0]).toMatchObject({ capacity: 8, occupied: 0, planned: 8, ownership: "Company Field · Contract access" });
    expect(field.data?.topology.rows.map((row) => row.id)).toEqual(["east-rd"]);
    expect(field.data?.topology.rows.filter((row) => row.visibleDetail).map((row) => row.id)).toEqual(["east-rd"]);
    expect(field.data?.topology.slots.every((slot) => slot.rowId === "east-rd")).toBe(true);
    expect(denied.state).toBe("restricted");
  });

  it("reserves Rows exclusively and emits an ordered delta", async () => {
    const adapter = new FixtureHubAdapter(0);
    const owner = context("owner");
    const before = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "north-field" }, owner);
    const deltas: number[] = [];
    const unsubscribe = adapter.subscribeField("north-field", before.data!.sequence, owner, (delta) => deltas.push(delta.sequence));
    const created = await adapter.dispatch({ type: "cropPlan.create", input: { fieldId: "north-field", rowIds: ["north-r12"], crop: "tomato" } }, owner);
    const duplicate = await adapter.dispatch({ type: "cropPlan.create", input: { fieldId: "north-field", rowIds: ["north-r12"], crop: "tomato" } }, owner);
    unsubscribe();
    expect(created.ok).toBe(true);
    expect(duplicate.ok).toBe(false);
    expect(deltas).toEqual([before.data!.sequence + 1]);
  });

  it("links a reserved Crop Plan to stable Assignment scope", async () => {
    const adapter = new FixtureHubAdapter(0);
    const owner = context("owner");
    const created = await adapter.dispatch({ type: "cropPlan.create", input: { fieldId: "north-field", rowIds: ["north-r12"], crop: "tomato" } }, owner);
    const assignment = await adapter.dispatch({
      type: "assignment.create",
      input: {
        title: "Plant North Row 12",
        objective: "Execute the reserved tomato Crop Plan.",
        fieldId: "north-field",
        crop: "Tomatoes",
        scope: "Row 12",
        scopeRef: { fieldId: "north-field", rowIds: ["north-r12"] },
        sourcePlanId: created.entityId,
        assigneeId: "staff-noah",
        supervisorId: "staff-jordan",
        deadline: "Tomorrow, 18:00",
        payout: 240,
        requirement: "Verify all eligible slots",
        materialIds: ["tomato-seedling"],
      },
    }, owner);
    const field = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "north-field" }, owner);
    const plan = field.data?.cropPlans.find((item) => item.id === created.entityId);
    expect(assignment.ok).toBe(true);
    expect(plan).toMatchObject({ status: "in_execution", linkedAssignmentId: assignment.entityId, rowIds: ["north-r12"] });
    expect((await adapter.dispatch({ type: "cropPlan.cancel", planId: created.entityId! }, owner)).ok).toBe(false);
  });

  it("edits an unlinked reserved Crop Plan and releases its previous scope", async () => {
    const adapter = new FixtureHubAdapter(0);
    const owner = context("owner");
    const created = await adapter.dispatch({ type: "cropPlan.create", input: { fieldId: "north-field", rowIds: ["north-r12"], crop: "tomato" } }, owner);
    const updated = await adapter.dispatch({ type: "cropPlan.update", planId: created.entityId!, input: { fieldId: "north-field", rowIds: ["north-r11"], crop: "tomato" } }, owner);
    const field = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "north-field" }, owner);
    const plan = field.data?.cropPlans.find((item) => item.id === created.entityId);
    expect(updated.ok).toBe(true);
    expect(plan).toMatchObject({ rowIds: ["north-r11"], eligibleSlots: 4, status: "reserved" });
    expect(field.data?.topology.rows.find((row) => row.id === "north-r12")).toMatchObject({ planned: 0, available: 8, status: "empty" });
    expect(field.data?.topology.rows.find((row) => row.id === "north-r11")).toMatchObject({ planned: 4, available: 0, status: "planned" });
  });

  it("requests resync for gaps and topology changes while ignoring duplicates", () => {
    const field = createScaleFieldFixture(2);
    const initial = createFieldSyncState(field);
    const plan: CropPlan = { id: "cp", reference: "CP-1", fieldId: field.id, rowIds: ["scale-r01"], crop: "potato", cropLabel: "Potatoes", status: "reserved", statusLabel: "Reserved", eligibleSlots: 2, excludedSlots: [], materialEstimate: [], createdAt: "Now", updatedAt: "Now" };
    const accepted = applyFieldDelta(initial, { kind: "plan_upsert", fieldId: field.id, topologyRevision: initial.topologyRevision, sequence: initial.sequence + 1, plan });
    const duplicate = applyFieldDelta(accepted, { kind: "plan_upsert", fieldId: field.id, topologyRevision: initial.topologyRevision, sequence: initial.sequence + 1, plan });
    const gap = applyFieldDelta(duplicate, { kind: "plan_upsert", fieldId: field.id, topologyRevision: initial.topologyRevision, sequence: initial.sequence + 3, plan });
    expect(accepted.plans.cp).toBeDefined();
    expect(duplicate).toBe(accepted);
    expect(gap.resyncRequired).toBe(true);
    const mismatch: FieldSyncState = applyFieldDelta(initial, { kind: "plan_upsert", fieldId: field.id, topologyRevision: "v2", sequence: initial.sequence + 1, plan });
    expect(mismatch.resyncRequired).toBe(true);
  });

  it("projects accepted deltas without rebuilding stable topology", async () => {
    const adapter = new FixtureHubAdapter(0);
    const owner = context("owner");
    const model = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "north-field" }, owner);
    const detail = model.data!;
    const slot = structuredClone(detail.topology.slots[0]);
    slot.plant = slot.plant ? { ...slot.plant, water: 91 } : slot.plant;
    const projected = projectFieldDelta(detail, { kind: "slot_upsert", fieldId: detail.id, topologyRevision: detail.topology.topologyRevision, sequence: detail.sequence + 1, slot });
    expect(projected.topology.rows).toBe(detail.topology.rows);
    expect(projected.topology.slots.find((item) => item.id === slot.id)?.plant?.water).toBe(91);
    expect(projected.sequence).toBe(detail.sequence + 1);
  });
});
