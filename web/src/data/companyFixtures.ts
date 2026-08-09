import type {
  BusinessSaleListing,
  CargoRecord,
  CompanyIdentityTerms,
  CompanyLease,
  CompanyRecord,
  LedgerEntry,
  RolePolicy,
  StaffApplication,
  StaffInvite,
  StaffMember,
  WarehouseItem,
  WarehouseReservation,
  WholesaleSale,
} from "../types";

export interface CompanyFixtureState {
  company: CompanyRecord;
  personalBalances: Record<string, number>;
  treasury: {
    available: number;
    escrowReserved: number;
    assignmentPayReserved: number;
    leaseObligations: number;
    pendingBuyerIncome: number;
    warehouseValuation: number;
    procurementBudget: number;
  };
  cargo: CargoRecord[];
  warehouseItems: WarehouseItem[];
  reservations: WarehouseReservation[];
  wholesaleSales: WholesaleSale[];
  staff: StaffMember[];
  applications: StaffApplication[];
  invitations: StaffInvite[];
  leases: CompanyLease[];
  rolePolicies: RolePolicy[];
  identity: CompanyIdentityTerms;
  ledger: LedgerEntry[];
  listing: BusinessSaleListing;
}

const policies: RolePolicy[] = [
  { role: "visitor", memberCount: 0, permissions: [{ id: "viewCompanyProfile", group: "operations", label: "View public profile", enabled: true, locked: true }, { id: "buyPersonalSupplies", group: "finance", label: "Buy personal supplies", enabled: true, locked: true }, { id: "buyBusiness", group: "ownership", label: "Buy listed business", enabled: true }], pendingChanges: 0 },
  { role: "contractor", memberCount: 1, permissions: [{ id: "viewOwnCompanyCargo", group: "operations", label: "View contract cargo", enabled: true }, { id: "viewFieldPortfolio", group: "operations", label: "Access contracted Field", enabled: true }, { id: "setFieldRoute", group: "operations", label: "Set route to contract scope", enabled: true }], pendingChanges: 0 },
  { role: "worker", memberCount: 2, permissions: [{ id: "viewOwnAssignments", group: "operations", label: "View own Assignments", enabled: true }, { id: "viewOwnCompanyCargo", group: "operations", label: "View own Company Cargo", enabled: true }, { id: "setFieldRoute", group: "operations", label: "Set route to assigned scope", enabled: true }], pendingChanges: 0 },
  { role: "procurement", memberCount: 1, permissions: [{ id: "buyCompanySupplies", group: "finance", label: "Buy Company supplies", enabled: true }, { id: "viewProcurementLedger", group: "finance", label: "View own purchase ledger", enabled: true }, { id: "viewFieldMaterialDemand", group: "operations", label: "View Field material demand", enabled: true }], transactionLimit: 1500, pendingChanges: 0 },
  { role: "supervisor", memberCount: 1, permissions: [{ id: "createAssignments", group: "operations", label: "Create Assignments", enabled: true }, { id: "viewTeamCompanyCargo", group: "operations", label: "View team Company Cargo", enabled: true }, { id: "viewWarehouse", group: "operations", label: "View Warehouse", enabled: true }, { id: "viewLeases", group: "finance", label: "View Field restrictions", enabled: true }], pendingChanges: 0 },
  { role: "manager", memberCount: 1, permissions: [{ id: "viewStaff", group: "people", label: "Manage Staff records", enabled: true }, { id: "reviewApplications", group: "people", label: "Review Job Applications", enabled: true }, { id: "inviteStaff", group: "people", label: "Invite Staff", enabled: true }, { id: "manageWarehouse", group: "operations", label: "Manage Warehouse", enabled: true }, { id: "viewTreasury", group: "finance", label: "View Treasury", enabled: true }, { id: "viewCompanyLedger", group: "finance", label: "View Company Ledger", enabled: true }, { id: "manageLeases", group: "finance", label: "Manage Leases", enabled: true }], transactionLimit: 5000, pendingChanges: 0 },
  { role: "owner", memberCount: 1, permissions: [{ id: "manageRolePolicies", group: "ownership", label: "Manage role policies", enabled: true, locked: true }, { id: "renameCompany", group: "ownership", label: "Rename Company", enabled: true, locked: true }, { id: "sellBusiness", group: "ownership", label: "Sell business", enabled: true, locked: true }, { id: "contributeTreasury", group: "finance", label: "Contribute personal funds", enabled: true, locked: true }], pendingChanges: 0 },
];

