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

export interface ActionIntent {
  id: string;
  target: HubRoute;
  selectionKind?: SelectionKind;
  selectionId?: string;
}

export interface HubViewModel<TData = unknown> {
  route: HubRoute;
  state: ViewState;
  data: TData;
}

export interface IntentResult {
  ok: boolean;
  message?: string;
}

export interface HubAdapter {
  load<TData>(route: HubRoute, context: HubContextModel): Promise<HubViewModel<TData>>;
  dispatch(intent: ActionIntent, context: HubContextModel): Promise<IntentResult>;
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
