export type HubSurface = "office" | "tablet";

export type HubPresence = "remote" | "office" | "warehouse" | "registry";

export type FarmRole =
  | "visitor"
  | "contractor"
  | "worker"
  | "procurement"
  | "supervisor"
  | "manager"
  | "owner";

export type HubRoute = "today" | "fields" | "work" | "supplies" | "company";

export type ViewState =
  | "ready"
  | "loading"
  | "empty"
  | "blocked"
  | "error"
  | "restricted"
  | "unavailable";

export type SelectionKind =
  | "assignment"
  | "cargo"
  | "field"
  | "row"
  | "slot"
  | "cropPlan"
  | "buyerOrder"
  | "contract"
  | "supply"
  | "companyModule";

export interface HubCapabilities {
  routes: HubRoute[];
  viewPrivateCompany: boolean;
  viewFinancials: boolean;
  manageStaff: boolean;
  manageOperations: boolean;
  companyProcurement: boolean;
  physicalTransactions: boolean;
  viewOwnAssignments: boolean;
  viewTeamAssignments: boolean;
  createAssignments: boolean;
  manageBuyerOrders: boolean;
  browsePublicContracts: boolean;
  managePublicContracts: boolean;
  viewActiveContract: boolean;
  buyPersonalSupplies: boolean;
  buyCompanySupplies: boolean;
  approveProcurement: boolean;
  manageIssuedMaterials: boolean;
  viewFieldPortfolio: boolean;
  viewAssignedFieldDetail: boolean;
  viewTeamFieldDetail: boolean;
  viewFieldEconomics: boolean;
  viewFieldMaterialDemand: boolean;
  viewFieldHistory: boolean;
  createCropPlans: boolean;
  createFieldAssignments: boolean;
  createFieldContracts: boolean;
  setFieldRoute: boolean;
  viewCompanyProfile: boolean;
  viewOwnCompanyCargo: boolean;
  viewTeamCompanyCargo: boolean;
  viewWarehouse: boolean;
  manageWarehouse: boolean;
  sellWholesaleStock: boolean;
  viewStaff: boolean;
  reviewApplications: boolean;
  inviteStaff: boolean;
  viewProcurementLedger: boolean;
  viewTreasury: boolean;
  contributeTreasury: boolean;
  viewCompanyLedger: boolean;
  viewLeases: boolean;
  manageLeases: boolean;
  manageRolePolicies: boolean;
  renameCompany: boolean;
  sellBusiness: boolean;
  buyBusiness: boolean;
}

export interface HubContextModel {
  actorId: string;
  role: FarmRole;
  surface: HubSurface;
  presence: HubPresence;
  capabilitiesRevision: number;
  viewState: ViewState;
  capabilities: HubCapabilities;
  serverTime?: number;
  selectedKind?: SelectionKind;
  selectedId?: string;
}

export interface NavigationIntent {
  type: "navigate";
  id: string;
  target: HubRoute;
  path?: string;
  selectionKind?: SelectionKind;
  selectionId?: string;
}

export type AssignmentStatus =
  | "assigned"
  | "accepted"
  | "in_progress"
  | "blocked"
  | "awaiting_review"
  | "completed"
  | "failed"
  | "expired"
  | "cancelled";

export type AvailableAssignmentAction =
  | "accept"
  | "resume"
  | "submit"
  | "approve"
  | "request_correction"
  | "reassign"
  | "cancel"
  | "resolve_blocker";

