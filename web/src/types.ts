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
  | { type: "assignment.resolveBlocker"; assignmentId: string; note: string };

export type HubViewRequest =
  | { kind: "hub"; route: HubRoute }
  | { kind: "assignmentDetail"; assignmentId: string };

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

export interface SupplyFixture {
  id: string;
  name: string;
  category: string;
  detail: string;
  stock: string;
  price: string;
  ownership: "Personal" | "Company" | "Supplier";
}

export interface CompanyModuleFixture {
  id: string;
  title: string;
  detail: string;
  value: string;
  permission?: keyof Omit<HubCapabilities, "routes">;
  surfaceRestriction?: HubSurface;
}
