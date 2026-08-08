import { beforeEach, describe, expect, it } from "vitest";
import { ACTOR_BY_ROLE, capabilitiesFor } from "../data/fixtures";
import type { CompanyCargoData, CompanyHomeData, FarmRole, HubContextModel, TreasurySnapshot, WarehouseData } from "../types";
import { FixtureHubAdapter } from "./FixtureHubAdapter";

function context(role: FarmRole, presence: HubContextModel["presence"] = "office", surface: HubContextModel["surface"] = "office"): HubContextModel {
  return { actorId: ACTOR_BY_ROLE[role], role, surface, presence, capabilitiesRevision: 1, viewState: "ready", capabilities: capabilitiesFor(role, surface) };
}

describe("Company domain adapter", () => {
  let adapter: FixtureHubAdapter;
  beforeEach(() => { adapter = new FixtureHubAdapter(0); });

  it("derives a role-adaptive Company Home without leaking finance", async () => {
    const visitor = await adapter.load<CompanyHomeData>({ kind: "companyHome" }, context("visitor"));
    const worker = await adapter.load<CompanyHomeData>({ kind: "companyHome" }, context("worker"));
    const owner = await adapter.load<CompanyHomeData>({ kind: "companyHome" }, context("owner"));
    expect(visitor.data?.modules.map((item) => item.id)).toEqual(expect.arrayContaining(["profile", "application"]));
    expect(visitor.data?.modules.some((item) => item.id === "treasury")).toBe(false);
    expect(worker.data?.modules.map((item) => item.id)).toEqual(expect.arrayContaining(["profile", "cargo"]));
    expect(owner.data?.modules.map((item) => item.area)).toEqual(expect.arrayContaining(["operations", "people", "finance", "ownership"]));
  });

  it("limits cargo to the current custodian unless team access is granted", async () => {
    const worker = await adapter.load<CompanyCargoData>({ kind: "companyCargo" }, context("worker"));
    const contractor = await adapter.load<CompanyCargoData>({ kind: "companyCargo" }, context("contractor"));
    const supervisor = await adapter.load<CompanyCargoData>({ kind: "companyCargo" }, context("supervisor"));
    expect(worker.data?.records.map((item) => item.custodianId)).toEqual(["staff-noah"]);
    expect(contractor.data?.records.map((item) => item.custodianId)).toEqual(["actor-avery"]);
    expect(supervisor.data?.records.length).toBeGreaterThan(1);
  });

  it("separates UI surface from physical Warehouse presence", async () => {
    const remote = await adapter.load<WarehouseData>({ kind: "companyWarehouse" }, context("owner", "remote", "tablet"));
    const onSite = await adapter.load<WarehouseData>({ kind: "companyWarehouse" }, context("owner", "warehouse", "tablet"));
    expect(remote.data?.atWarehouse).toBe(false);
    expect(onSite.data?.atWarehouse).toBe(true);
  });

  it("keeps Owner-only governance away from Manager", async () => {
    const manager = context("manager");
    expect(manager.capabilities.manageRolePolicies).toBe(false);
    expect(manager.capabilities.renameCompany).toBe(false);
    expect(manager.capabilities.sellBusiness).toBe(false);
    expect((await adapter.load({ kind: "companyRolePolicies" }, manager)).state).toBe("restricted");
  });

  it("uses Treasury as the shared company purchase balance", async () => {
    const owner = context("owner");
    const before = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    const draft = await adapter.dispatch({ type: "purchase.createDraft", payer: "company", lines: [{ productId: "tomato-seedling", quantity: 1 }] }, owner);
    await adapter.dispatch({ type: "purchase.confirm", purchaseId: draft.entityId! }, owner);
    const after = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    expect(after.data!.available).toBe(before.data!.available - 18);
    expect(after.data?.recentEntries[0]).toMatchObject({ type: "purchase", linkedId: draft.entityId });
  });
});