export type ActionIntent =
  | { type: "assignment.accept"; assignmentId: string }
  | { type: "assignment.resume"; assignmentId: string }
  | { type: "assignment.submit"; assignmentId: string }
  | { type: "assignment.approve"; assignmentId: string; note?: string }
  | { type: "assignment.requestCorrection"; assignmentId: string; note: string }
  | { type: "assignment.reassign"; assignmentId: string; assigneeId: string }
  | { type: "assignment.cancel"; assignmentId: string; reason: string }
  | { type: "assignment.resolveBlocker"; assignmentId: string; note: string }
  | { type: "assignment.create"; input: AssignmentCreateInput }
  | { type: "buyerOrder.transition"; orderId: string; action: BuyerOrderAction }
  | { type: "contract.accept"; contractId: string }
  | { type: "contract.verifyStep"; contractId: string; stepId: string }
  | { type: "contract.transition"; contractId: string; action: ContractAction; note?: string }
  | { type: "contract.create"; input: ContractCreateInput }
  | { type: "purchase.createDraft"; payer: SupplyPayer; lines: PurchaseLineInput[] }
  | { type: "purchase.confirm"; purchaseId: string }
  | { type: "procurement.resolve"; requestId: string; decision: "approve" | "reject" }
  | { type: "issuedMaterial.transition"; materialId: string; action: "return" | "flag"; operationId?: string }
  | { type: "cropPlan.create"; input: CropPlanInput }
  | { type: "cropPlan.update"; planId: string; input: CropPlanInput }
  | { type: "cropPlan.cancel"; planId: string }
  | { type: "field.setRoute"; scope: FieldScopeRef }
  | { type: "field.preparePurchase"; fieldId: string }
  | { type: "field.purchase"; fieldId: string; operationId: string }
  | { type: "cargo.deposit"; cargoId: string; quantity: number; operationId: string }
  | { type: "companyCargo.setRoute"; cargoId: string }
  | { type: "company.setRoute"; destination: "office" | "warehouse" | "registry" }
  | { type: "warehouse.prepareOrder"; reservationId: string }
  | { type: "warehouse.withdraw"; itemId: string; quantity: number; operationId: string }
  | { type: "warehouse.createWholesale"; itemId: string; quantity: number; quality: string }
  | { type: "warehouse.confirmWholesale"; saleId: string }
  | { type: "jobApplication.saveDraft"; input: JobApplicationInput }
  | { type: "jobApplication.submit"; input: JobApplicationInput }
  | { type: "jobApplication.withdraw"; applicationId: string }
  | { type: "staffApplication.transition"; applicationId: string; action: "interview" | "accept" | "reject"; role?: FarmRole }
  | { type: "staff.invite"; candidateId: string; role: FarmRole }
  | { type: "staffInvitation.accept"; invitationId: string }
  | { type: "staff.transition"; memberId: string; action: "suspend" | "reinstate" | "remove" | "change_role"; role?: FarmRole }
  | { type: "treasury.contribute"; amount: number }
  | { type: "lease.transition"; leaseId: string; action: "start" | "pay" | "end" }
  | { type: "rolePolicy.save"; role: FarmRole; permissions: string[]; transactionLimit?: number }
  | { type: "rolePolicy.reset"; role: FarmRole }
  | { type: "company.rename"; name: string }
  | { type: "businessSale.saveDraft"; askingPrice: number }
  | { type: "businessSale.publish"; listingId: string }
  | { type: "businessSale.cancel"; listingId: string }
  | { type: "businessSale.reserve"; listingId: string }
  | { type: "businessSale.confirm"; listingId: string; party: "buyer" | "seller" };

export type HubViewRequest =
  | { kind: "hub"; route: HubRoute }
  | { kind: "assignmentDetail"; assignmentId: string }
  | { kind: "assignmentCreate" }
  | { kind: "buyerOrderDetail"; orderId: string }
  | { kind: "contractDetail"; contractId: string; mode: "public" | "active" | "progress" | "completion" }
  | { kind: "contractCreate" }
  | { kind: "purchaseReview"; purchaseId: string }
  | { kind: "fieldsOverview" }
  | { kind: "fieldDetail"; fieldId: string }
  | { kind: "companyHome" }
  | { kind: "companyProfile" }
  | { kind: "companyCargo" }
  | { kind: "companyWarehouse" }
  | { kind: "companyWholesaleReview"; saleId: string }
  | { kind: "companyStaff" }
  | { kind: "companyStaffMember"; memberId: string }
  | { kind: "companyApplications" }
  | { kind: "companyApplicationReview"; applicationId: string }
  | { kind: "companyJobApplication" }
  | { kind: "companyTreasury" }
  | { kind: "companyLedger" }
  | { kind: "companyLeases" }
  | { kind: "companyLeaseDetail"; leaseId: string }
  | { kind: "companyRolePolicies" }
  | { kind: "companyIdentity" }
  | { kind: "companyBusinessSale" }
  | { kind: "companySaleReview" }
  | { kind: "companyPublicSale" }
  | { kind: "companyOwnershipTransfer"; listingId: string };

