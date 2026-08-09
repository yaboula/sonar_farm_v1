import { ACTOR_BY_ROLE, capabilitiesFor } from "../data/fixtures";
import { createCompanyFixtureState, type CompanyFixtureState } from "../data/companyFixtures";
import type {
  CompanyCargoData,
  CompanyHomeData,
  CompanyHomeModule,
  CompanyLease,
  CompanyProfile,
  FarmRole,
  HubContextModel,
  HubCapabilities,
  HubSurface,
  IntentResult,
  JobApplicationInput,
  LedgerEntry,
  OwnershipTransfer,
  RolePolicy,
  StaffApplication,
  StaffData,
  StaffMember,
  TreasurySnapshot,
  WarehouseData,
} from "../types";

const now = () => "Today, 16:32";
const clone = <T,>(value: T): T => structuredClone(value);

export class CompanyFixtureRepository {
  private state: CompanyFixtureState = createCompanyFixtureState();
  private ledgerSequence = 411;
  private saleSequence = 2;
  private applicationSequence = 3;
  private invitationSequence = 1;
  private wholesaleSequence = 1;

  reset() {
    this.state = createCompanyFixtureState();
    this.ledgerSequence = 411;
    this.saleSequence = 2;
    this.applicationSequence = 3;
    this.invitationSequence = 1;
    this.wholesaleSequence = 1;
  }

  getCompanyBalance() { return this.state.treasury.available; }
  getProcurementBudget() { return this.state.treasury.procurementBudget; }
  getPersonalBalance(actorId: string) { return this.state.personalBalances[actorId] ?? 0; }
  getCapabilitiesRevision() { return this.state.company.capabilitiesRevision; }
  resolveCapabilities(role: FarmRole, surface: HubSurface): HubCapabilities {
    const capabilities = capabilitiesFor(role, surface);
    const policy = this.state.rolePolicies.find((item) => item.role === role);
    if (!policy || role === "owner") return capabilities;
    for (const permission of policy.permissions) {
      if (permission.id in capabilities) (capabilities as unknown as Record<string, unknown>)[permission.id] = permission.enabled;
    }
    return capabilities;
  }
  getLeaseSnapshot(leaseId: string) { return clone(this.state.leases.find((item) => item.id === leaseId)); }
  debitPersonal(actorId: string, amount: number) {
    if (amount <= 0 || this.getPersonalBalance(actorId) < amount) return false;
    this.state.personalBalances[actorId] -= amount;
    return true;
  }

  loadHome(context: HubContextModel): CompanyHomeData {
    const modules: CompanyHomeModule[] = [{ id: "profile", area: "public", title: "Company Profile", detail: "Public identity and opportunities", value: this.state.company.status === "operating" ? "Operating" : "For Sale", path: "/company/profile", priority: "normal" }];
    const cargo = this.safeCargo(context);
    if (context.capabilities.viewOwnCompanyCargo && cargo.length) modules.push({ id: "cargo", area: "operations", title: "Company Cargo", detail: "Produce currently in custody", value: `${cargo.reduce((sum, item) => sum + item.quantity, 0)} units`, path: "/company/cargo", priority: cargo.some((item) => item.status === "mismatch") ? "critical" : "attention", badge: cargo.some((item) => item.status === "mismatch") ? "Mismatch" : "Deposit due" });
    if (context.capabilities.viewWarehouse) modules.push({ id: "warehouse", area: "operations", title: "Warehouse", detail: "Stock, reservations and incoming cargo", value: `${this.state.warehouseItems.reduce((sum, item) => sum + item.total, 0)} items`, path: "/company/warehouse", priority: this.state.warehouseItems.some((item) => item.status === "discrepancy") ? "attention" : "normal", badge: "1 discrepancy" });
    if (context.capabilities.viewStaff) modules.push({ id: "staff", area: "people", title: "Staff", detail: "Members, applications and invitations", value: `${this.state.staff.filter((item) => item.status === "active").length} active`, path: "/company/staff", priority: this.state.applications.some((item) => item.status === "submitted") ? "attention" : "normal", badge: `${this.state.applications.filter((item) => ["submitted", "under_review"].includes(item.status)).length} pending` });
    if (context.capabilities.viewTreasury) modules.push({ id: "treasury", area: "finance", title: "Treasury", detail: "Available and committed company funds", value: `$${this.state.treasury.available.toLocaleString()}`, path: "/company/treasury", priority: "normal" });
    if (context.capabilities.viewCompanyLedger || context.capabilities.viewProcurementLedger) modules.push({ id: "ledger", area: "finance", title: "Transaction Ledger", detail: "Immutable business movements", value: `${this.safeLedger(context).length} entries`, path: "/company/ledger", priority: "normal" });
    if (context.capabilities.viewLeases) {
      const grace = this.state.leases.filter((item) => item.status === "grace").length;
      modules.push({ id: "leases", area: "finance", title: "Leases", detail: "Land access and recurring obligations", value: `${this.state.leases.filter((item) => ["starter", "active", "grace"].includes(item.status)).length} operated`, path: "/company/leases", priority: grace ? "critical" : "normal", badge: grace ? `${grace} Grace Period` : undefined });
    }
    if (context.capabilities.manageRolePolicies) modules.push({ id: "roles", area: "ownership", title: "Roles & Permissions", detail: "Role templates and audited exceptions", value: "7 roles", path: "/company/roles", priority: "normal" });
    if (context.capabilities.renameCompany) modules.push({ id: "identity", area: "ownership", title: "Company Identity", detail: "Name, cost and cooldown", value: this.state.company.name, path: "/company/identity", priority: "normal" });
    if (context.capabilities.sellBusiness) modules.push({ id: "sale", area: "ownership", title: "Business Sale", detail: "Assets, obligations and ownership transfer", value: this.state.listing.status === "draft" ? "Draft" : this.state.listing.status, path: "/company/sale", priority: ["reserved", "awaiting_seller", "listing_changed"].includes(this.state.listing.status) ? "critical" : "normal", badge: this.state.listing.status === "awaiting_seller" ? "Seller confirmation" : undefined });
    if (context.role === "visitor") {
      modules.push({ id: "application", area: "people", title: "Job Application", detail: "Apply for verified farming work", value: this.ownApplication(context)?.status ?? "Open", path: "/company/jobs/apply", priority: "normal" });
      if (["published", "reserved", "awaiting_seller"].includes(this.state.listing.status)) modules.push({ id: "public-sale", area: "ownership", title: "Business for Sale", detail: "Review the complete company listing", value: `$${this.state.listing.askingPrice.toLocaleString()}`, path: "/company/business-for-sale", priority: "attention" });
    }
    return { company: clone(this.state.company), headline: this.headline(context, modules), modules, procurementLink: context.capabilities.companyProcurement ? { remaining: this.state.treasury.procurementBudget, pending: 2, path: "/supplies?area=procurement" } : undefined };
  }

