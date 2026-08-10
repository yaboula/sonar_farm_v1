import { cloneAssignmentFixtures, ELIGIBLE_ASSIGNEES } from "../data/assignmentFixtures";
import { cloneWorkSupplyFixtures } from "../data/workSupplyFixtures";
import { FieldFixtureRepository } from "./FieldFixtureRepository";
import { CompanyFixtureRepository } from "./CompanyFixtureRepository";
import type {
  ActionIntent,
  AssignmentCreateInput,
  AssignmentDetail,
  AvailableAssignmentAction,
  BuyerOrderAction,
  BuyerOrderDetail,
  ContractAction,
  ContractDetail,
  FarmRole,
  FieldDeltaListener,
  HubAdapter,
  HubContextModel,
  HubViewRequest,
  HubViewModel,
  IntentResult,
  SuppliesHubData,
  WorkArea,
  WorkFixture,
  WorkQueueData,
} from "../types";

type AssignmentMutationIntent = Exclude<
  Extract<ActionIntent, { type: `assignment.${string}` }>,
  { type: "assignment.create" }
>;

const wait = (duration: number) => new Promise((resolve) => setTimeout(resolve, duration));

const MANAGEMENT_ROLES: FarmRole[] = ["supervisor", "manager", "owner"];
const WORKER_ACTIONS: AvailableAssignmentAction[] = ["accept", "resume", "submit"];
const SUPERVISOR_ACTIONS: AvailableAssignmentAction[] = [
  "approve",
  "request_correction",
  "reassign",
  "cancel",
  "resolve_blocker",
];

function canReadAssignment(role: FarmRole, assignment: AssignmentDetail) {
  if (MANAGEMENT_ROLES.includes(role)) return true;
  return ["worker", "procurement"].includes(role) && assignment.assignee.id === "staff-noah";
}

function actionsForRole(role: FarmRole, assignment: AssignmentDetail) {
  const allowed = MANAGEMENT_ROLES.includes(role) ? SUPERVISOR_ACTIONS : WORKER_ACTIONS;
  return assignment.availableActions.filter((action) => allowed.includes(action));
}

function addProgress(
  assignment: AssignmentDetail,
  title: string,
  detail: string,
  actor: string,
  tone: "neutral" | "positive" | "warning",
) {
  assignment.progress.unshift({
    id: `evt-${assignment.id}-${Date.now()}`,
    at: "Just now",
    title,
    detail,
    actor,
    tone,
  });
}

function assignmentToQueue(item: AssignmentDetail): WorkFixture {
  const target = item.requirements.reduce((sum, requirement) => sum + requirement.target, 0);
  const current = item.requirements.reduce(
    (sum, requirement) => sum + Math.min(requirement.current, requirement.target),
    0,
  );
  return {
    id: item.id,
    type: "assignment",
    title: item.title,
    meta: `${item.crop} · ${item.field.scope} · ${item.assignee.name}`,
    status: item.statusLabel,
    deadline: item.deadline,
    progress: target ? Math.round((current / target) * 100) : 0,
    assigneeId: item.assignee.id,
  };
}

function buyerOrderToQueue(item: BuyerOrderDetail): WorkFixture {
  return {
    id: item.id,
    type: "buyerOrder",
    title: item.buyer,
    meta: `${item.quantity} ${item.product} · ${item.quality}`,
    status: item.statusLabel,
    deadline: item.deadline,
    progress: item.quantity ? Math.round((item.reservedQuantity / item.quantity) * 100) : 0,
  };
}

function contractToQueue(item: ContractDetail): WorkFixture {
  const complete = item.steps.filter((step) => step.completed).length;
  return {
    id: item.id,
    type: "contract",
    title: item.title,
    meta: `${item.field} · ${item.scope}`,
    status: item.statusLabel,
    deadline: item.deadline,
    progress: item.steps.length ? Math.round((complete / item.steps.length) * 100) : 0,
  };
}

function nextBuyerActions(action: BuyerOrderAction): BuyerOrderDetail["availableActions"] {
  if (action === "accept") return ["plan", "reject"];
  if (action === "plan") return ["create_assignment", "reserve", "reject"];
  if (action === "reserve") return ["create_assignment", "prepare", "reject"];
  if (action === "prepare") return ["complete", "reject"];
  return [];
}

export class FixtureHubAdapter implements HubAdapter {
  private assignments = cloneAssignmentFixtures();
  private workSupplies = cloneWorkSupplyFixtures();
  private assignmentSequence = 1062;
  private contractSequence = 84;
  private purchaseSequence = 301;
  private fields = new FieldFixtureRepository();
  private company = new CompanyFixtureRepository();

  constructor(private readonly delayMs = 80) {}

  resolveCapabilities(role: FarmRole, surface: HubContextModel["surface"]) {
    return this.company.resolveCapabilities(role, surface);
  }

  private effectiveContext(context: HubContextModel): HubContextModel {
    return { ...context, capabilitiesRevision: this.company.getCapabilitiesRevision(), capabilities: this.resolveCapabilities(context.role, context.surface) };
  }

