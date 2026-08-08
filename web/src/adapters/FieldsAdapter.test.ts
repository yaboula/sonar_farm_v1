import { describe, expect, it } from "vitest";
import { capabilitiesFor } from "../data/fixtures";
import { createScaleFieldFixture } from "../data/fieldFixtures";
import type { CropPlan, FieldDetail, FieldsOverviewData, FieldSyncState, HubContextModel } from "../types";
import { FixtureHubAdapter } from "./FixtureHubAdapter";
import { applyFieldDelta, createFieldSyncState } from "./fieldSync";

const context = (role: HubContextModel["role"], surface: HubContextModel["surface"] = "office"): HubContextModel => ({
  role,
  surface,
  viewState: "ready",
  capabilities: capabilitiesFor(role, surface),
});

describe("Fields domain adapter", () => {
  it("builds stable identities for a 20 by 20 field", () => {
    const field = createScaleFieldFixture();
    expect(field.topology.rows).toHaveLength(20);
    expect(field.topology.slots).toHaveLength(400);
    expect(new Set(field.topology.slots.map((slot) => slot.id)).size).toBe(400);
    expect(field.topology.slots[399].id).toBe("scale-field:scale-r20:s20");
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
  });

  it("limits Contractor Fields to the active contract Row", async () => {
    const adapter = new FixtureHubAdapter(0);
    const overview = await adapter.load<FieldsOverviewData>({ kind: "fieldsOverview" }, context("contractor"));
    const field = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "east-field" }, context("contractor"));
    const denied = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "north-field" }, context("contractor"));
    expect(overview.data?.fields.map((item) => item.id)).toEqual(["east-field"]);
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
});