  loadProfile(context: HubContextModel): CompanyProfile {
    const canSeeSale = ["published", "reserved", "awaiting_seller"].includes(this.state.listing.status);
    return { company: clone(this.state.company), ownershipLabel: this.state.company.ownerName ? `Player operated · Owner ${this.state.company.ownerName}` : "Initial sale · No current Owner", publicFields: [{ name: "North Field", cropSummary: "Tomatoes", status: "Operating" }, { name: "Greenhouse 2", cropSummary: "Tomatoes", status: "Harvest Ready" }, { name: "East Field", cropSummary: "Mixed production", status: "Operating" }], publicContracts: 2, applicationsOpen: true, contractorTerms: ["Contractors supply their own materials", "Field access is limited to the reserved scope", "Rewards remain funded through escrow"], sale: canSeeSale ? { listingId: this.state.listing.id, askingPrice: this.state.listing.askingPrice, status: this.state.listing.status } : undefined, availableActions: ["contracts", ...(canSeeSale ? ["sale" as const] : []), ...(context.role === "visitor" ? ["apply" as const] : []), "supplies", "route"] };
  }

  loadCargo(context: HubContextModel): CompanyCargoData {
    return { records: clone(this.safeCargo(context)), scopeLabel: context.capabilities.viewTeamCompanyCargo ? "Company custody" : context.role === "contractor" ? "Active Contract custody" : "My custody", warehousePresence: context.presence === "warehouse" };
  }

  loadWarehouse(context: HubContextModel): WarehouseData | null {
    if (!context.capabilities.viewWarehouse) return null;
    return { items: clone(this.state.warehouseItems), reservations: clone(this.state.reservations), incomingCargo: clone(this.state.cargo.filter((item) => item.status !== "completed")), capacity: { used: 142, total: 220 }, atWarehouse: context.presence === "warehouse", canManage: context.capabilities.manageWarehouse, canSellWholesale: context.capabilities.sellWholesaleStock };
  }

  loadWholesale(saleId: string, context: HubContextModel) {
    if (!context.capabilities.sellWholesaleStock) return null;
    return clone(this.state.wholesaleSales.find((item) => item.id === saleId) ?? null);
  }

  loadStaff(context: HubContextModel): StaffData | null {
    if (!context.capabilities.viewStaff) return null;
    return { members: clone(this.state.staff), applications: context.capabilities.reviewApplications ? clone(this.state.applications) : [], invitations: context.capabilities.inviteStaff ? clone(this.state.invitations) : [], candidates: [{ id: "actor-cameron", name: "Cameron Price", eligible: true }, { id: "actor-jules", name: "Jules Grant", eligible: false, reason: "Active member of another job" }], assignableRoles: context.role === "owner" ? ["worker", "procurement", "supervisor", "manager"] : ["worker", "procurement"] };
  }