  reset() {
    this.assignments = cloneAssignmentFixtures();
    this.workSupplies = cloneWorkSupplyFixtures();
    this.assignmentSequence = 1062;
    this.contractSequence = 84;
    this.purchaseSequence = 301;
    this.fields.reset();
    this.company.reset();
  }

  private loadWork(context: HubContextModel): WorkQueueData {
    const areas: WorkArea[] = [];
    const items: WorkFixture[] = [];

    if (context.capabilities.viewOwnAssignments || context.capabilities.viewTeamAssignments) {
      areas.push("assignments");
      this.assignments
        .filter((item) => context.capabilities.viewTeamAssignments || item.assignee.id === "staff-noah")
        .forEach((item) => items.push(assignmentToQueue(item)));
    }
    if (context.capabilities.manageBuyerOrders) {
      areas.push("buyerOrders");
      this.workSupplies.buyerOrders.forEach((item) => items.push(buyerOrderToQueue(item)));
    }
    if (context.capabilities.browsePublicContracts || context.capabilities.managePublicContracts) {
      areas.push("publicContracts");
      this.workSupplies.contracts
        .filter((item) => context.capabilities.managePublicContracts || item.status === "published")
        .filter((item) => item.status !== "active")
        .forEach((item) => items.push(contractToQueue(item)));
    }
    if (context.capabilities.viewActiveContract) {
      areas.push("activeContract");
      this.workSupplies.contracts
        .filter((item) => item.status === "active" || item.status === "awaiting_review" || item.status === "completed")
        .filter((item) => item.contractor === "Avery Cole")
        .forEach((item) => items.push(contractToQueue(item)));
    }

    return {
      areas,
      items,
      canCreateAssignment: context.capabilities.createAssignments,
      canCreateContract: context.capabilities.managePublicContracts,
    };
  }

  private loadSupplies(context: HubContextModel): SuppliesHubData {
    const canCompanyBuy = context.capabilities.buyCompanySupplies;
    return {
      products: structuredClone(this.workSupplies.products),
      allowedPayers: canCompanyBuy ? ["personal", "company"] : ["personal"],
      personalBalance: this.company.getPersonalBalance(context.actorId),
      companyBalance: canCompanyBuy ? this.company.getCompanyBalance() : undefined,
      procurement: canCompanyBuy
        ? {
            monthlyBudget: 12000,
            remaining: this.company.getProcurementBudget(),
            transactionLimit: 1500,
            allowedCategories: ["Seedlings", "Seeds", "Hand Tools", "Watering", "Fertilizer", "Pest Treatment"],
            recentPurchases: this.workSupplies.purchases
              .filter((purchase) => purchase.payer === "company" && purchase.status === "delivered")
              .slice(-3)
              .map((purchase) => ({ id: purchase.id, detail: purchase.reference, amount: purchase.total, at: "Just now" })),
            requests: structuredClone(this.workSupplies.procurementRequests),
            violations: ["One asset return is overdue by 3 hours."],
          }
        : undefined,
      issuedMaterials: context.capabilities.manageIssuedMaterials
        ? structuredClone(this.workSupplies.issuedMaterials)
        : [],
    };
  }

