import { beforeEach, describe, expect, it } from "vitest";
import { ACTOR_BY_ROLE, capabilitiesFor } from "../data/fixtures";
import type { BusinessSaleListing, CompanyCargoData, CompanyHomeData, CompanyIdentityTerms, CompanyLease, CompanyProfile, FarmRole, FieldDetail, FieldsOverviewData, HubContextModel, LedgerEntry, RolePolicy, StaffData, TreasurySnapshot, WarehouseData } from "../types";
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

  it("withdraws real Warehouse quantity only at the physical surface", async () => {
    const remote = context("owner", "remote", "tablet");
    const onSite = context("owner", "warehouse", "office");
    const before = await adapter.load<WarehouseData>({ kind: "companyWarehouse" }, onSite);
    const item = before.data!.items[0];
    expect((await adapter.dispatch({ type: "warehouse.withdraw", itemId: item.id, quantity: 1, operationId: crypto.randomUUID() }, remote)).ok).toBe(false);
    expect((await adapter.dispatch({ type: "warehouse.withdraw", itemId: item.id, quantity: 1, operationId: crypto.randomUUID() }, onSite)).ok).toBe(true);
    const after = await adapter.load<WarehouseData>({ kind: "companyWarehouse" }, onSite);
    expect(after.data!.items.find((entry) => entry.id === item.id)?.available).toBe(item.available - 1);
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
    const draft = await adapter.dispatch({ type: "purchase.createDraft", payer: "company", lines: [{ productId: "tomato_seedling", quantity: 1 }] }, owner);
    await adapter.dispatch({ type: "purchase.confirm", purchaseId: draft.entityId! }, owner);
    const after = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    expect(after.data!.available).toBe(before.data!.available - 45);
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

  it("applies role policy losses to stale open contexts and can restore defaults", async () => {
    const owner = context("owner");
    const manager = context("manager");
    const policies = await adapter.load<RolePolicy[]>({ kind: "companyRolePolicies" }, owner);
    const managerPolicy = policies.data!.find((item) => item.role === "manager")!;
    const remaining = managerPolicy.permissions.filter((item) => item.id !== "viewTreasury").map((item) => item.id);
    const saved = await adapter.dispatch({ type: "rolePolicy.save", role: "manager", permissions: remaining, transactionLimit: 5000 }, owner);
    expect(saved.contextUpdate?.capabilitiesRevision).toBeGreaterThan(1);
    expect(adapter.resolveCapabilities("manager", "office").viewTreasury).toBe(false);
    expect((await adapter.load({ kind: "companyTreasury" }, manager)).state).toBe("restricted");
    await adapter.dispatch({ type: "rolePolicy.reset", role: "manager" }, owner);
    expect((await adapter.load({ kind: "companyTreasury" }, manager)).state).toBe("ready");
    expect((await adapter.dispatch({ type: "rolePolicy.save", role: "owner", permissions: [], transactionLimit: undefined }, owner)).ok).toBe(false);
  });

  it("renames only from the Owner Office and posts the fee once with cooldown", async () => {
    const owner = context("owner");
    const manager = context("manager");
    const tabletOwner = context("owner", "remote", "tablet");
    const before = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    expect((await adapter.dispatch({ type: "company.rename", name: "Valley Harvest Co" }, manager)).ok).toBe(false);
    expect((await adapter.dispatch({ type: "company.rename", name: "Valley Harvest Co" }, tabletOwner)).ok).toBe(false);
    expect((await adapter.dispatch({ type: "company.rename", name: "Valley Harvest Co" }, owner)).ok).toBe(true);
    expect((await adapter.dispatch({ type: "company.rename", name: "Second Name" }, owner)).ok).toBe(false);
    const identity = await adapter.load<CompanyIdentityTerms>({ kind: "companyIdentity" }, owner);
    const profile = await adapter.load<CompanyProfile>({ kind: "companyProfile" }, owner);
    const after = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    expect(identity.data).toMatchObject({ currentName: "Valley Harvest Co", available: false });
    expect(profile.data?.company.name).toBe("Valley Harvest Co");
    expect(after.data?.available).toBe(before.data!.available - 2500);
    expect(after.data?.recentEntries[0]).toMatchObject({ type: "rename", amount: 2500 });
  });

  it("reserves buyer funds and completes ownership without partial Company state", async () => {
    const owner = context("owner");
    const buyer = context("visitor", "registry", "tablet");
    const remoteBuyer = context("visitor", "remote", "tablet");
    const beforeTreasury = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, owner);
    const beforeWarehouse = await adapter.load<WarehouseData>({ kind: "companyWarehouse" }, owner);
    const beforeStaff = await adapter.load<StaffData>({ kind: "companyStaff" }, owner);
    await adapter.dispatch({ type: "businessSale.saveDraft", askingPrice: 180000 }, owner);
    expect((await adapter.dispatch({ type: "businessSale.publish", listingId: "sale-001" }, owner)).ok).toBe(true);
    expect((await adapter.dispatch({ type: "businessSale.reserve", listingId: "sale-001" }, remoteBuyer)).ok).toBe(false);
    expect((await adapter.dispatch({ type: "businessSale.reserve", listingId: "sale-001" }, buyer)).ok).toBe(true);
    const reserved = await adapter.load<BusinessSaleListing>({ kind: "companyPublicSale" }, buyer);
    expect(reserved.data).toMatchObject({ status: "reserved", buyerId: buyer.actorId, escrowAmount: 180000 });
    expect((await adapter.dispatch({ type: "businessSale.reserve", listingId: "sale-001" }, { ...buyer, actorId: "actor-cameron" })).ok).toBe(false);
    expect((await adapter.dispatch({ type: "businessSale.confirm", listingId: "sale-001", party: "buyer" }, buyer)).ok).toBe(true);
    const transferred = await adapter.dispatch({ type: "businessSale.confirm", listingId: "sale-001", party: "seller" }, { ...owner, presence: "registry" });
    const buyerAsOwner = { ...owner, actorId: buyer.actorId };
    const afterTreasury = await adapter.load<TreasurySnapshot>({ kind: "companyTreasury" }, buyerAsOwner);
    const afterWarehouse = await adapter.load<WarehouseData>({ kind: "companyWarehouse" }, buyerAsOwner);
    const afterStaff = await adapter.load<StaffData>({ kind: "companyStaff" }, buyerAsOwner);
    const listing = await adapter.load<BusinessSaleListing>({ kind: "companyBusinessSale" }, buyerAsOwner);
    expect(transferred).toMatchObject({ ok: true, contextUpdate: { role: "visitor" } });
    expect(listing.data).toMatchObject({ status: "completed", escrowAmount: 0, buyerId: buyer.actorId });
    expect(afterTreasury.data?.available).toBe(beforeTreasury.data?.available);
    expect(afterWarehouse.data?.items).toEqual(beforeWarehouse.data?.items);
    expect(afterStaff.data?.members).toHaveLength(beforeStaff.data!.members.length);
    expect(afterStaff.data?.members.some((member) => member.id === "staff-elijah")).toBe(false);
    expect(afterStaff.data?.members.some((member) => member.id === buyer.actorId && member.role === "owner")).toBe(true);
    const ledger = await adapter.load<LedgerEntry[]>({ kind: "companyLedger" }, buyerAsOwner);
    expect(ledger.data?.filter((entry) => entry.linkedId === "sale-001")).toHaveLength(2);
  });

  it("refunds buyer escrow when a material listing change forces revalidation", async () => {
    const owner = context("owner");
    const buyer = context("visitor", "registry", "tablet");
    await adapter.dispatch({ type: "businessSale.publish", listingId: "sale-001" }, owner);
    await adapter.dispatch({ type: "businessSale.reserve", listingId: "sale-001" }, buyer);
    await adapter.dispatch({ type: "treasury.contribute", amount: 1000 }, owner);
    const changed = await adapter.load<BusinessSaleListing>({ kind: "companyBusinessSale" }, owner);
    expect(changed.data).toMatchObject({ status: "listing_changed", escrowAmount: 0, buyerId: undefined });
    await adapter.dispatch({ type: "businessSale.cancel", listingId: "sale-001" }, owner);
    await adapter.dispatch({ type: "businessSale.saveDraft", askingPrice: 180000 }, owner);
    await adapter.dispatch({ type: "businessSale.publish", listingId: "sale-001" }, owner);
    expect((await adapter.dispatch({ type: "businessSale.reserve", listingId: "sale-001" }, buyer)).ok).toBe(true);
  });
});