export interface HubViewModel<TData = unknown> {
  request: HubViewRequest;
  state: ViewState;
  data: TData | null;
}

export interface IntentResult {
  ok: boolean;
  message?: string;
  changed?: boolean;
  closeSurface?: boolean;
  entityId?: string;
  contextUpdate?: { role?: FarmRole; capabilitiesRevision?: number };
  receiptId?: string;
  invalidated?: string[];
  handoff?: { kind: "route" | "world"; scope: FieldScopeRef };
}

export type FieldDeltaListener = (delta: FieldDelta) => void;

export interface HubAdapter {
  bootstrap?(): Promise<HubContextModel>;
  close?(): Promise<void>;
  load<TData>(request: HubViewRequest, context: HubContextModel): Promise<HubViewModel<TData>>;
  dispatch(intent: ActionIntent, context: HubContextModel): Promise<IntentResult>;
  subscribeField(fieldId: string, afterSequence: number, context: HubContextModel, listener: FieldDeltaListener): () => void;
}

export interface AssignmentRequirement {
  id: string;
  label: string;
  detail: string;
  current: number;
  target: number;
  unit: string;
  status: "pending" | "verified" | "failed";
  lastVerifiedAt?: string;
}

export interface IssuedMaterial {
  id: string;
  name: string;
  quantity: string;
  ownership: "Company" | "Personal";
  returnRequired: boolean;
  status: "issued" | "missing" | "returned";
}

export interface ProgressEvent {
  id: string;
  at: string;
  title: string;
  detail: string;
  actor: string;
  tone: "neutral" | "positive" | "warning";
}

export interface PayoutTerms {
  amount: number;
  currency: "USD";
  status: "reserved" | "pending_review" | "released" | "void";
  conditions: string[];
}

export interface AssignmentDetail {
  id: string;
  reference: string;
  title: string;
  status: AssignmentStatus;
  statusLabel: string;
  workType: string;
  objective: string;
  crop: string;
  field: { id: string; name: string; scope: string; routeLabel: string };
  assignee: { id: string; name: string; role: string };
  supervisor: { id: string; name: string };
  deadline: string;
  deadlineIso: string;
  requirements: AssignmentRequirement[];
  issuedMaterials: IssuedMaterial[];
  payout: PayoutTerms;
  progress: ProgressEvent[];
  cancellationSummary: string;
  blocker?: { title: string; detail: string; raisedAt: string };
  reviewerNote?: string;
  availableActions: AvailableAssignmentAction[];
  eligibleAssignees?: Array<{ id: string; name: string; role: string }>;
  scopeRef?: FieldScopeRef;
  sourcePlanId?: string;
}

export interface FieldFixture {
  id: string;
  name: string;
  crop: string;
  detail: string;
  status: "Healthy" | "Needs attention" | "Ready" | "Grace period";
  capacity: string;
  moisture: number;
  lease: string;
}

export type FieldLayer = "overview" | "water" | "health" | "growth" | "readiness" | "work" | "plan";
export type FieldSeverity = "info" | "warning" | "critical";
export type FieldOperationalStatus =
  | "active"
  | "attention"
  | "ready"
  | "empty"
  | "planting_suspended"
  | "grace"
  | "lease_expired"
  | "inaccessible"
  | "unavailable";
export type FieldSlotStatus = "empty" | "planned" | "occupied";
export type CropPlanStatus = "draft" | "reserved" | "in_execution" | "completed" | "cancelled";
export type AttentionKind =
  | "water_low"
  | "health_loss"
  | "harvest_ready"
  | "spoilage_risk"
  | "planned_empty"
  | "plan_conflict"
  | "work_deadline"
  | "material_shortage"
  | "access_restriction"
  | "pest"
  | "fertilizer"
  | "pruning"
  | "tie";