  async load<TData>(request: HubViewRequest, context: HubContextModel): Promise<HubViewModel<TData>> {
    await wait(this.delayMs);
    context = this.effectiveContext(context);
    if (context.viewState !== "ready") return { request, state: context.viewState, data: null };

    if (request.kind === "hub") {
      const data = request.route === "work"
        ? this.loadWork(context)
        : request.route === "supplies"
          ? this.loadSupplies(context)
          : {};
      return { request, state: "ready", data: data as TData };
    }

    if (request.kind === "fieldsOverview") {
      const data = this.fields.loadOverview(context);
      return data
        ? { request, state: "ready", data: data as TData }
        : { request, state: "restricted", data: null };
    }

    if (request.kind === "fieldDetail") {
      const data = this.fields.loadField(request.fieldId, context);
      if (data === "restricted") return { request, state: "restricted", data: null };
      return { request, state: "ready", data: data as TData | null };
    }

    if (request.kind === "assignmentCreate") {
      return context.capabilities.createAssignments
        ? { request, state: "ready", data: {
            nextReference: `ASG-${this.assignmentSequence}`,
            serverNow: Math.floor(Date.now() / 1000),
            fields: [],
            members: [
              { id: "staff-noah", name: "Noah Reed", role: "Worker" },
              { id: "staff-sofia", name: "Sofia Bennett", role: "Worker" },
            ],
            plans: this.fields.loadAvailablePlans(context),
          } as TData }
        : { request, state: "restricted", data: null };
    }

    if (request.kind === "assignmentDetail") {
      const assignment = this.assignments.find((item) => item.id === request.assignmentId);
      if (!assignment) return { request, state: "ready", data: null };
      if (!canReadAssignment(context.role, assignment)) return { request, state: "restricted", data: null };
      const safeAssignment = structuredClone(assignment);
      safeAssignment.availableActions = actionsForRole(context.role, safeAssignment);
      safeAssignment.eligibleAssignees = ELIGIBLE_ASSIGNEES.map((worker) => ({ ...worker, role: "Worker" }));
      return { request, state: "ready", data: safeAssignment as TData };
    }

    if (request.kind === "buyerOrderDetail") {
      if (!context.capabilities.manageBuyerOrders) return { request, state: "restricted", data: null };
      const order = this.workSupplies.buyerOrders.find((item) => item.id === request.orderId);
      return { request, state: "ready", data: (order ? structuredClone(order) : null) as TData | null };
    }

    if (request.kind === "contractCreate") {
      return context.capabilities.managePublicContracts
        ? { request, state: "ready", data: {
            nextReference: `PC-${String(this.contractSequence).padStart(3, "0")}`,
            serverNow: Math.floor(Date.now() / 1000),
            fields: [],
            members: [],
            plans: this.fields.loadAvailablePlans(context),
          } as TData }
        : { request, state: "restricted", data: null };
    }

    if (request.kind === "contractDetail") {
      const contract = this.workSupplies.contracts.find((item) => item.id === request.contractId);
      if (!contract) return { request, state: "ready", data: null };
      const publicAccess = request.mode === "public" && (context.capabilities.browsePublicContracts || context.capabilities.managePublicContracts);
      const activeAccess = request.mode !== "public" && (
        context.capabilities.managePublicContracts ||
        (context.capabilities.viewActiveContract && contract.contractor === "Avery Cole")
      );
      if (!publicAccess && !activeAccess) return { request, state: "restricted", data: null };
      const safe = structuredClone(contract);
      if (request.mode === "public") {
        safe.availableActions = context.role === "visitor" && safe.status === "published"
          ? ["accept"]
          : context.capabilities.managePublicContracts
            ? safe.availableActions
            : [];
      }
      return { request, state: "ready", data: safe as TData };
    }

    if (request.kind === "companyHome") return { request, state: "ready", data: this.company.loadHome(context) as TData };
    if (request.kind === "companyProfile") return { request, state: "ready", data: this.company.loadProfile(context) as TData };
    if (request.kind === "companyCargo") {
      if (!context.capabilities.viewOwnCompanyCargo) return { request, state: "restricted", data: null };
      return { request, state: "ready", data: this.company.loadCargo(context) as TData };
    }
    if (request.kind === "companyWarehouse") {
      const data = this.company.loadWarehouse(context);
      return data ? { request, state: "ready", data: data as TData } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyWholesaleReview") {
      const data = this.company.loadWholesale(request.saleId, context);
      return context.capabilities.sellWholesaleStock ? { request, state: "ready", data: data as TData | null } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyStaff") {
      const data = this.company.loadStaff(context);
      return data ? { request, state: "ready", data: data as TData } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyStaffMember") {
      const data = this.company.loadMember(request.memberId, context);
      return context.capabilities.viewStaff ? { request, state: "ready", data: data as TData | null } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyApplications") {
      const data = this.company.loadApplications(context);
      return data ? { request, state: "ready", data: data as TData } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyApplicationReview") {
      const data = this.company.loadApplication(request.applicationId, context);
      return context.capabilities.reviewApplications ? { request, state: "ready", data: data as TData | null } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyJobApplication") {
      return context.role === "visitor" ? { request, state: "ready", data: this.company.loadOwnApplication(context) as TData | null } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyTreasury") {
      const data = this.company.loadTreasury(context);
      return data ? { request, state: "ready", data: data as TData } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyLedger") {
      const data = this.company.loadLedger(context);
      return data ? { request, state: "ready", data: data as TData } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyLeases") {
      const data = this.company.loadLeases(context);
      return data ? { request, state: "ready", data: data as TData } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyLeaseDetail") {
      const data = this.company.loadLease(request.leaseId, context);
      return context.capabilities.viewLeases ? { request, state: "ready", data: data as TData | null } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyRolePolicies") {
      const data = this.company.loadRolePolicies(context);
      return data ? { request, state: "ready", data: data as TData } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyIdentity") {
      const data = this.company.loadIdentity(context);
      return data ? { request, state: "ready", data: data as TData } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyBusinessSale" || request.kind === "companySaleReview") {
      const data = this.company.loadBusinessSale(context);
      return data ? { request, state: "ready", data: data as TData } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyPublicSale") {
      const data = this.company.loadPublicSale(context);
      return context.capabilities.buyBusiness ? { request, state: "ready", data: data as TData | null } : { request, state: "restricted", data: null };
    }
    if (request.kind === "companyOwnershipTransfer") {
      const data = this.company.loadTransfer(request.listingId, context);
      return data ? { request, state: "ready", data: data as TData } : { request, state: "restricted", data: null };
    }

    if (request.kind !== "purchaseReview") return { request, state: "restricted", data: null };

    const purchase = this.workSupplies.purchases.find((item) => item.id === request.purchaseId);
    if (!purchase) return { request, state: "ready", data: null };
    const allowed = purchase.payer === "personal"
      ? context.capabilities.buyPersonalSupplies
      : context.capabilities.buyCompanySupplies;
    const safePurchase = structuredClone(purchase);
    safePurchase.canConfirm = safePurchase.status === "draft";
    return allowed
      ? { request, state: "ready", data: safePurchase as TData }
      : { request, state: "restricted", data: null };
  }

