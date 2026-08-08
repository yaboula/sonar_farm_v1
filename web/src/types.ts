export type HubSurface = "office" | "tablet";

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
}

export interface HubContextModel {
  role: FarmRole;
  surface: HubSurface;
  viewState: ViewState;
  capabilities: HubCapabilities;
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
  | { type: "issuedMaterial.transition"; materialId: string; action: "return" | "flag" };

export type HubViewRequest =
  | { kind: "hub"; route: HubRoute }
  | { kind: "assignmentDetail"; assignmentId: string }
  | { kind: "assignmentCreate" }
  | { kind: "buyerOrderDetail"; orderId: string }
  | { kind: "contractDetail"; contractId: string; mode: "public" | "active" | "progress" | "completion" }
  | { kind: "contractCreate" }
  | { kind: "purchaseReview"; purchaseId: string };

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
  contextUpdate?: { role?: FarmRole };
  receiptId?: string;
}

export interface HubAdapter {
  load<TData>(request: HubViewRequest, context: HubContextModel): Promise<HubViewModel<TData>>;
  dispatch(intent: ActionIntent, context: HubContextModel): Promise<IntentResult>;
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

export interface AssignmentCreateInput {
  title: string;
  objective: string;
  fieldId: string;
  crop: string;
  scope: string;
  assigneeId: string;
  supervisorId: string;
  deadline: string;
  payout: number;
  requirement: string;
  materialIds: string[];
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
  failureRule: string;
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

export type PurchaseStatus = "draft" | "processing" | "completed" | "failed";

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