export function createCompanyFixtureState(): CompanyFixtureState {
  return {
    company: {
      id: "company-grapeseed",
      name: "Grapeseed Farm Co.",
      originalName: "Grapeseed Farm Co.",
      brandName: "Sonar Farm",
      status: "operating",
      ownerId: "staff-elijah",
      ownerName: "Elijah Mercer",
      description: "A player-operated produce company supplying northern San Andreas through verified field work.",
      officeLocation: "Grapeseed Farm Office · Union Road",
      foundedAt: "14 May 2026",
      capabilitiesRevision: 1,
    },
    personalBalances: {
      "actor-morgan": 215000,
      "actor-avery": 3420,
      "staff-noah": 1680,
      "staff-lena": 4120,
      "staff-jordan": 7350,
      "staff-maya": 18400,
      "staff-elijah": 42500,
    },
    treasury: {
      available: 24680,
      escrowReserved: 2400,
      assignmentPayReserved: 820,
      leaseObligations: 3600,
      pendingBuyerIncome: 4860,
      warehouseValuation: 18950,
      procurementBudget: 6200,
    },
    cargo: [
      { id: "cargo-tomato-12", reference: "CG-301", product: "Tomato Crates", quantity: 12, unit: "crates", quality: "Fine", source: "Greenhouse 2 · ASG-1052", custodianId: "staff-noah", custodian: "Noah Reed", ownership: "Company", linkedKind: "assignment", linkedId: "asg-1052", destination: "Farm Warehouse · Produce Bay", status: "carrying", restriction: "Cannot be sold, transferred or discarded outside the Farm Warehouse.", availableActions: ["set_route", "open_work"] },
      { id: "cargo-contract-04", reference: "CG-304", product: "Prepared Tomato Seedlings", quantity: 4, unit: "trays", quality: "Verified", source: "East Field · PC-083", custodianId: "actor-avery", custodian: "Avery Cole", ownership: "Company", linkedKind: "contract", linkedId: "pc-083", destination: "East Field Gate Store", status: "ready", restriction: "Contract cargo remains Company-owned after verification.", availableActions: ["set_route", "open_work"] },
      { id: "cargo-mismatch-02", reference: "CG-298", product: "Lettuce Crates", quantity: 2, unit: "crates", quality: "Unverified", source: "East Field · Row H", custodianId: "staff-sofia", custodian: "Sofia Bennett", ownership: "Company", linkedKind: "assignment", linkedId: "asg-1059", destination: "Farm Warehouse · Inspection Bay", status: "mismatch", restriction: "Quality verification required before deposit.", availableActions: ["set_route", "open_work"] },
    ],
    warehouseItems: [
      { id: "wh-tomato", name: "Tomato Crates", category: "produce", unit: "crates", total: 18, available: 7, reserved: 11, quality: [{ label: "Fine", quantity: 14 }, { label: "Standard", quantity: 4 }], incoming: 12, status: "reserved", location: "Produce Bay A" },
      { id: "wh-lettuce", name: "Lettuce Crates", category: "produce", unit: "crates", total: 9, available: 9, reserved: 0, quality: [{ label: "Fine", quantity: 6 }, { label: "Standard", quantity: 3 }], incoming: 2, status: "stocked", location: "Produce Bay B" },
      { id: "wh-seedlings", name: "Tomato Seedlings", category: "material", unit: "seedlings", total: 36, available: 28, reserved: 8, quality: [{ label: "Healthy", quantity: 36 }], incoming: 0, status: "stocked", location: "Materials Rack 2" },
      { id: "wh-crates", name: "Company Crates", category: "material", unit: "crates", total: 8, available: 2, reserved: 6, quality: [{ label: "Serviceable", quantity: 8 }], incoming: 0, status: "low", location: "Packing Bay" },
      { id: "wh-watering", name: "Watering Cans", category: "tool", unit: "tools", total: 3, available: 1, reserved: 2, quality: [{ label: "Serviceable", quantity: 2 }, { label: "Inspection due", quantity: 1 }], incoming: 0, status: "discrepancy", location: "Tool Cage", discrepancy: "Asset SF-118 is overdue for return by 3 hours." },
    ],
    reservations: [
      { id: "res-bo-204", itemId: "wh-tomato", quantity: 11, sourceKind: "buyer_order", sourceId: "bo-204", sourceLabel: "Paleto Fresh Tomato Order", status: "active" },
      { id: "res-asg-1052", itemId: "wh-crates", quantity: 6, sourceKind: "assignment", sourceId: "asg-1052", sourceLabel: "Harvest Greenhouse 2", status: "active" },
      { id: "res-pc-083", itemId: "wh-seedlings", quantity: 8, sourceKind: "contract", sourceId: "pc-083", sourceLabel: "Establish East Field Row D", status: "active" },
    ],
    wholesaleSales: [],
    staff: [
      { id: "staff-elijah", name: "Elijah Mercer", role: "owner", status: "active", joinedAt: "14 May 2026", lastActivity: "Today, 16:32", companyCargo: 0, issuedMaterials: 0, permissionExceptions: [], unresolvedIssues: [], availableActions: [] },
      { id: "staff-maya", name: "Maya Collins", role: "manager", status: "active", joinedAt: "19 May 2026", lastActivity: "Today, 15:48", activeAssignment: "Review BO-204", companyCargo: 0, issuedMaterials: 1, permissionExceptions: ["Warehouse transaction limit · $5,000"], unresolvedIssues: [], availableActions: ["suspend", "remove", "change_role"] },
      { id: "staff-jordan", name: "Jordan Tate", role: "supervisor", status: "active", joinedAt: "28 May 2026", lastActivity: "Today, 16:21", activeAssignment: "Supervising ASG-1048", companyCargo: 0, issuedMaterials: 0, permissionExceptions: [], unresolvedIssues: [], availableActions: ["suspend", "remove", "change_role"] },
      { id: "staff-lena", name: "Lena Brooks", role: "procurement", status: "active", joinedAt: "02 Jun 2026", lastActivity: "Today, 14:42", companyCargo: 0, issuedMaterials: 2, permissionExceptions: ["Purchase limit · $1,500"], unresolvedIssues: ["One asset return overdue"], availableActions: ["suspend", "remove", "change_role"] },
      { id: "staff-noah", name: "Noah Reed", role: "worker", status: "active", joinedAt: "11 Jun 2026", lastActivity: "Today, 16:24", activeAssignment: "ASG-1048 · Water North Field", companyCargo: 12, issuedMaterials: 1, permissionExceptions: [], unresolvedIssues: [], availableActions: ["suspend", "remove", "change_role"] },
      { id: "staff-sofia", name: "Sofia Bennett", role: "worker", status: "active", joinedAt: "18 Jun 2026", lastActivity: "Today, 15:10", activeAssignment: "ASG-1059 · Inspect East Field", companyCargo: 2, issuedMaterials: 1, permissionExceptions: [], unresolvedIssues: ["Cargo quality mismatch"], availableActions: ["suspend", "remove", "change_role"] },
    ],
    applications: [
      { id: "app-morgan", applicantId: "actor-morgan", applicant: "Morgan Hayes", introduction: "Available for careful greenhouse and packing work.", availability: "Weekday evenings and Saturday mornings", preferredWork: "Harvest and packing", rulesAccepted: true, submittedAt: "Today, 10:18", updatedAt: "Today, 10:18", status: "submitted", proposedRole: "worker", availableActions: ["interview", "accept", "reject"] },
      { id: "app-riley", applicantId: "actor-riley", applicant: "Riley Ward", introduction: "Interested in field preparation and irrigation.", availability: "Most afternoons", preferredWork: "Planting and care", rulesAccepted: true, submittedAt: "Yesterday, 18:42", updatedAt: "Today, 09:15", status: "under_review", reviewer: "Maya Collins", warning: "Public Contract PC-078 completed with one correction.", proposedRole: "worker", availableActions: ["interview", "accept", "reject"] },
    ],
    invitations: [],
    leases: [
      { id: "lease-north", fieldId: "north-field", fieldName: "North Field", location: "Grapeseed · North access gate", status: "starter", recurringPrice: 0, billing: "Permanent starter field", capacity: 96, allowedCrops: ["Tomato", "Lettuce", "Potato", "Carrot"], activeCrops: "Tomatoes · 84 occupied", linkedWork: ["ASG-1048", "BO-204"], availableActions: ["open_field"] },
      { id: "lease-east", fieldId: "east-field", fieldName: "East Field", location: "Grapeseed · East service track", status: "active", recurringPrice: 1800, billing: "Every 14 days", nextPayment: "20 Aug, 06:00", capacity: 80, allowedCrops: ["Tomato", "Lettuce", "Potato"], activeCrops: "Lettuce · Tomato Row planned", linkedWork: ["PC-083"], availableActions: ["pay", "end", "open_field"] },
      { id: "lease-orchard", fieldId: "orchard-annex", fieldName: "Orchard Annex", location: "Grapeseed · Annex gate", status: "grace", recurringPrice: 1800, billing: "Every 14 days", nextPayment: "Overdue", graceDeadline: "Tomorrow, 11:30", capacity: 64, allowedCrops: ["Tomato", "Potato", "Carrot"], activeCrops: "Empty · prepared soil", linkedWork: [], restriction: "Planting suspended · care and harvest remain permitted", availableActions: ["pay", "end", "open_field"] },
      { id: "lease-riverside", fieldId: "riverside-patch", fieldName: "Riverside Patch", location: "Alamo Sea · South track", status: "available", recurringPrice: 2400, billing: "Every 14 days", capacity: 120, allowedCrops: ["Lettuce", "Potato", "Carrot"], activeCrops: "Not leased", linkedWork: [], availableActions: ["start"] },
    ],
    rolePolicies: structuredClone(policies),
    identity: { currentName: "Grapeseed Farm Co.", originalName: "Grapeseed Farm Co.", lastRenamedAt: undefined, renameCost: 2500, cooldownEndsAt: undefined, namingRules: ["3–28 characters", "Letters, numbers, spaces, apostrophes and hyphens", "No protected public-service names"], available: true },
    ledger: [
      { id: "txn-410", idempotencyKey: "buyer-order:bo-198:payment", type: "buyer_order", amount: 3240, direction: "credit", actorId: "system-buyer", actor: "County Produce Depot", at: "Today, 13:05", source: "County Produce Depot", destination: "Grapeseed Farm Co. Treasury", linkedKind: "buyer_order", linkedId: "bo-198", status: "completed", balanceAfter: 24680 },
      { id: "txn-409", idempotencyKey: "purchase:pur-299", type: "purchase", amount: 720, direction: "debit", actorId: "staff-lena", actor: "Lena Brooks", at: "Today, 11:14", source: "Grapeseed Farm Co. Treasury", destination: "Grapeseed Agricultural Supply", linkedKind: "purchase", linkedId: "pur-299", status: "completed", balanceAfter: 21440 },
      { id: "txn-408", idempotencyKey: "contract:pc-083:escrow", type: "contract_escrow", amount: 640, direction: "reserve", actorId: "staff-maya", actor: "Maya Collins", at: "Yesterday, 14:20", source: "Grapeseed Farm Co. Treasury", destination: "PC-083 Escrow", linkedKind: "contract", linkedId: "pc-083", status: "escrowed", balanceAfter: 22160 },
      { id: "txn-407", idempotencyKey: "lease:lease-east:payment:2026-08", type: "lease", amount: 1800, direction: "debit", actorId: "staff-elijah", actor: "Elijah Mercer", at: "01 Aug, 06:00", source: "Grapeseed Farm Co. Treasury", destination: "East Field Lease", linkedKind: "lease", linkedId: "lease-east", status: "completed", balanceAfter: 22800 },
    ],
    listing: { id: "sale-001", version: 1, companyId: "company-grapeseed", companyName: "Grapeseed Farm Co.", sellerId: "staff-elijah", sellerName: "Elijah Mercer", askingPrice: 180000, suggestedValuation: 164500, treasuryIncluded: 24680, warehouseValuation: 18950, activeLeases: 2, staffCount: 6, activeObligations: 7200, saleFee: 9000, sellerProceeds: 171000, escrowAmount: 0, expiresAt: undefined, status: "draft", buyerConfirmed: false, sellerConfirmed: false, initialSale: false, availableActions: ["save", "publish"] },
  };
}