  async dispatch(intent: ActionIntent, context: HubContextModel): Promise<IntentResult> {
    await wait(this.delayMs);
    context = this.effectiveContext(context);

    if (intent.type === "assignment.create") return this.createAssignment(intent.input, context);
    if (intent.type.startsWith("assignment.")) return this.dispatchAssignment(intent as AssignmentMutationIntent, context);
    if (intent.type === "buyerOrder.transition") return this.transitionBuyerOrder(intent.orderId, intent.action, context);
    if (intent.type === "contract.accept") return this.acceptContract(intent.contractId, context);
    if (intent.type === "contract.verifyStep") return this.verifyContractStep(intent.contractId, intent.stepId, context);
    if (intent.type === "contract.transition") return this.transitionContract(intent.contractId, intent.action, intent.note, context);
    if (intent.type === "contract.create") return this.createContract(intent.input, context);
    if (intent.type === "purchase.createDraft") return this.createPurchase(intent.payer, intent.lines, context);
    if (intent.type === "purchase.confirm") return this.confirmPurchase(intent.purchaseId, context);
    if (intent.type === "procurement.resolve") return this.resolveProcurement(intent.requestId, intent.decision, context);
    if (intent.type === "issuedMaterial.transition") return this.transitionIssuedMaterial(intent.materialId, intent.action, context);
    if (intent.type === "cropPlan.create") return this.fields.createPlan(intent.input, context);
    if (intent.type === "cropPlan.update") return this.fields.updatePlan(intent.planId, intent.input, context);
    if (intent.type === "cropPlan.cancel") return this.fields.cancelPlan(intent.planId, context);
    if (intent.type === "field.setRoute") return this.fields.setRoute(intent.scope, context);
    if (intent.type === "field.preparePurchase") return { ok: true, changed: true, message: "Field purchase prepared for Owner confirmation." };
    if (intent.type === "companyCargo.setRoute") return this.company.setCargoRoute(intent.cargoId, context);
    if (intent.type === "company.setRoute") return this.company.setRoute(intent.destination);
    if (intent.type === "warehouse.withdraw") return this.company.withdraw(intent.itemId, intent.quantity, context);
    if (intent.type === "warehouse.prepareOrder") return this.company.prepareOrder(intent.reservationId, context);
    if (intent.type === "warehouse.createWholesale") return this.company.createWholesale(intent.itemId, intent.quantity, intent.quality, context);
    if (intent.type === "warehouse.confirmWholesale") return this.company.confirmWholesale(intent.saleId, context);
    if (intent.type === "jobApplication.saveDraft") return this.company.saveApplication(intent.input, context, false);
    if (intent.type === "jobApplication.submit") return this.company.saveApplication(intent.input, context, true);
    if (intent.type === "jobApplication.withdraw") return this.company.withdrawApplication(intent.applicationId, context);
    if (intent.type === "staffApplication.transition") return this.company.transitionApplication(intent.applicationId, intent.action, intent.role, context);
    if (intent.type === "staff.invite") return this.company.inviteStaff(intent.candidateId, intent.role, context);
    if (intent.type === "staffInvitation.accept") return this.company.acceptInvitation(intent.invitationId, context);
    if (intent.type === "staff.transition") return this.company.transitionStaff(intent.memberId, intent.action, intent.role, context);
    if (intent.type === "treasury.contribute") return this.company.contribute(intent.amount, context);
    if (intent.type === "lease.transition") {
      const result = this.company.transitionLease(intent.leaseId, intent.action, context);
      const lease = result.ok ? this.company.getLeaseSnapshot(intent.leaseId) : undefined;
      if (lease) this.fields.applyLeaseState(lease);
      return result;
    }
    if (intent.type === "rolePolicy.save") return this.company.savePolicy(intent.role, intent.permissions, intent.transactionLimit, context);
    if (intent.type === "rolePolicy.reset") return this.company.resetPolicy(intent.role, context);
    if (intent.type === "company.rename") return this.company.rename(intent.name, context);
    if (intent.type === "businessSale.saveDraft") return this.company.saveSaleDraft(intent.askingPrice, context);
    if (intent.type === "businessSale.publish") return this.company.publishSale(intent.listingId, context);
    if (intent.type === "businessSale.cancel") return this.company.cancelSale(intent.listingId, context);
    if (intent.type === "businessSale.reserve") return this.company.reserveSale(intent.listingId, context);
    if (intent.type === "businessSale.confirm") return this.company.confirmSale(intent.listingId, intent.party, context);
    return { ok: false, message: "This action is unavailable." };
  }