  loadMember(memberId: string, context: HubContextModel): StaffMember | null {
    if (!context.capabilities.viewStaff) return null;
    const member = this.state.staff.find((item) => item.id === memberId);
    if (!member) return null;
    const safe = clone(member);
    if (context.role !== "owner" && ["owner", "manager"].includes(safe.role)) safe.availableActions = [];
    return safe;
  }

  loadApplications(context: HubContextModel) { return context.capabilities.reviewApplications ? clone(this.state.applications) : null; }
  loadApplication(id: string, context: HubContextModel) { return context.capabilities.reviewApplications ? clone(this.state.applications.find((item) => item.id === id) ?? null) : null; }
  loadOwnApplication(context: HubContextModel) { return context.role === "visitor" ? { application: clone(this.ownApplication(context)), invitation: clone(this.state.invitations.find((item) => item.candidateId === context.actorId && item.status === "pending")) } : null; }

  loadTreasury(context: HubContextModel): TreasurySnapshot | null {
    if (!context.capabilities.viewTreasury) return null;
    return { ...clone(this.state.treasury), personalBalance: context.capabilities.contributeTreasury ? this.getPersonalBalance(context.actorId) : undefined, recentEntries: clone(this.state.ledger.slice(0, 5)), availableActions: ["ledger", ...(context.capabilities.contributeTreasury ? ["contribute" as const] : [])] };
  }

  loadLedger(context: HubContextModel): LedgerEntry[] | null {
    if (!context.capabilities.viewCompanyLedger && !context.capabilities.viewProcurementLedger) return null;
    return clone(this.safeLedger(context));
  }

  loadLeases(context: HubContextModel): CompanyLease[] | null { return context.capabilities.viewLeases ? clone(this.state.leases) : null; }
  loadLease(id: string, context: HubContextModel): CompanyLease | null { return context.capabilities.viewLeases ? clone(this.state.leases.find((item) => item.id === id) ?? null) : null; }
  loadRolePolicies(context: HubContextModel): RolePolicy[] | null { return context.capabilities.manageRolePolicies ? clone(this.state.rolePolicies) : null; }
  loadIdentity(context: HubContextModel) { return context.capabilities.renameCompany ? clone(this.state.identity) : null; }
  loadBusinessSale(context: HubContextModel) { return context.capabilities.sellBusiness ? clone(this.state.listing) : null; }
  loadPublicSale(context: HubContextModel) { return context.capabilities.buyBusiness && ["published", "reserved", "awaiting_seller"].includes(this.state.listing.status) ? clone(this.state.listing) : null; }

  loadTransfer(listingId: string, context: HubContextModel): OwnershipTransfer | null {
    if (!context.capabilities.buyBusiness && !context.capabilities.sellBusiness) return null;
    if (this.state.listing.id !== listingId) return null;
    return { listing: clone(this.state.listing), company: clone(this.state.company), buyerFunds: this.getPersonalBalance(context.actorId), assets: [`Treasury · $${this.state.treasury.available.toLocaleString()}`, `Warehouse · $${this.state.treasury.warehouseValuation.toLocaleString()}`, `${this.state.leases.filter((item) => ["starter", "active", "grace"].includes(item.status)).length} operated Fields`], liabilities: [`Escrow · $${this.state.treasury.escrowReserved.toLocaleString()}`, `Active obligations · $${this.state.listing.activeObligations.toLocaleString()}`, "Existing Buyer Orders and Contracts"], staffContinuity: `${this.state.staff.length} Staff members remain employed`, formerOwnerExit: "The former Owner leaves the company after atomic transfer" };
  }

  setCargoRoute(cargoId: string, context: HubContextModel): IntentResult {
    const cargo = this.safeCargo(context).find((item) => item.id === cargoId);
    return cargo ? { ok: true, message: `Route set to ${cargo.destination}.`, handoff: { kind: "world", scope: { fieldId: "warehouse" } } } : { ok: false, message: "This cargo is no longer available in your custody." };
  }

  setRoute(destination: "office" | "warehouse" | "registry"): IntentResult {
    const labels = { office: "Grapeseed Farm Office", warehouse: "Farm Warehouse", registry: "San Andreas Business Registry" };
    return { ok: true, closeSurface: true, message: `Route set to ${labels[destination]}.`, handoff: { kind: "route", scope: { fieldId: destination } } };
  }

  prepareOrder(reservationId: string, context: HubContextModel): IntentResult {
    if (!context.capabilities.manageWarehouse) return { ok: false, message: "Warehouse management permission is required." };
    if (context.presence !== "warehouse") return { ok: false, closeSurface: true, message: "Continue at the Farm Warehouse." };
    const reservation = this.state.reservations.find((item) => item.id === reservationId);
    if (!reservation || reservation.status !== "active") return { ok: false, message: "This reservation is no longer active." };
    reservation.status = "prepared";
    return { ok: true, changed: true, message: `${reservation.sourceLabel} stock prepared for delivery.`, invalidated: [reservation.sourceId, "warehouse"] };
  }

