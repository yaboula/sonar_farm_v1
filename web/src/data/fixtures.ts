import type {
  CompanyModuleFixture,
  FarmRole,
  FieldFixture,
  HubCapabilities,
  HubRoute,
  SupplyFixture,
  WorkFixture,
} from "../types";

const MEMBER_ROUTES: HubRoute[] = ["today", "fields", "work", "supplies", "company"];

export const ROLE_LABELS: Record<FarmRole, string> = {
  visitor: "Visitor",
  contractor: "Contractor",
  worker: "Worker",
  procurement: "Procurement",
  supervisor: "Supervisor",
  manager: "Manager",
  owner: "Owner",
};

export function capabilitiesFor(role: FarmRole, surface: "office" | "tablet"): HubCapabilities {
  const isManagement = ["supervisor", "manager", "owner"].includes(role);
  const routes: HubRoute[] =
    role === "visitor"
      ? ["work", "supplies", "company"]
      : role === "contractor"
        ? MEMBER_ROUTES
        : MEMBER_ROUTES;

  return {
    routes,
    viewPrivateCompany: !["visitor", "contractor"].includes(role),
    viewFinancials: ["manager", "owner"].includes(role),
    manageStaff: ["manager", "owner"].includes(role),
    manageOperations: isManagement,
    companyProcurement: ["procurement", "manager", "owner"].includes(role),
    physicalTransactions: surface === "office" && !["visitor", "contractor"].includes(role),
  };
}

export const FIELDS: FieldFixture[] = [
  {
    id: "north-field",
    name: "North Field",
    crop: "Tomatoes",
    detail: "Rows 1–12 · 84 plants",
    status: "Needs attention",
    capacity: "84 / 96 slots",
    moisture: 38,
    lease: "Company owned",
  },
  {
    id: "greenhouse-2",
    name: "Greenhouse 2",
    crop: "Tomatoes",
    detail: "Rows A–F · 48 plants",
    status: "Ready",
    capacity: "48 / 48 slots",
    moisture: 74,
    lease: "Company owned",
  },
  {
    id: "east-field",
    name: "East Field",
    crop: "Lettuce",
    detail: "Plots 1–10 · 60 plants",
    status: "Healthy",
    capacity: "60 / 80 slots",
    moisture: 67,
    lease: "Lease · 12 days left",
  },
  {
    id: "orchard-annex",
    name: "Orchard Annex",
    crop: "Unassigned",
    detail: "Prepared plots · planting suspended",
    status: "Grace period",
    capacity: "0 / 64 slots",
    moisture: 51,
    lease: "Grace period · 19h left",
  },
];

export const WORK: WorkFixture[] = [
  {
    id: "asg-1048",
    type: "assignment",
    title: "Water North Field",
    meta: "Tomatoes · Rows 4–8 · Noah Reed",
    status: "In progress",
    deadline: "Today, 18:30",
    progress: 38,
  },
  {
    id: "asg-1052",
    type: "assignment",
    title: "Harvest Greenhouse 2",
    meta: "Tomatoes · Rows A–F · Noah Reed",
    status: "Accepted",
    deadline: "Tomorrow, 09:00",
    progress: 0,
  },
  {
    id: "bo-204",
    type: "buyerOrder",
    title: "County Produce Depot",
    meta: "18 Tomato Crates · Fine quality",
    status: "11 of 18 reserved",
    deadline: "Today, 21:00",
    progress: 61,
  },
  {
    id: "pc-078",
    type: "contract",
    title: "Prepare Tomato Row D",
    meta: "East Field · Contractor materials",
    status: "Available",
    deadline: "Tomorrow, 16:00",
    progress: 0,
  },
];

export const SUPPLIES: SupplyFixture[] = [
  {
    id: "tomato-seedling",
    name: "Tomato Seedling",
    category: "Seedlings",
    detail: "Healthy starter · greenhouse raised",
    stock: "Base stock",
    price: "$18 each",
    ownership: "Supplier",
  },
  {
    id: "watering-can",
    name: "Watering Can",
    category: "Hand Tools",
    detail: "8 L galvanized field can",
    stock: "4 remaining",
    price: "$240",
    ownership: "Supplier",
  },
  {
    id: "fertilizer-10",
    name: "Balanced Fertilizer",
    category: "Care",
    detail: "10 kg · controlled release",
    stock: "12 remaining",
    price: "$96",
    ownership: "Supplier",
  },
  {
    id: "issued-pruners",
    name: "Field Pruners",
    category: "Issued Materials",
    detail: "Assigned to Noah Reed",
    stock: "Return after shift",
    price: "Asset SF-118",
    ownership: "Company",
  },
];

export const COMPANY_MODULES: CompanyModuleFixture[] = [
  { id: "cargo", title: "Company Cargo", detail: "Produce currently in custody", value: "12 crates" },
  { id: "warehouse", title: "Warehouse", detail: "Stored produce and materials", value: "142 items", permission: "viewPrivateCompany" },
  { id: "staff", title: "Staff", detail: "Workers and applications", value: "6 active", permission: "manageStaff" },
  { id: "treasury", title: "Treasury", detail: "Company funds and reserved money", value: "$24,680", permission: "viewFinancials" },
  { id: "leases", title: "Leases", detail: "Land obligations and grace periods", value: "2 active", permission: "manageOperations" },
  { id: "procurement", title: "Procurement", detail: "Company purchases and issued stock", value: "3 pending", permission: "companyProcurement" },
  { id: "permissions", title: "Roles & Permissions", detail: "Operational access policy", value: "7 roles", permission: "manageStaff" },
  { id: "identity", title: "Company Identity", detail: "Name and public profile", value: "Sonar Farm", permission: "manageStaff" },
];