  subscribeField(fieldId: string, afterSequence: number, context: HubContextModel, listener: FieldDeltaListener) {
    return this.fields.subscribe(fieldId, afterSequence, context, listener);
  }

  private createAssignment(input: AssignmentCreateInput, context: HubContextModel): IntentResult {
    if (!context.capabilities.createAssignments) return { ok: false, message: "Assignment creation is not permitted." };
    if (!input.title.trim() || !input.objective.trim() || input.payout <= 0) return { ok: false, message: "Complete the required Assignment terms." };
    const id = `asg-${this.assignmentSequence++}`;
    const assigneeName = input.assigneeId === "staff-sofia" ? "Sofia Bennett" : "Noah Reed";
    this.assignments.unshift({
      id,
      reference: id.toUpperCase(),
      title: input.title.trim(),
      status: "assigned",
      statusLabel: "Assigned",
      workType: "Field Operation",
      objective: input.objective.trim(),
      crop: input.crop,
      field: { id: input.fieldId, name: ({ "north-field": "North Field", "greenhouse-2": "Greenhouse 2", "east-field": "East Field", "orchard-annex": "Orchard Annex" } as Record<string, string>)[input.fieldId] ?? input.fieldId, scope: input.scope, routeLabel: "Assigned access point" },
      assignee: { id: input.assigneeId, name: assigneeName, role: "Worker" },
      supervisor: { id: input.supervisorId, name: "Jordan Tate" },
      deadline: input.deadline,
      deadlineIso: "2026-08-09T18:00:00+02:00",
      requirements: [{ id: `${id}-req`, label: input.requirement, detail: "Requires farm service verification", current: 0, target: 1, unit: "result", status: "pending" }],
      issuedMaterials: input.materialIds.map((materialId) => ({ id: `${id}-${materialId}`, name: materialId === "watering-can" ? "Watering Can" : "Field Pruners", quantity: "1 issued asset", ownership: "Company", returnRequired: true, status: "issued" })),
      payout: { amount: input.payout, currency: "USD", status: "reserved", conditions: ["Verified result required.", "Issued assets must be accounted for."] },
      progress: [{ id: `${id}-created`, at: "Just now", title: "Assignment issued", detail: "Reserved pay and work scope recorded.", actor: "Jordan Tate", tone: "neutral" }],
      cancellationSummary: "Cancellation voids reserved pay unless verified work requires review.",
      availableActions: ["accept", "reassign", "cancel"],
      scopeRef: input.scopeRef,
      sourcePlanId: input.sourcePlanId,
    });
    if (input.sourcePlanId) this.fields.linkPlanToWork(input.sourcePlanId, "assignment", id);
    return { ok: true, changed: true, entityId: id, message: `${id.toUpperCase()} created with reserved pay.` };
  }

