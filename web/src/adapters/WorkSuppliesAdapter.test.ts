import { beforeEach, describe, expect, it } from "vitest";
import { ACTOR_BY_ROLE, capabilitiesFor } from "../data/fixtures";
import type { BuyerOrderDetail, ContractDetail, FarmRole, FieldDetail, HubContextModel, PurchaseReview, SuppliesHubData, WorkQueueData } from "../types";
import { FixtureHubAdapter } from "./FixtureHubAdapter";

function context(role: FarmRole, surface: "office" | "tablet" = "office"): HubContextModel {
  return { actorId: ACTOR_BY_ROLE[role], role, surface, presence: surface === "office" ? "office" : "remote", capabilitiesRevision: 1, viewState: "ready", capabilities: capabilitiesFor(role, surface) };
}

describe("FixtureHubAdapter Work and Supplies", () => {
  let adapter: FixtureHubAdapter;
  beforeEach(() => { adapter = new FixtureHubAdapter(0); });

  it("derives Work areas and data for every role", async () => {
    const visitor = await adapter.load<WorkQueueData>({ kind: "hub", route: "work" }, context("visitor"));
    const worker = await adapter.load<WorkQueueData>({ kind: "hub", route: "work" }, context("worker"));
    const owner = await adapter.load<WorkQueueData>({ kind: "hub", route: "work" }, context("owner"));
    const contractor = await adapter.load<WorkQueueData>({ kind: "hub", route: "work" }, context("contractor"));
    expect(visitor.data?.areas).toEqual(["publicContracts"]);
    expect(visitor.data?.items.every((item) => item.type === "contract")).toBe(true);
    expect(worker.data?.areas).toEqual(["assignments"]);
    expect(worker.data?.items.every((item) => item.assigneeId === "staff-noah")).toBe(true);
    expect(owner.data?.areas).toEqual(["assignments", "buyerOrders", "publicContracts"]);
    expect(contractor.data?.areas).toEqual(["activeContract"]);
  });

  it("creates an Assignment and immediately exposes its detail", async () => {
    const result = await adapter.dispatch({ type: "assignment.create", input: { title: "Water East Rows", objective: "Restore moisture.", fieldId: "north-field", crop: "Tomatoes", scope: "Rows 9–12", assigneeId: "staff-noah", supervisorId: "staff-jordan", deadline: "Tomorrow, 18:00", payout: 220, requirement: "Verify four rows", materialIds: ["watering-can"] } }, context("supervisor"));
    expect(result.ok).toBe(true);
    const detail = await adapter.load({ kind: "assignmentDetail", assignmentId: result.entityId! }, context("worker"));
    expect(detail.state).toBe("ready");
    expect(detail.data).toMatchObject({ title: "Water East Rows", status: "assigned" });
  });

  it("drives a Buyer Order through authorized transitions", async () => {
    for (const action of ["accept", "plan", "reserve", "prepare", "complete"] as const) {
      expect((await adapter.dispatch({ type: "buyerOrder.transition", orderId: "bo-211", action }, context("manager"))).ok).toBe(true);
    }
    const detail = await adapter.load<BuyerOrderDetail>({ kind: "buyerOrderDetail", orderId: "bo-211" }, context("owner"));
    expect(detail.data?.status).toBe("completed");
    expect(detail.data?.availableActions).toEqual([]);
  });

  it("reserves a public Contract once and returns a role context update", async () => {
    const first = await adapter.dispatch({ type: "contract.accept", contractId: "pc-078" }, context("visitor"));
    const second = await adapter.dispatch({ type: "contract.accept", contractId: "pc-078" }, context("visitor"));
    expect(first).toMatchObject({ ok: true, contextUpdate: { role: "contractor" } });
    expect(second.ok).toBe(false);
    const active = await adapter.load<ContractDetail>({ kind: "contractDetail", contractId: "pc-078", mode: "active" }, context("contractor"));
    expect(active.data?.status).toBe("active");
  });

  it("verifies Contractor steps without allowing premature submission", async () => {
    const premature = await adapter.dispatch({ type: "contract.transition", contractId: "pc-083", action: "submit" }, context("contractor"));
    expect(premature.ok).toBe(false);
    for (const stepId of ["prepare", "plant", "water"] as const) {
      const contract = await adapter.load<ContractDetail>({ kind: "contractDetail", contractId: "pc-083", mode: "progress" }, context("contractor"));
      if (!contract.data?.steps.find((step) => step.id === stepId)?.completed) expect((await adapter.dispatch({ type: "contract.verifyStep", contractId: "pc-083", stepId }, context("contractor"))).ok).toBe(true);
    }
    expect((await adapter.dispatch({ type: "contract.transition", contractId: "pc-083", action: "submit" }, context("contractor"))).ok).toBe(true);
  });

  it("removes temporary Contractor access after abandonment", async () => {
    const result = await adapter.dispatch({ type: "contract.transition", contractId: "pc-083", action: "abandon" }, context("contractor"));
    expect(result).toMatchObject({ ok: true, contextUpdate: { role: "visitor" } });
    const denied = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "east-field" }, context("visitor"));
    expect(denied.state).toBe("restricted");
  });

  it("keeps Tablet purchase confirmation read-only and completes at Office", async () => {
    const draft = await adapter.dispatch({ type: "purchase.createDraft", payer: "personal", lines: [{ productId: "tomato-seedling", quantity: 2 }] }, context("visitor", "tablet"));
    const tablet = await adapter.dispatch({ type: "purchase.confirm", purchaseId: draft.entityId! }, context("visitor", "tablet"));
    expect(tablet).toMatchObject({ ok: false, closeSurface: true });
    const before = await adapter.load<PurchaseReview>({ kind: "purchaseReview", purchaseId: draft.entityId! }, context("visitor", "office"));
    expect(before.data?.status).toBe("draft");
    expect((await adapter.dispatch({ type: "purchase.confirm", purchaseId: draft.entityId! }, context("visitor", "office"))).ok).toBe(true);
    const after = await adapter.load<PurchaseReview>({ kind: "purchaseReview", purchaseId: draft.entityId! }, context("visitor", "office"));
    expect(after.data?.status).toBe("completed");
    expect(after.data?.receiptId).toBeTruthy();
  });

  it("protects company procurement and resolves custody actions", async () => {
    const visitor = await adapter.load<SuppliesHubData>({ kind: "hub", route: "supplies" }, context("visitor"));
    const owner = await adapter.load<SuppliesHubData>({ kind: "hub", route: "supplies" }, context("owner"));
    expect(visitor.data?.allowedPayers).toEqual(["personal"]);
    expect(visitor.data?.procurement).toBeUndefined();
    expect(owner.data?.allowedPayers).toEqual(["personal", "company"]);
    expect((await adapter.dispatch({ type: "procurement.resolve", requestId: "pr-031", decision: "approve" }, context("owner"))).ok).toBe(true);
    expect((await adapter.dispatch({ type: "issuedMaterial.transition", materialId: "issue-118", action: "return" }, context("procurement"))).ok).toBe(true);
  });
});
