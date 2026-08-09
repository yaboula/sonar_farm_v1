import { beforeEach, describe, expect, it } from "vitest";
import { ACTOR_BY_ROLE, capabilitiesFor } from "../data/fixtures";
import type { CompanyCargoData, CompanyHomeData, CompanyLease, FarmRole, FieldDetail, FieldsOverviewData, HubContextModel, LedgerEntry, StaffData, TreasurySnapshot, WarehouseData } from "../types";
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

  it("sells only unreserved Warehouse stock and posts one atomic settlement", async () => {
    const owner = context("owner", "warehouse", "tablet");
    const beforeStock = await adapter.load<WarehouseData>({ kind: "companyWarehouse" }, owner);
    const beforeTreasury = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    const draft = await adapter.dispatch({ type: "warehouse.createWholesale", itemId: "wh-lettuce", quantity: 3, quality: "Fine" }, owner);
    const confirmed = await adapter.dispatch({ type: "warehouse.confirmWholesale", saleId: draft.entityId! }, owner);
    const duplicate = await adapter.dispatch({ type: "warehouse.confirmWholesale", saleId: draft.entityId! }, owner);
    const afterStock = await adapter.load<WarehouseData>({ kind: "companyWarehouse" }, owner);
    const afterTreasury = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    const ledger = await adapter.load<LedgerEntry[]>({ kind: "companyLedger" }, owner);
    expect(confirmed.ok).toBe(true);
    expect(duplicate.ok).toBe(false);
    expect(afterStock.data?.items.find((item) => item.id === "wh-lettuce")?.available).toBe((beforeStock.data?.items.find((item) => item.id === "wh-lettuce")?.available ?? 0) - 3);
    expect(afterTreasury.data!.available).toBe(beforeTreasury.data!.available + 435);
    expect(ledger.data?.filter((item) => item.linkedId === draft.entityId)).toHaveLength(1);
    expect(afterStock.data?.reservations).toEqual(beforeStock.data?.reservations);
  });

  it("keeps one active Job Application per character and hires it once", async () => {
    const visitor = context("visitor");
    const manager = context("manager");
    const duplicate = await adapter.dispatch({ type: "jobApplication.submit", input: { introduction: "A replacement statement", availability: "Weekends", preferredWork: "Field logistics", rulesAccepted: true } }, visitor);
    expect(duplicate.ok).toBe(false);
    const accepted = await adapter.dispatch({ type: "staffApplication.transition", applicationId: "app-morgan", action: "accept", role: "worker" }, manager);
    const repeated = await adapter.dispatch({ type: "staffApplication.transition", applicationId: "app-morgan", action: "accept", role: "worker" }, manager);
    const staff = await adapter.load<StaffData>({ kind: "companyStaff" }, manager);
    expect(accepted.ok).toBe(true);
    expect(repeated.ok).toBe(false);
    expect(staff.data?.members.filter((member) => member.id === visitor.actorId)).toHaveLength(1);
  });

  it("requires the invited candidate to accept before Staff access changes", async () => {
    const manager = context("manager");
    const candidate = { ...context("visitor"), actorId: "actor-cameron" };
    const invited = await adapter.dispatch({ type: "staff.invite", candidateId: "actor-cameron", role: "worker" }, manager);
    const before = await adapter.load<StaffData>({ kind: "companyStaff" }, manager);
    const accepted = await adapter.dispatch({ type: "staffInvitation.accept", invitationId: invited.entityId! }, candidate);
    const after = await adapter.load<StaffData>({ kind: "companyStaff" }, manager);
    expect(before.data?.members.some((member) => member.id === "actor-cameron")).toBe(false);
    expect(accepted.contextUpdate?.role).toBe("worker");
    expect(after.data?.members.some((member) => member.id === "actor-cameron")).toBe(true);
  });

  it("protects the Owner and blocks removal while Work or custody remains", async () => {
    const owner = context("owner");
    expect((await adapter.dispatch({ type: "staff.transition", memberId: "staff-elijah", action: "remove" }, owner)).ok).toBe(false);
    expect((await adapter.dispatch({ type: "staff.transition", memberId: "staff-noah", action: "remove" }, owner)).message).toMatch(/Resolve active Work/);
  });

  it("allows only the on-site Owner to contribute without creating withdrawals", async () => {
    const owner = context("owner");
    const remoteOwner = context("owner", "remote", "tablet");
    const manager = context("manager");
    const before = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    expect((await adapter.dispatch({ type: "treasury.contribute", amount: 1000 }, remoteOwner)).ok).toBe(false);
    expect((await adapter.dispatch({ type: "treasury.contribute", amount: 1000 }, manager)).ok).toBe(false);
    const contributed = await adapter.dispatch({ type: "treasury.contribute", amount: 1000 }, owner);
    const after = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    expect(contributed.ok).toBe(true);
    expect(after.data?.available).toBe(before.data!.available + 1000);
    expect(after.data?.personalBalance).toBe(before.data!.personalBalance! - 1000);
    expect((await adapter.load<LedgerEntry[]>({ kind: "companyLedger" }, owner)).data?.[0]).toMatchObject({ type: "owner_contribution", amount: 1000, direction: "credit" });
  });

  it("redacts Procurement Ledger to purchases made by that actor", async () => {
    const procurement = context("procurement");
    const ledger = await adapter.load<LedgerEntry[]>({ kind: "companyLedger" }, procurement);
    expect(ledger.data?.length).toBeGreaterThan(0);
    expect(ledger.data?.every((entry) => entry.type === "purchase" && entry.actorId === procurement.actorId)).toBe(true);
  });

  it("resolves a Lease Grace Period in Treasury, Ledger and Fields together", async () => {
    const owner = context("owner");
    const before = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    const paid = await adapter.dispatch({ type: "lease.transition", leaseId: "lease-orchard", action: "pay" }, owner);
    const lease = await adapter.load<CompanyLease>({ kind: "companyLeaseDetail", leaseId: "lease-orchard" }, owner);
    const field = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "orchard-annex" }, owner);
    const after = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    expect(paid.ok).toBe(true);
    expect(lease.data).toMatchObject({ status: "active", restriction: undefined });
    expect(field.data).toMatchObject({ status: "empty", restriction: undefined });
    expect(after.data?.available).toBe(before.data!.available - 1800);
    expect(after.data?.recentEntries[0]).toMatchObject({ type: "lease", linkedId: "lease-orchard" });
  });

  it("adds newly leased land to Fields and removes access when a Lease ends", async () => {
    const owner = context("owner");
    expect((await adapter.dispatch({ type: "lease.transition", leaseId: "lease-riverside", action: "start" }, owner)).ok).toBe(true);
    const portfolio = await adapter.load<FieldsOverviewData>({ kind: "fieldsOverview" }, owner);
    expect(portfolio.data?.fields.some((field) => field.id === "riverside-patch" && field.capacity === 120)).toBe(true);
    expect((await adapter.dispatch({ type: "lease.transition", leaseId: "lease-east", action: "end" }, owner)).ok).toBe(true);
    const east = await adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId: "east-field" }, owner);
    expect(east.data).toMatchObject({ status: "inaccessible", availableActions: [] });
  });
});