export interface FieldPoint {
  x: number;
  y: number;
}

export interface FieldScopeRef {
  fieldId: string;
  rowIds?: string[];
}

export interface PlantState {
  id: string;
  crop: string;
  cropLabel: string;
  stage: string;
  progress: number;
  water: number;
  health: number;
  spoilage: number;
  plantedAt: string;
  maturesAt: string;
  lastCareAt: string;
  readiness: "growing" | "ready" | "at_risk";
}

export interface FieldSlot {
  id: string;
  legacyIndex: number;
  rowId: string;
  label: string;
  position: FieldPoint;
  status: FieldSlotStatus;
  plant?: PlantState;
  plannedCrop?: string;
  diagnosticIds: string[];
  assignmentId?: string;
  contractId?: string;
  visible: boolean;
}

export interface FieldRow {
  id: string;
  label: string;
  order: number;
  slotIds: string[];
  plannedCrop?: string;
  cropLabel: string;
  occupied: number;
  planned: number;
  available: number;
  averageWater?: number;
  averageHealth?: number;
  averageGrowth?: number;
  readyCount: number;
  criticalCount: number;
  status: "empty" | "planned" | "growing" | "attention" | "ready" | "blocked" | "restricted";
  assignmentIds: string[];
  contractIds: string[];
  materialDemand?: string;
  visibleDetail: boolean;
}

export interface FieldTopology {
  fieldId: string;
  topologyRevision: string;
  orientation: number;
  rows: FieldRow[];
  slots: FieldSlot[];
  bounds: { width: number; height: number };
}

export interface FieldDiagnostic {
  id: string;
  kind: AttentionKind;
  severity: FieldSeverity;
  scope: "field" | "row" | "slot";
  scopeId: string;
  title: string;
  cause: string;
  evidence: string;
  window: string;
  impact: string;
  recommendedAction: string;
  availableAction?: "open_assignment" | "create_assignment" | "create_contract" | "set_route";
}

export interface FieldEvent {
  id: string;
  type: "planted" | "watered" | "inspected" | "harvested" | "plan_changed" | "work_linked" | "access_changed" | "restriction_applied";
  at: string;
  actor: string;
  title: string;
  detail: string;
  rowId?: string;
  slotId?: string;
}

export interface CropPlan {
  id: string;
  reference: string;
  fieldId: string;
  rowIds: string[];
  crop: string;
  cropLabel: string;
  status: CropPlanStatus;
  statusLabel: string;
  eligibleSlots: number;
  excludedSlots: Array<{ slotId: string; reason: string }>;
  materialEstimate: string[];
  linkedAssignmentId?: string;
  linkedContractId?: string;
  createdAt: string;
  updatedAt: string;
}

export interface CropPlanInput {
  fieldId: string;
  rowIds: string[];
  crop: string;
}

export interface FieldOverview {
  id: string;
  name: string;
  location: string;
  status: FieldOperationalStatus;
  statusLabel: string;
  ownership: string;
  leaseExpiresAt?: string;
  restriction?: string;
  occupied: number;
  planned: number;
  capacity: number;
  cropSummary: string;
  attentionCount: number;
  criticalCount: number;
  activeAssignments: number;
  materialDemand?: string;
  nextMilestone: string;
  yieldForecast?: string;
  permittedRowIds?: string[];
}

export interface FieldDetail extends FieldOverview {
  topology: FieldTopology;
  diagnostics: FieldDiagnostic[];
  events: FieldEvent[];
  cropPlans: CropPlan[];
  linkedWork: Array<{ id: string; kind: "assignment" | "contract" | "buyer_order"; title: string; status: string; scope: string }>;
  materialNeeds: Array<{ id: string; item: string; quantity: string; status: string }>;
  serverTime: string;
  stateRevision: string;
  sequence: number;
  availableActions: Array<"create_plan" | "create_assignment" | "create_contract" | "set_route">;
}

export interface FieldsOverviewData {
  fields: FieldOverview[];
  landing: "attention" | "assignment" | "materials" | "contract";
  activeScope?: FieldScopeRef;
  headline: string;
}