  createWholesale(itemId: string, quantity: number, quality: string, context: HubContextModel): IntentResult {
    if (!context.capabilities.sellWholesaleStock) return { ok: false, message: "Wholesale sales are not permitted." };
    const item = this.state.warehouseItems.find((entry) => entry.id === itemId);
    if (!item || !Number.isInteger(quantity) || quantity <= 0 || quantity > item.available) return { ok: false, message: "Choose an available, unreserved stock quantity." };
    const id = `ws-${String(this.wholesaleSequence++).padStart(3, "0")}`;
    const unitPrice = item.category === "produce" ? 145 : 25;
    this.state.wholesaleSales.push({ id, reference: id.toUpperCase(), itemId, itemName: item.name, quality, quantity, unitPrice, payout: quantity * unitPrice, availableBefore: item.available, availableAfter: item.available - quantity, status: "draft" });
    return { ok: true, changed: true, entityId: id, message: `${id.toUpperCase()} prepared for review.` };
  }

  confirmWholesale(saleId: string, context: HubContextModel): IntentResult {
    if (!context.capabilities.sellWholesaleStock) return { ok: false, message: "Wholesale sales are not permitted." };
    if (context.presence !== "warehouse") return { ok: false, closeSurface: true, message: "Complete this stock transfer at the Farm Warehouse." };
    const sale = this.state.wholesaleSales.find((item) => item.id === saleId);
    const item = sale ? this.state.warehouseItems.find((entry) => entry.id === sale.itemId) : undefined;
    if (!sale || !item || sale.status !== "draft" || item.available < sale.quantity) return { ok: false, message: "Warehouse stock changed. Review the sale again." };
    item.total -= sale.quantity; item.available -= sale.quantity; sale.status = "completed";
    const ledger = this.postLedger({ key: `wholesale:${sale.id}`, type: "wholesale", amount: sale.payout, direction: "credit", actorId: context.actorId, actor: this.actorName(context.actorId), source: "San Andreas Produce Wholesaler", destination: `${this.state.company.name} Treasury`, linkedKind: "wholesale", linkedId: sale.id, status: "completed" });
    sale.ledgerEntryId = ledger.id;
    return { ok: true, changed: true, receiptId: ledger.id, message: `$${sale.payout.toLocaleString()} credited to Treasury.`, invalidated: ["warehouse", "treasury", "ledger"] };
  }

  saveApplication(input: JobApplicationInput, context: HubContextModel, submit: boolean): IntentResult {
    if (context.role !== "visitor" || !input.introduction.trim() || !input.availability.trim() || !input.preferredWork.trim()) return { ok: false, message: "Complete the required application details." };
    if (submit && !input.rulesAccepted) return { ok: false, message: "Company rules must be acknowledged before submission." };
    let application = this.ownApplication(context);
    if (application && !["draft", "rejected", "withdrawn"].includes(application.status)) return { ok: false, message: "You already have an active Job Application." };
    if (!application || application.status !== "draft") {
      application = { id: `app-${this.applicationSequence++}`, applicantId: context.actorId, applicant: this.actorName(context.actorId), ...input, updatedAt: now(), status: "draft", proposedRole: "worker", availableActions: ["submit", "withdraw"] };
      this.state.applications.push(application);
    } else Object.assign(application, input, { updatedAt: now() });
    if (submit) Object.assign(application, { status: "submitted", submittedAt: now(), availableActions: ["withdraw"] });
    return { ok: true, changed: true, entityId: application.id, message: submit ? "Job Application submitted." : "Application draft saved.", invalidated: ["applications", application.id] };
  }

  withdrawApplication(applicationId: string, context: HubContextModel): IntentResult {
    const application = this.state.applications.find((item) => item.id === applicationId && item.applicantId === context.actorId);
    if (!application || !["draft", "submitted", "under_review", "interview"].includes(application.status)) return { ok: false, message: "This application can no longer be withdrawn." };
    application.status = "withdrawn"; application.availableActions = [];
    return { ok: true, changed: true, message: "Job Application withdrawn." };
  }