  private dispatchAssignment(intent: AssignmentMutationIntent, context: HubContextModel): IntentResult {
    const assignment = this.assignments.find((item) => item.id === intent.assignmentId);
    if (!assignment || !canReadAssignment(context.role, assignment)) return { ok: false, message: "Assignment is unavailable for this role." };
    const actionName = intent.type.replace("assignment.", "").replace("requestCorrection", "request_correction").replace("resolveBlocker", "resolve_blocker") as AvailableAssignmentAction;
    if (!actionsForRole(context.role, assignment).includes(actionName)) return { ok: false, message: "This action is no longer available." };

    if (intent.type === "assignment.resume") return { ok: true, changed: false, closeSurface: true, message: `Return to ${assignment.field.name} · ${assignment.field.scope}` };
    if (intent.type === "assignment.accept") {
      assignment.status = "in_progress";
      assignment.statusLabel = "In Progress";
      assignment.availableActions = ["resume", "reassign", "cancel"];
      addProgress(assignment, "Assignment accepted", "Issued materials are now in worker custody.", assignment.assignee.name, "neutral");
      return { ok: true, changed: true, message: "Assignment accepted." };
    }
    if (intent.type === "assignment.submit") {
      const complete = assignment.requirements.every((item) => item.status === "verified" && item.current >= item.target);
      if (!complete) return { ok: false, message: "Verified requirements are still incomplete." };
      assignment.status = "awaiting_review";
      assignment.statusLabel = "Awaiting Review";
      assignment.payout.status = "pending_review";
      assignment.availableActions = ["approve", "request_correction", "reassign", "cancel"];
      addProgress(assignment, "Submitted for review", "All required results are ready for Supervisor review.", assignment.assignee.name, "positive");
      return { ok: true, changed: true, message: "Assignment submitted for review." };
    }
    if (intent.type === "assignment.approve") {
      assignment.status = "completed";
      assignment.statusLabel = "Completed";
      assignment.payout.status = "released";
      assignment.availableActions = [];
      assignment.reviewerNote = intent.note || "Verified result approved.";
      addProgress(assignment, "Result approved", `Reserved pay of $${assignment.payout.amount} released.`, "Jordan Tate", "positive");
      return { ok: true, changed: true, message: "Result approved and reserved pay released." };
    }
    if (intent.type === "assignment.requestCorrection") {
      if (!intent.note.trim()) return { ok: false, message: "Correction notes are required." };
      assignment.status = "in_progress";
      assignment.statusLabel = "Correction Requested";
      assignment.payout.status = "reserved";
      assignment.reviewerNote = intent.note.trim();
      assignment.availableActions = ["resume", "reassign", "cancel"];
      addProgress(assignment, "Correction requested", intent.note.trim(), "Jordan Tate", "warning");
      return { ok: true, changed: true, message: "Assignment returned with correction notes." };
    }
    if (intent.type === "assignment.resolveBlocker") {
      if (!intent.note.trim()) return { ok: false, message: "Resolution notes are required." };
      assignment.status = "in_progress";
      assignment.statusLabel = "In Progress";
      assignment.blocker = undefined;
      assignment.availableActions = ["resume", "reassign", "cancel"];
      addProgress(assignment, "Blocker resolved", intent.note.trim(), "Jordan Tate", "positive");
      return { ok: true, changed: true, message: "Blocker resolved." };
    }
    if (intent.type === "assignment.reassign") {
      const name = intent.assigneeId === "staff-sofia" ? "Sofia Bennett" : intent.assigneeId === "staff-noah" ? "Noah Reed" : undefined;
      if (!name) return { ok: false, message: "Selected worker is unavailable." };
      assignment.assignee = { id: intent.assigneeId, name, role: "Worker" };
      addProgress(assignment, "Assignment reassigned", `Responsibility moved to ${name}.`, "Jordan Tate", "neutral");
      return { ok: true, changed: true, message: `Assignment reassigned to ${name}.` };
    }
    if (!intent.reason.trim()) return { ok: false, message: "Cancellation reason is required." };
    assignment.status = "cancelled";
    assignment.statusLabel = "Cancelled";
    assignment.payout.status = "void";
    assignment.availableActions = [];
    addProgress(assignment, "Assignment cancelled", intent.reason.trim(), "Jordan Tate", "warning");
    return { ok: true, changed: true, message: "Assignment cancelled." };
  }

  private transitionBuyerOrder(orderId: string, action: BuyerOrderAction, context: HubContextModel): IntentResult {
    if (!context.capabilities.manageBuyerOrders) return { ok: false, message: "Buyer Order management is not permitted." };
    const order = this.workSupplies.buyerOrders.find((item) => item.id === orderId);
    if (!order || !order.availableActions.includes(action)) return { ok: false, message: "This Buyer Order action is no longer available." };
    if (action === "create_assignment") return { ok: true, changed: false, entityId: order.id, message: "Assignment planning opened for this Buyer Order." };
    const labels: Record<Exclude<BuyerOrderAction, "create_assignment">, [BuyerOrderDetail["status"], string]> = {
      accept: ["accepted", "Accepted"], plan: ["planned", "Fulfillment Planned"], reserve: ["reserved", "Stock Reserved"], prepare: ["ready", "Ready for Delivery"], complete: ["completed", "Completed"], reject: ["rejected", "Rejected"],
    };
    const [status, label] = labels[action];
    order.status = status;
    order.statusLabel = label;
    if (action === "reserve") order.reservedQuantity = order.quantity;
    order.availableActions = nextBuyerActions(action);
    return { ok: true, changed: true, message: `${order.reference} updated: ${label}.` };
  }

  private acceptContract(contractId: string, context: HubContextModel): IntentResult {
    if (context.role !== "visitor") return { ok: false, message: "Only an independent visitor can accept this public contract." };
    const contract = this.workSupplies.contracts.find((item) => item.id === contractId);
    if (!contract || contract.status !== "published" || contract.contractor) return { ok: false, message: "This contract has already been reserved." };
    contract.status = "active";
    contract.statusLabel = "Active";
    contract.contractor = "Avery Cole";
    contract.fieldAccess = `${contract.field} access active`;
    contract.availableActions = ["set_route_field", "open_supplies", "abandon"];
    return { ok: true, changed: true, entityId: contract.id, contextUpdate: { role: "contractor" }, message: `${contract.reference} reserved. Reward remains in escrow.` };
  }