export type FieldDelta =
  | { kind: "slot_upsert"; fieldId: string; topologyRevision: string; sequence: number; slot: FieldSlot }
  | { kind: "plan_upsert"; fieldId: string; topologyRevision: string; sequence: number; plan: CropPlan }
  | { kind: "plan_remove"; fieldId: string; topologyRevision: string; sequence: number; planId: string }
  | { kind: "invalidate"; fieldId: string; topologyRevision: string; sequence: number; reason: string };

export interface FieldSubscription {
  fieldId: string;
  topologyRevision: string;
  afterSequence: number;
}

export interface FieldSyncState {
  topologyRevision: string;
  sequence: number;
  slots: Record<string, FieldSlot>;
  plans: Record<string, CropPlan>;
  resyncRequired: boolean;
}

export interface WorkFixture {
  id: string;
  type: "assignment" | "buyerOrder" | "contract";
  title: string;
  meta: string;
  status: string;
  deadline: string;
  progress: number;
  assigneeId?: string;
}

export type WorkArea = "assignments" | "buyerOrders" | "publicContracts" | "activeContract";

export interface WorkQueueData {
  areas: WorkArea[];
  items: WorkFixture[];
  canCreateAssignment: boolean;
  canCreateContract: boolean;
}

export type FarmingWorkAction = "plant" | "water" | "fertilize" | "weed" | "treat_pest" | "harvest";
export interface WorkRequirementInput {
  action: FarmingWorkAction;
  rowIds: string[];
  crop?: string;
  itemTier?: "basic" | "plus" | "pro";
  target: number;
  thresholdKey?: "water" | "nutrients" | "weeds" | "pests" | "quality";
  thresholdValue?: number;
}

export interface WorkCreateData {
  nextReference: string;
  serverNow: number;
  fields: Array<{ id: string; name: string; description: string }>;
  members: Array<{ id: string; name: string; role: string }>;
  plans: Array<{ id: string; reference: string; fieldId: string; crop: string; rowIds: string[] }>;
}

export interface AssignmentCreateInput {
  title: string;
  objective: string;
  fieldId: string;
  crop: string;
  scope: string;
  assigneeId: string;
  supervisorId: string;
  deadline: string;
  deadlineAt?: number;
  payout: number;
  requirement: string;
  requirements?: WorkRequirementInput[];
  materialIds: string[];
  scopeRef?: FieldScopeRef;
  sourcePlanId?: string;
}

export type BuyerOrderStatus = "open" | "accepted" | "planned" | "reserved" | "ready" | "completed" | "rejected";
export type BuyerOrderAction = "accept" | "plan" | "create_assignment" | "reserve" | "prepare" | "complete" | "reject";

export interface BuyerOrderDetail {
  id: string;
  reference: string;
  buyer: string;
  buyerType: string;
  product: string;
  quantity: number;
  unit: string;
  quality: string;
  status: BuyerOrderStatus;
  statusLabel: string;
  deadline: string;
  deadlineAt?: number;
  destination: string;
  payout: number;
  reservedQuantity: number;
  fulfillment: string;
  cargoOwnership: string;
  linkedAssignments: Array<{ id: string; title: string; status: string }>;
  terms: string[];
  availableActions: BuyerOrderAction[];
}

export type ContractStatus = "draft" | "published" | "reserved" | "active" | "awaiting_review" | "completed" | "failed" | "expired" | "cancelled";
export type ContractAction = "accept" | "publish" | "set_route_field" | "open_supplies" | "set_route_delivery" | "submit" | "complete" | "abandon" | "cancel";

export interface ContractStep {
  id: string;
  label: string;
  detail: string;
  completed: boolean;
}

export interface ContractDetail {
  id: string;
  reference: string;
  title: string;
  status: ContractStatus;
  statusLabel: string;
  objective: string;
  field: string;
  crop: string;
  scope: string;
  contractor?: string;
  deadline: string;
  reward: number;
  escrowStatus: "reserved" | "released" | "refunded" | "void";
  materialsPolicy: string;
  fieldAccess: string;
  cargoOwnership: string;
  deliveryDestination: string;
  producedCargo: string;
  acceptedResult?: string;
  adjustment?: number;
  steps: ContractStep[];
  requirements: string[];
  failureRules: string[];
  availableActions: ContractAction[];
  scopeRef?: FieldScopeRef;
  sourcePlanId?: string;
}