  transitionApplication(applicationId: string, action: "interview" | "accept" | "reject", role: FarmRole | undefined, context: HubContextModel): IntentResult {
    if (!context.capabilities.reviewApplications) return { ok: false, message: "Application review permission is required." };
    const application = this.state.applications.find((item) => item.id === applicationId);
    if (!application || !["submitted", "under_review", "interview"].includes(application.status)) return { ok: false, message: "This application changed while review was open." };
    application.reviewer = this.actorName(context.actorId);
    if (action === "interview") { application.status = "interview"; application.availableActions = ["accept", "reject"]; }
    if (action === "reject") { application.status = "rejected"; application.availableActions = []; }
    if (action === "accept") {
      const finalRole = role ?? "worker";
      if (!this.allowedHireRoles(context.role).includes(finalRole)) return { ok: false, message: "That initial role is outside your hiring authority." };
      application.status = "accepted"; application.proposedRole = finalRole; application.availableActions = [];
      if (!this.state.staff.some((item) => item.id === application.applicantId)) this.state.staff.push({ id: application.applicantId, name: application.applicant, role: finalRole, status: "active", joinedAt: now(), lastActivity: now(), companyCargo: 0, issuedMaterials: 0, permissionExceptions: [], unresolvedIssues: [], availableActions: ["suspend", "remove", "change_role"] });
      return { ok: true, changed: true, message: `${application.applicant} hired as ${finalRole}.`, contextUpdate: application.applicantId === context.actorId ? { role: finalRole } : undefined, invalidated: ["staff", "applications"] };
    }
    return { ok: true, changed: true, message: action === "interview" ? "Interview requested." : "Application rejected.", invalidated: ["applications", application.id] };
  }

  inviteStaff(candidateId: string, role: FarmRole, context: HubContextModel): IntentResult {
    if (!context.capabilities.inviteStaff || !this.allowedHireRoles(context.role).includes(role)) return { ok: false, message: "That Staff invitation is not permitted." };
    if (this.state.staff.some((item) => item.id === candidateId) || this.state.invitations.some((item) => item.candidateId === candidateId && item.status === "pending")) return { ok: false, message: "This player is already Staff or has a pending invitation." };
    const id = `invite-${this.invitationSequence++}`;
    this.state.invitations.push({ id, candidateId, candidate: candidateId === "actor-cameron" ? "Cameron Price" : "Candidate", role, invitedBy: this.actorName(context.actorId), expiresAt: "Tomorrow, 16:32", status: "pending" });
    return { ok: true, changed: true, entityId: id, message: "Staff invitation sent." };
  }

  acceptInvitation(invitationId: string, context: HubContextModel): IntentResult {
    const invite = this.state.invitations.find((item) => item.id === invitationId && item.candidateId === context.actorId);
    if (!invite || invite.status !== "pending") return { ok: false, message: "This invitation is no longer available." };
    invite.status = "accepted";
    this.state.staff.push({ id: invite.candidateId, name: invite.candidate, role: invite.role, status: "active", joinedAt: now(), lastActivity: now(), companyCargo: 0, issuedMaterials: 0, permissionExceptions: [], unresolvedIssues: [], availableActions: ["suspend", "remove", "change_role"] });
    return { ok: true, changed: true, message: `Joined ${this.state.company.name} as ${invite.role}.`, contextUpdate: { role: invite.role }, invalidated: ["staff"] };
  }

  transitionStaff(memberId: string, action: "suspend" | "reinstate" | "remove" | "change_role", role: FarmRole | undefined, context: HubContextModel): IntentResult {
    if (!context.capabilities.viewStaff) return { ok: false, message: "Staff management permission is required." };
    const member = this.state.staff.find((item) => item.id === memberId);
    if (!member || member.role === "owner") return { ok: false, message: "The Owner can change only through a valid ownership transfer." };
    if (context.role !== "owner" && ["manager"].includes(member.role)) return { ok: false, message: "Only the Owner can change Management Staff." };
    if (action === "remove" && (member.companyCargo || member.issuedMaterials || member.activeAssignment)) return { ok: false, message: "Resolve active Work, cargo and issued materials before removal." };
    if (action === "suspend") member.status = "suspended";
    if (action === "reinstate") member.status = "active";
    if (action === "change_role") {
      if (!role || !this.allowedHireRoles(context.role).includes(role)) return { ok: false, message: "That role change is not permitted." };
      member.role = role;
    }
    if (action === "remove") this.state.staff = this.state.staff.filter((item) => item.id !== memberId);
    this.bumpCapabilities();
    return { ok: true, changed: true, message: action === "remove" ? `${member.name} removed from Staff.` : `${member.name} updated.`, invalidated: ["staff", memberId] };
  }

  contribute(amount: number, context: HubContextModel): IntentResult {
    if (!context.capabilities.contributeTreasury) return { ok: false, message: "Only the Owner can contribute personal funds." };
    if (context.surface !== "office" || context.presence !== "office") return { ok: false, closeSurface: true, message: "Complete the contribution at the Office Terminal." };
    if (!Number.isInteger(amount) || amount <= 0 || amount > this.getPersonalBalance(context.actorId)) return { ok: false, message: "Choose an amount available in personal funds." };
    this.state.personalBalances[context.actorId] -= amount;
    const ledger = this.postLedger({ key: `contribution:${context.actorId}:${this.ledgerSequence}`, type: "owner_contribution", amount, direction: "credit", actorId: context.actorId, actor: this.actorName(context.actorId), source: "Owner Personal Funds", destination: `${this.state.company.name} Treasury`, status: "completed" });
    this.invalidateListing();
    return { ok: true, changed: true, receiptId: ledger.id, message: `$${amount.toLocaleString()} contributed to Treasury.`, invalidated: ["treasury", "ledger", "business-sale"] };
  }