  private transitionContract(contractId: string, action: ContractAction, note: string | undefined, context: HubContextModel): IntentResult {
    const contract = this.workSupplies.contracts.find((item) => item.id === contractId);
    const permitted = context.capabilities.managePublicContracts || (context.capabilities.viewActiveContract && contract?.contractor === "Avery Cole");
    if (!contract || !permitted || !contract.availableActions.includes(action)) return { ok: false, message: "This contract action is no longer available." };
    if (action === "accept") return { ok: false, message: "Use the public acceptance flow." };
    if (action === "set_route_field" || action === "set_route_delivery") return { ok: true, changed: false, closeSurface: true, message: action === "set_route_field" ? `Route set to ${contract.field}.` : `Route set to ${contract.deliveryDestination}.` };
    if (action === "open_supplies") return { ok: true, changed: false, entityId: "supplies", message: "Personal Supply Market opened for required materials." };
    if (action === "submit") {
      if (contract.steps.some((step) => !step.completed)) return { ok: false, message: "Verified contract steps are still incomplete." };
      contract.status = "awaiting_review";
      contract.statusLabel = "Awaiting Review";
      contract.availableActions = context.capabilities.managePublicContracts ? ["complete", "cancel"] : [];
      return { ok: true, changed: true, message: "Contract result submitted for validation." };
    }
    if (action === "complete") {
      contract.status = "completed";
      contract.statusLabel = "Completed";
      contract.escrowStatus = "released";
      contract.acceptedResult = contract.producedCargo;
      contract.adjustment = 0;
      contract.availableActions = [];
      return { ok: true, changed: true, message: `${contract.reference} completed. Escrow released.` };
    }
    if (action === "publish") {
      contract.status = "published";
      contract.statusLabel = "Available";
      contract.availableActions = [];
      return { ok: true, changed: true, message: `${contract.reference} published with funded escrow.` };
    }
    contract.status = action === "abandon" ? "failed" : "cancelled";
    contract.statusLabel = action === "abandon" ? "Failed · Abandoned" : "Cancelled";
    contract.escrowStatus = action === "abandon" ? "refunded" : "void";
    contract.availableActions = [];
    return {
      ok: true,
      changed: true,
      contextUpdate: action === "abandon" && context.role === "contractor" ? { role: "visitor" } : undefined,
      message: note?.trim() || `${contract.reference} ${contract.statusLabel.toLowerCase()}.`,
    };
  }

  private verifyContractStep(contractId: string, stepId: string, context: HubContextModel): IntentResult {
    const contract = this.workSupplies.contracts.find((item) => item.id === contractId);
    if (!contract || !context.capabilities.viewActiveContract || contract.contractor !== "Avery Cole" || contract.status !== "active") return { ok: false, message: "Contract progress is unavailable." };
    const step = contract.steps.find((item) => item.id === stepId);
    if (!step || step.completed) return { ok: false, message: "This verification step is no longer available." };
    step.completed = true;
    const completed = contract.steps.filter((item) => item.completed).length;
    contract.producedCargo = `${completed} of ${contract.steps.length} contract steps verified`;
    contract.availableActions = contract.steps.every((item) => item.completed)
      ? ["set_route_delivery", "submit", "abandon"]
      : ["set_route_field", "open_supplies", "abandon"];
    return { ok: true, changed: true, message: `${step.label} verified.` };
  }

  private createContract(input: Extract<ActionIntent, { type: "contract.create" }>["input"], context: HubContextModel): IntentResult {
    if (!context.capabilities.managePublicContracts) return { ok: false, message: "Contract publishing is not permitted." };
    if (!input.title.trim() || !input.objective.trim() || input.reward <= 0) return { ok: false, message: "Complete the funded contract terms." };
    const id = `pc-${String(this.contractSequence++).padStart(3, "0")}`;
    this.workSupplies.contracts.unshift({
      id, reference: id.toUpperCase(), title: input.title, status: "draft", statusLabel: "Draft", objective: input.objective, field: input.field, crop: "Tomatoes", scope: input.scope, deadline: input.deadline, reward: input.reward, escrowStatus: "reserved", materialsPolicy: "Contractor supplies all required materials.", fieldAccess: `${input.field} access after acceptance`, cargoOwnership: "All resulting cargo belongs to Sonar Farm.", deliveryDestination: `${input.field} verification marker`, producedCargo: "No cargo recorded", steps: [{ id: `${id}-step`, label: input.template, detail: input.scope, completed: false }], requirements: [input.requirements], failureRules: [input.failureRule], availableActions: ["publish", "cancel"], scopeRef: input.scopeRef, sourcePlanId: input.sourcePlanId,
    });
    if (input.sourcePlanId) this.fields.linkPlanToWork(input.sourcePlanId, "contract", id);
    return { ok: true, changed: true, entityId: id, message: `${id.toUpperCase()} created with reward held in escrow.` };
  }