export interface ContractCreateInput {
  template: string;
  title: string;
  objective: string;
  field: string;
  scope: string;
  deadline: string;
  reward: number;
  requirements: string;
  structuredRequirements?: WorkRequirementInput[];
  failureRule: string;
  scopeRef?: FieldScopeRef;
  sourcePlanId?: string;
}

export interface SupplyFixture {
  id: string;
  name: string;
  category: string;
  detail: string;
  stock: string;
  price: string;
  ownership: "Personal" | "Company" | "Supplier";
}

export type SupplyPayer = "personal" | "company";

export interface SupplyProduct {
  id: string;
  name: string;
  category: "Seedlings" | "Seeds" | "Hand Tools" | "Watering" | "Fertilizer" | "Pest Treatment";
  cropRelation: string;
  detail: string;
  unit: string;
  unitPrice: number;
  stock: number | "base";
  restock: string;
  personalOwned: number;
  companyOwned: number;
  tier?: "basic" | "plus" | "pro";
  effect?: string;
  image?: string;
  leadMinutes?: number;
  applications?: number;
}

export interface PurchaseLineInput {
  productId: string;
  quantity: number;
}

export interface PurchaseLine extends PurchaseLineInput {
  name: string;
  unit: string;
  unitPrice: number;
}

export type PurchaseStatus = "draft" | "approval_required" | "approved" | "ordered" | "in_transit" | "delivered" | "failed" | "rejected";

export interface PurchaseReview {
  id: string;
  reference: string;
  payer: SupplyPayer;
  lines: PurchaseLine[];
  subtotal: number;
  fees: number;
  total: number;
  balance: number;
  projectedBalance: number;
  budgetRemaining?: number;
  transactionLimit?: number;
  ownership: "Personal" | "Company";
  inventoryCapacity: string;
  fulfillment: string;
  status: PurchaseStatus;
  failureReason?: "insufficient_funds" | "budget_exceeded" | "permission_lost" | "stock_changed" | "sold_out" | "inventory_full" | "unavailable";
  receiptId?: string;
  draftId?: string;
  dueAt?: number;
  canConfirm?: boolean;
  canApprove?: boolean;
}

export interface ProcurementRequest {
  id: string;
  requestedBy: string;
  summary: string;
  amount: number;
  status: "pending" | "approved" | "rejected";
}

export interface IssuedMaterialRecord {
  id: string;
  asset: string;
  worker: string;
  assignment: string;
  issued: number;
  used: number;
  remaining: number;
  unit: string;
  status: "issued" | "return_due" | "returned" | "discrepancy";
  availableActions: Array<"return" | "flag">;
}

export interface SuppliesHubData {
  products: SupplyProduct[];
  allowedPayers: SupplyPayer[];
  personalBalance: number;
  companyBalance?: number;
  procurement?: {
    monthlyBudget: number;
    remaining: number;
    transactionLimit: number;
    allowedCategories: string[];
    recentPurchases: Array<{ id: string; detail: string; amount: number; at: string }>;
    requests: ProcurementRequest[];
    violations: string[];
  };
  issuedMaterials: IssuedMaterialRecord[];
}

export interface CompanyModuleFixture {
  id: string;
  title: string;
  detail: string;
  value: string;
  permission?: keyof Omit<HubCapabilities, "routes">;
  surfaceRestriction?: HubSurface;
}

export type CompanyOperationalStatus = "operating" | "for_sale" | "temporarily_unavailable" | "unowned";
export type CompanyArea = "public" | "operations" | "people" | "finance" | "ownership";

export interface CompanyRecord {
  id: string;
  name: string;
  originalName: string;
  brandName: "Sonar Farm";
  status: CompanyOperationalStatus;
  ownerId?: string;
  ownerName?: string;
  description: string;
  officeLocation: string;
  foundedAt: string;
  capabilitiesRevision: number;
}