  transitionLease(leaseId: string, action: "start" | "pay" | "end", context: HubContextModel): IntentResult {
    if (!context.capabilities.manageLeases) return { ok: false, message: "Lease management permission is required." };
    const lease = this.state.leases.find((item) => item.id === leaseId);
    if (!lease || !lease.availableActions.includes(action)) return { ok: false, message: "This Lease action is no longer available." };
    if ((action === "start" || action === "pay") && this.state.treasury.available < lease.recurringPrice) return { ok: false, message: "Treasury cannot cover this Lease payment." };
    if (action === "start" || action === "pay") {
      lease.status = "active"; lease.nextPayment = "23 Aug, 16:32"; lease.graceDeadline = undefined; lease.restriction = undefined; lease.availableActions = ["pay", "end", "open_field"];
      this.postLedger({ key: `lease:${lease.id}:${action}:${lease.nextPayment}`, type: "lease", amount: lease.recurringPrice, direction: "debit", actorId: context.actorId, actor: this.actorName(context.actorId), source: `${this.state.company.name} Treasury`, destination: `${lease.fieldName} Lease`, linkedKind: "lease", linkedId: lease.id, status: "completed" });
    } else { lease.status = "ended"; lease.availableActions = []; }
    this.invalidateListing();
    return { ok: true, changed: true, message: action === "end" ? `${lease.fieldName} Lease ended.` : `${lease.fieldName} Lease payment completed.`, invalidated: ["leases", lease.fieldId, "treasury", "ledger"] };
  }

  savePolicy(role: FarmRole, permissions: string[], transactionLimit: number | undefined, context: HubContextModel): IntentResult {
    if (!context.capabilities.manageRolePolicies || role === "owner") return { ok: false, message: "This role policy is protected." };
    const policy = this.state.rolePolicies.find((item) => item.role === role);
    if (!policy || permissions.length === 0 || (transactionLimit !== undefined && transactionLimit < 0)) return { ok: false, message: "The role policy contains an invalid combination." };
    policy.permissions.forEach((item) => { if (!item.locked) item.enabled = permissions.includes(item.id); });
    policy.transactionLimit = transactionLimit; policy.pendingChanges = 0;
    this.bumpCapabilities();
    return { ok: true, changed: true, message: `${role} policy saved.`, contextUpdate: { capabilitiesRevision: this.getCapabilitiesRevision() }, invalidated: ["session-context", "role-policies"] };
  }

  resetPolicy(role: FarmRole, context: HubContextModel): IntentResult {
    if (!context.capabilities.manageRolePolicies || role === "owner") return { ok: false, message: "This role policy cannot be reset." };
    const base = createCompanyFixtureState().rolePolicies.find((item) => item.role === role);
    const index = this.state.rolePolicies.findIndex((item) => item.role === role);
    if (!base || index < 0) return { ok: false, message: "Role policy not found." };
    this.state.rolePolicies[index] = base; this.bumpCapabilities();
    return { ok: true, changed: true, message: `${role} restored to default.`, contextUpdate: { capabilitiesRevision: this.getCapabilitiesRevision() }, invalidated: ["session-context", "role-policies"] };
  }