  private createPurchase(payer: "personal" | "company", lines: Array<{ productId: string; quantity: number }>, context: HubContextModel): IntentResult {
    const allowed = payer === "personal" ? context.capabilities.buyPersonalSupplies : context.capabilities.buyCompanySupplies;
    if (!allowed || !lines.length) return { ok: false, message: "This purchase payer is unavailable." };
    const detailed = lines.map((line) => {
      const product = this.workSupplies.products.find((item) => item.id === line.productId);
      return product && line.quantity > 0 ? { ...line, name: product.name, unit: product.unit, unitPrice: product.unitPrice } : null;
    });
    if (detailed.some((line) => !line)) return { ok: false, message: "One or more cart lines are invalid." };
    const safeLines = detailed.filter((line): line is NonNullable<typeof line> => Boolean(line));
    const subtotal = safeLines.reduce((sum, line) => sum + line.quantity * line.unitPrice, 0);
    const fees = payer === "company" ? 0 : Math.round(subtotal * 0.025);
    const total = subtotal + fees;
    const balance = payer === "company" ? this.company.getCompanyBalance() : this.company.getPersonalBalance(context.actorId);
    const id = `pur-${this.purchaseSequence++}`;
    this.workSupplies.purchases.push({
      id, reference: id.toUpperCase(), payer, lines: safeLines, subtotal, fees, total, balance, projectedBalance: balance - total, budgetRemaining: payer === "company" ? this.company.getProcurementBudget() : undefined, transactionLimit: payer === "company" ? 1500 : undefined, ownership: payer === "company" ? "Company" : "Personal", inventoryCapacity: payer === "company" ? "18 of 40 company slots used" : "7 of 20 personal slots used", fulfillment: "Office Terminal · Supplier counter", status: "draft",
    });
    return { ok: true, changed: true, entityId: id, message: "Purchase draft ready for review." };
  }

  private confirmPurchase(purchaseId: string, context: HubContextModel): IntentResult {
    const purchase = this.workSupplies.purchases.find((item) => item.id === purchaseId);
    if (!purchase || purchase.status !== "draft") return { ok: false, message: "This purchase can no longer be confirmed." };
    if (!context.capabilities.physicalTransactions || context.presence !== "office") return { ok: false, closeSurface: true, message: "Complete this purchase at an Office Terminal." };
    if (purchase.payer === "company" && !context.capabilities.buyCompanySupplies) { purchase.failureReason = "permission_lost"; return { ok: false, message: "Company purchasing permission was removed." }; }
    const liveBalance = purchase.payer === "company" ? this.company.getCompanyBalance() : this.company.getPersonalBalance(context.actorId);
    if (purchase.total > liveBalance) { purchase.failureReason = "insufficient_funds"; return { ok: false, message: "The selected payer has insufficient funds." }; }
    if (purchase.payer === "company" && purchase.total > this.company.getProcurementBudget()) { purchase.failureReason = "budget_exceeded"; return { ok: false, message: "The procurement budget is insufficient." }; }
    if (purchase.payer === "company" && purchase.transactionLimit && purchase.total > purchase.transactionLimit && !context.capabilities.approveProcurement) { purchase.failureReason = "budget_exceeded"; return { ok: false, message: "This purchase exceeds your transaction limit and requires approval." }; }
    for (const line of purchase.lines) {
      const product = this.workSupplies.products.find((item) => item.id === line.productId);
      if (!product || (product.stock !== "base" && product.stock < line.quantity)) { purchase.failureReason = product?.stock === 0 ? "sold_out" : "stock_changed"; return { ok: false, message: product?.stock === 0 ? `${line.name} is sold out.` : `${line.name} stock changed before confirmation.` }; }
    }
    purchase.status = "delivered";
    purchase.receiptId = `SF-${Date.now().toString().slice(-6)}`;
    purchase.failureReason = undefined;
    for (const line of purchase.lines) {
      const product = this.workSupplies.products.find((item) => item.id === line.productId)!;
      if (product.stock !== "base") product.stock -= line.quantity;
      if (purchase.payer === "company") product.companyOwned += line.quantity;
      else product.personalOwned += line.quantity;
    }
    if (purchase.payer === "company") this.company.recordPurchase(purchase.total, purchase.id, context);
    else this.company.debitPersonal(context.actorId, purchase.total);
    return { ok: true, changed: true, receiptId: purchase.receiptId, message: `Purchase completed · receipt ${purchase.receiptId}.` };
  }

  private resolveProcurement(requestId: string, decision: "approve" | "reject", context: HubContextModel): IntentResult {
    if (!context.capabilities.approveProcurement) return { ok: false, message: "Procurement approval is not permitted." };
    const request = this.workSupplies.procurementRequests.find((item) => item.id === requestId);
    if (!request || request.status !== "pending") return { ok: false, message: "This procurement request is no longer pending." };
    request.status = decision === "approve" ? "approved" : "rejected";
    return { ok: true, changed: true, message: `${request.id.toUpperCase()} ${request.status}.` };
  }

  private transitionIssuedMaterial(materialId: string, action: "return" | "flag", context: HubContextModel): IntentResult {
    if (!context.capabilities.manageIssuedMaterials) return { ok: false, message: "Issued material management is not permitted." };
    const material = this.workSupplies.issuedMaterials.find((item) => item.id === materialId);
    if (!material || !material.availableActions.includes(action)) return { ok: false, message: "This material action is no longer available." };
    material.status = action === "return" ? "returned" : "discrepancy";
    material.availableActions = [];
    return { ok: true, changed: true, message: action === "return" ? `${material.asset} returned and custody closed.` : `${material.asset} discrepancy recorded for review.` };
  }
}

export const fixtureHubAdapter = new FixtureHubAdapter();