export interface CompanyHomeModule {
  id: string;
  area: CompanyArea;
  title: string;
  detail: string;
  value: string;
  path: string;
  priority: "critical" | "attention" | "normal";
  badge?: string;
}

export interface CompanyHomeData {
  company: CompanyRecord;
  headline: string;
  modules: CompanyHomeModule[];
  procurementLink?: { remaining: number; pending: number; path: string };
}

export interface CompanyProfile {
  company: CompanyRecord;
  ownershipLabel: string;
  publicFields: Array<{ name: string; cropSummary: string; status: string }>;
  publicContracts: number;
  applicationsOpen: boolean;
  contractorTerms: string[];
  sale?: { listingId: string; askingPrice: number; status: string };
  availableActions: Array<"contracts" | "sale" | "apply" | "supplies" | "route">;
}

export type CargoStatus = "carrying" | "partial_deposit" | "ready" | "completed" | "mismatch";
export interface CargoRecord {
  id: string;
  reference: string;
  product: string;
  quantity: number;
  unit: string;
  quality: string;
  source: string;
  custodianId: string;
  custodian: string;
  ownership: "Company";
  linkedKind: "assignment" | "contract" | "buyer_order";
  linkedId: string;
  destination: string;
  status: CargoStatus;
  restriction: string;
  availableActions: Array<"set_route" | "open_work">;
}

export interface CompanyCargoData {
  records: CargoRecord[];
  scopeLabel: string;
  warehousePresence: boolean;
}

export type WarehouseItemStatus = "stocked" | "low" | "reserved" | "full" | "discrepancy";
export interface WarehouseReservation {
  id: string;
  itemId: string;
  quantity: number;
  sourceKind: "buyer_order" | "assignment" | "contract";
  sourceId: string;
  sourceLabel: string;
  status: "active" | "prepared" | "released";
}

export interface WarehouseItem {
  id: string;
  name: string;
  category: "produce" | "material" | "tool";
  unit: string;
  total: number;
  available: number;
  reserved: number;
  quality: Array<{ label: string; quantity: number }>;
  incoming: number;
  status: WarehouseItemStatus;
  location: string;
  discrepancy?: string;
}

export interface WarehouseData {
  items: WarehouseItem[];
  reservations: WarehouseReservation[];
  incomingCargo: CargoRecord[];
  capacity: { used: number; total: number };
  atWarehouse: boolean;
  canManage: boolean;
  canSellWholesale: boolean;
}

export interface WholesaleSale {
  id: string;
  reference: string;
  itemId: string;
  itemName: string;
  quality: string;
  quantity: number;
  unitPrice: number;
  payout: number;
  availableBefore: number;
  availableAfter: number;
  status: "draft" | "processing" | "completed" | "failed";
  failureReason?: string;
  ledgerEntryId?: string;
}

export type StaffStatus = "active" | "off_duty" | "suspended" | "pending_removal";
export interface StaffMember {
  id: string;
  name: string;
  role: FarmRole;
  status: StaffStatus;
  joinedAt: string;
  lastActivity: string;
  activeAssignment?: string;
  companyCargo: number;
  issuedMaterials: number;
  permissionExceptions: string[];
  unresolvedIssues: string[];
  availableActions: Array<"suspend" | "reinstate" | "remove" | "change_role">;
}

export type ApplicationStatus = "draft" | "submitted" | "under_review" | "interview" | "accepted" | "rejected" | "withdrawn";
export interface JobApplicationInput {
  introduction: string;
  availability: string;
  preferredWork: string;
  rulesAccepted: boolean;
}

export interface StaffApplication extends JobApplicationInput {
  id: string;
  applicantId: string;
  applicant: string;
  submittedAt?: string;
  updatedAt: string;
  status: ApplicationStatus;
  reviewer?: string;
  warning?: string;
  proposedRole: FarmRole;
  availableActions: Array<"submit" | "withdraw" | "interview" | "accept" | "reject">;
}