  rename(name: string, context: HubContextModel): IntentResult {
    const clean = name.trim().replace(/\s+/g, " ");
    if (!context.capabilities.renameCompany) return { ok: false, message: "Company Identity permission is required." };
    if (context.surface !== "office" || context.presence !== "office") return { ok: false, closeSurface: true, message: "Complete the rename at the Office Terminal." };
    if (!this.state.identity.available || clean.length < 3 || clean.length > 28 || !/^[A-Za-z0-9 '-]+$/.test(clean)) return { ok: false, message: "The company name does not meet naming rules." };
    if (this.state.treasury.available < this.state.identity.renameCost) return { ok: false, message: "Treasury cannot cover the rename cost." };
    const previous = this.state.company.name;
    this.postLedger({ key: `rename:${this.state.company.id}:${this.state.company.capabilitiesRevision}`, type: "rename", amount: this.state.identity.renameCost, direction: "debit", actorId: context.actorId, actor: this.actorName(context.actorId), source: `${previous} Treasury`, destination: "San Andreas Business Registry", linkedKind: "company", linkedId: this.state.company.id, status: "completed" });
    this.state.company.name = clean; this.state.identity.currentName = clean; this.state.identity.lastRenamedAt = now(); this.state.identity.cooldownEndsAt = "15 Aug 2026, 16:32"; this.state.identity.available = false; this.state.listing.companyName = clean;
    this.invalidateListing();
    return { ok: true, changed: true, message: `Company renamed to ${clean}.`, invalidated: ["company", "identity", "ledger", "business-sale"] };
  }

  saveSaleDraft(askingPrice: number, context: HubContextModel): IntentResult {
    if (!context.capabilities.sellBusiness || askingPrice < 10000 || askingPrice > 9999999) return { ok: false, message: "Enter a valid asking price." };
    if (!["draft", "not_listed", "cancelled", "listing_changed"].includes(this.state.listing.status)) return { ok: false, message: "The active listing must be cancelled before editing." };
    if (this.state.listing.status === "not_listed") this.state.listing.id = `sale-${String(this.saleSequence++).padStart(3, "0")}`;
    Object.assign(this.state.listing, { askingPrice, saleFee: Math.round(askingPrice * 0.05), sellerProceeds: Math.round(askingPrice * 0.95), treasuryIncluded: this.state.treasury.available, warehouseValuation: this.state.treasury.warehouseValuation, staffCount: this.state.staff.length, activeLeases: this.state.leases.filter((item) => ["starter", "active", "grace"].includes(item.status)).length, status: "draft", buyerId: undefined, buyerName: undefined, buyerConfirmed: false, sellerConfirmed: false, availableActions: ["save", "publish"] });
    return { ok: true, changed: true, entityId: this.state.listing.id, message: "Business Sale draft saved." };
  }

  publishSale(listingId: string, context: HubContextModel): IntentResult {
    if (!context.capabilities.sellBusiness || context.surface !== "office" || context.presence !== "office") return { ok: false, closeSurface: true, message: "Publish the listing at the Office Terminal." };
    if (this.state.listing.id !== listingId || this.state.listing.status !== "draft") return { ok: false, message: "The listing changed while review was open." };
    this.state.listing.status = "published"; this.state.listing.version += 1; this.state.listing.expiresAt = "15 Aug 2026, 16:32"; this.state.listing.availableActions = ["cancel"]; this.state.company.status = "for_sale";
    return { ok: true, changed: true, message: `${this.state.company.name} is publicly listed for sale.`, invalidated: ["company-profile", "business-sale"] };
  }

  cancelSale(listingId: string, context: HubContextModel): IntentResult {
    if (!context.capabilities.sellBusiness || this.state.listing.id !== listingId || !["published", "listing_changed"].includes(this.state.listing.status)) return { ok: false, message: "This listing cannot be cancelled." };
    this.state.listing.status = "cancelled"; this.state.listing.availableActions = ["save"]; this.state.company.status = "operating";
    return { ok: true, changed: true, message: "Business Sale listing cancelled." };
  }

  reserveSale(listingId: string, context: HubContextModel): IntentResult {
    if (!context.capabilities.buyBusiness || context.presence !== "registry") return { ok: false, closeSurface: true, message: "Continue at the Business Registry." };
    if (this.state.listing.id !== listingId || this.state.listing.status !== "published") return { ok: false, message: "The listing is no longer available." };
    if (this.getPersonalBalance(context.actorId) < this.state.listing.askingPrice) return { ok: false, message: "Personal funds are insufficient for this purchase." };
    this.state.listing.status = "reserved"; this.state.listing.buyerId = context.actorId; this.state.listing.buyerName = this.actorName(context.actorId); this.state.listing.availableActions = ["confirm_buyer"];
    return { ok: true, changed: true, message: "Listing reserved. Review and confirm the transfer.", invalidated: ["business-sale"] };
  }

  confirmSale(listingId: string, party: "buyer" | "seller", context: HubContextModel): IntentResult {
    const listing = this.state.listing;
    if (listing.id !== listingId || !["reserved", "awaiting_seller"].includes(listing.status)) return { ok: false, message: "The listing changed before confirmation." };
    if (context.presence !== "registry") return { ok: false, closeSurface: true, message: "Complete ownership transfer at the Business Registry." };
    if (party === "buyer") {
      if (context.actorId !== listing.buyerId || this.getPersonalBalance(context.actorId) < listing.askingPrice) return { ok: false, message: "Buyer identity or personal funds failed revalidation." };
      listing.buyerConfirmed = true; listing.status = listing.initialSale ? "locked" : "awaiting_seller"; listing.availableActions = listing.initialSale ? [] : ["confirm_seller"];
    } else {
      if (!context.capabilities.sellBusiness || context.actorId !== listing.sellerId || !listing.buyerConfirmed) return { ok: false, message: "Seller confirmation is not currently authorized." };
      listing.sellerConfirmed = true; listing.status = "locked"; listing.availableActions = [];
    }
    if (listing.status !== "locked") return { ok: true, changed: true, message: "Buyer confirmed. Awaiting selling Owner.", invalidated: ["business-sale"] };
    const buyerId = listing.buyerId!;
    this.state.personalBalances[buyerId] -= listing.askingPrice;
    if (listing.sellerId) this.state.personalBalances[listing.sellerId] = (this.state.personalBalances[listing.sellerId] ?? 0) + listing.sellerProceeds;
    const formerOwnerId = this.state.company.ownerId;
    const formerOwner = this.state.staff.find((item) => item.id === formerOwnerId);
    const buyerName = listing.buyerName ?? this.actorName(buyerId);
    if (formerOwner) this.state.staff = this.state.staff.filter((item) => item.id !== formerOwner.id);
    this.state.staff.push({ id: buyerId, name: buyerName, role: "owner", status: "active", joinedAt: now(), lastActivity: now(), companyCargo: 0, issuedMaterials: 0, permissionExceptions: [], unresolvedIssues: [], availableActions: [] });
    this.state.company.ownerId = buyerId; this.state.company.ownerName = buyerName; this.state.company.status = "operating"; listing.status = "completed";
    this.postLedger({ key: `business-sale:${listing.id}:completed`, type: "business_sale", amount: listing.askingPrice, direction: "release", actorId: buyerId, actor: buyerName, source: `${buyerName} Personal Funds`, destination: listing.sellerName ?? "Initial Business Registry", linkedKind: "business_sale", linkedId: listing.id, status: "released", affectsTreasury: false });
    this.bumpCapabilities();
    return { ok: true, changed: true, message: `Ownership transferred to ${buyerName}.`, contextUpdate: { role: context.actorId === buyerId ? "owner" : "visitor" }, invalidated: ["session-context", "company", "staff", "business-sale", "ledger"] };
  }

  recordPurchase(amount: number, purchaseId: string, context: HubContextModel) {
    return this.postLedger({ key: `purchase:${purchaseId}`, type: "purchase", amount, direction: "debit", actorId: context.actorId, actor: this.actorName(context.actorId), source: `${this.state.company.name} Treasury`, destination: "Grapeseed Agricultural Supply", linkedKind: "purchase", linkedId: purchaseId, status: "completed" });
  }

  private safeCargo(context: HubContextModel) {
    if (context.capabilities.viewTeamCompanyCargo) return this.state.cargo;
    if (!context.capabilities.viewOwnCompanyCargo) return [];
    return this.state.cargo.filter((item) => item.custodianId === context.actorId);
  }

  private safeLedger(context: HubContextModel) { return context.capabilities.viewCompanyLedger ? this.state.ledger : this.state.ledger.filter((item) => item.type === "purchase" && item.actorId === context.actorId); }
  private ownApplication(context: HubContextModel): StaffApplication | undefined { return this.state.applications.find((item) => item.applicantId === context.actorId && item.status !== "withdrawn"); }
  private allowedHireRoles(role: FarmRole): FarmRole[] { return role === "owner" ? ["worker", "procurement", "supervisor", "manager"] : role === "manager" ? ["worker", "procurement"] : []; }
  private actorName(actorId: string) { return this.state.staff.find((item) => item.id === actorId)?.name ?? this.state.applications.find((item) => item.applicantId === actorId)?.applicant ?? (actorId === "actor-avery" ? "Avery Cole" : actorId === "actor-cameron" ? "Cameron Price" : "Morgan Hayes"); }
  private headline(context: HubContextModel, modules: CompanyHomeModule[]) { const urgent = modules.find((item) => item.priority === "critical"); return urgent ? urgent.detail : context.role === "visitor" ? "Public opportunities and ownership" : "Business records that need attention"; }
  private bumpCapabilities() { this.state.company.capabilitiesRevision += 1; }
  private invalidateListing() { if (["published", "reserved", "awaiting_seller"].includes(this.state.listing.status)) { this.state.listing.status = "listing_changed"; this.state.listing.version += 1; this.state.listing.availableActions = ["cancel"]; } }

  private postLedger(input: { key: string; type: LedgerEntry["type"]; amount: number; direction: LedgerEntry["direction"]; actorId: string; actor: string; source: string; destination: string; linkedKind?: string; linkedId?: string; status: LedgerEntry["status"]; affectsTreasury?: boolean }) {
    const existing = this.state.ledger.find((item) => item.idempotencyKey === input.key);
    if (existing) return existing;
    if (input.affectsTreasury !== false) {
      if (input.direction === "credit") this.state.treasury.available += input.amount;
      if (input.direction === "debit") { this.state.treasury.available -= input.amount; if (input.type === "purchase") this.state.treasury.procurementBudget = Math.max(0, this.state.treasury.procurementBudget - input.amount); }
    }
    const entry: LedgerEntry = { id: `txn-${this.ledgerSequence++}`, idempotencyKey: input.key, type: input.type, amount: input.amount, direction: input.direction, actorId: input.actorId, actor: input.actor, at: now(), source: input.source, destination: input.destination, linkedKind: input.linkedKind, linkedId: input.linkedId, status: input.status, balanceAfter: this.state.treasury.available };
    this.state.ledger.unshift(entry);
    return entry;
  }
}

export const companyFixtureRepository = new CompanyFixtureRepository();

export function actorForRole(role: FarmRole) { return ACTOR_BY_ROLE[role]; }