export interface StaffInvite {
  id: string;
  candidateId: string;
  candidate: string;
  role: FarmRole;
  invitedBy: string;
  expiresAt: string;
  status: "pending" | "accepted" | "declined" | "expired";
}

export interface StaffData {
  members: StaffMember[];
  applications: StaffApplication[];
  invitations: StaffInvite[];
  candidates: Array<{ id: string; name: string; eligible: boolean; reason?: string }>;
  assignableRoles: FarmRole[];
}

export interface CompanyJobData {
  application?: StaffApplication;
  invitation?: StaffInvite;
}

export type LedgerStatus = "completed" | "pending" | "escrowed" | "released" | "refunded" | "reversed" | "failed";
export interface LedgerEntry {
  id: string;
  idempotencyKey: string;
  type: "purchase" | "field_purchase" | "assignment_pay" | "contract_escrow" | "buyer_order" | "lease" | "wholesale" | "rename" | "owner_contribution" | "business_sale";
  amount: number;
  direction: "credit" | "debit" | "reserve" | "release";
  actorId: string;
  actor: string;
  at: string;
  source: string;
  destination: string;
  linkedKind?: string;
  linkedId?: string;
  status: LedgerStatus;
  balanceAfter: number;
  reason?: string;
}

export interface TreasurySnapshot {
  available: number;
  escrowReserved: number;
  assignmentPayReserved: number;
  leaseObligations: number;
  pendingBuyerIncome: number;
  warehouseValuation: number;
  personalBalance?: number;
  recentEntries: LedgerEntry[];
  availableActions: Array<"ledger" | "contribute">;
}

export type LeaseStatus = "starter" | "purchase" | "owned" | "available" | "active" | "payment_due" | "grace" | "expired" | "ended";
export interface CompanyLease {
  id: string;
  fieldId: string;
  fieldName: string;
  location: string;
  status: LeaseStatus;
  recurringPrice: number;
  purchasePrice?: number;
  billing: string;
  nextPayment?: string;
  graceDeadline?: string;
  capacity: number;
  allowedCrops: string[];
  activeCrops: string;
  linkedWork: string[];
  ownedByCompany?: boolean;
  ownerName?: string;
  purchasePrepared?: boolean;
  purchasePreparedBy?: string;
  restriction?: string;
  availableActions: Array<"start" | "pay" | "end" | "prepare_purchase" | "purchase" | "open_field">;
}

export interface RolePolicy {
  role: FarmRole;
  memberCount: number;
  permissions: Array<{ id: string; group: "operations" | "people" | "finance" | "ownership"; label: string; enabled: boolean; locked?: boolean }>;
  transactionLimit?: number;
  pendingChanges: number;
}

export interface CompanyIdentityTerms {
  currentName: string;
  originalName: string;
  lastRenamedAt?: string;
  renameCost: number;
  cooldownEndsAt?: string;
  namingRules: string[];
  available: boolean;
}

export type SaleListingStatus = "not_listed" | "draft" | "published" | "reserved" | "awaiting_seller" | "locked" | "completed" | "cancelled" | "expired" | "listing_changed";
export interface BusinessSaleListing {
  id: string;
  version: number;
  companyId: string;
  companyName: string;
  sellerId?: string;
  sellerName?: string;
  buyerId?: string;
  buyerName?: string;
  askingPrice: number;
  suggestedValuation: number;
  treasuryIncluded: number;
  warehouseValuation: number;
  activeLeases: number;
  staffCount: number;
  activeObligations: number;
  saleFee: number;
  sellerProceeds: number;
  escrowAmount: number;
  expiresAt?: string;
  status: SaleListingStatus;
  buyerConfirmed: boolean;
  sellerConfirmed: boolean;
  initialSale: boolean;
  availableActions: Array<"save" | "publish" | "cancel" | "reserve" | "confirm_buyer" | "confirm_seller">;
}

export interface OwnershipTransfer {
  listing: BusinessSaleListing;
  company: CompanyRecord;
  buyerFunds: number;
  assets: string[];
  liabilities: string[];
  staffContinuity: string;
  formerOwnerExit: string;
}
