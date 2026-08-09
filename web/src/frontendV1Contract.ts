import type { FarmRole, HubPresence, HubRoute, HubSurface, ViewState } from "./types";

export const FRONTEND_V1_VERSION = "1.0.0" as const;
export const FRONTEND_V1_CANVAS = Object.freeze({ width: 1440, height: 810 });

export const FRONTEND_V1_PATHS = {
  today: "/today",
  fields: "/fields",
  fieldDetail: "/fields/:fieldId",
  work: "/work",
  assignmentCreate: "/work/assignments/new",
  assignmentDetail: "/work/assignments/:assignmentId",
  buyerOrderDetail: "/work/orders/:orderId",
  contractCreate: "/work/contracts/new",
  contractDetail: "/work/contracts/:contractId",
  activeContract: "/work/contracts/active/:contractId",
  contractProgress: "/work/contracts/active/:contractId/progress",
  contractCompletion: "/work/contracts/active/:contractId/completion",
  supplies: "/supplies",
  purchaseReview: "/supplies/purchases/:purchaseId/review",
  company: "/company",
  companyProfile: "/company/profile",
  companyCargo: "/company/cargo",
  companyWarehouse: "/company/warehouse",
  companyWholesaleReview: "/company/warehouse/wholesale/:saleId/review",
  companyStaff: "/company/staff",
  companyStaffMember: "/company/staff/:memberId",
  companyApplications: "/company/applications",
  companyApplicationReview: "/company/applications/:applicationId",
  companyJobApplication: "/company/jobs/apply",
  companyTreasury: "/company/treasury",
  companyLedger: "/company/ledger",
  companyLeases: "/company/leases",
  companyLeaseDetail: "/company/leases/:leaseId",
  companyRolePolicies: "/company/roles",
  companyIdentity: "/company/identity",
  companyBusinessSale: "/company/sale",
  companySaleReview: "/company/sale/review",
  companySaleTransfer: "/company/sale/transfer/:listingId",
  companyPublicSale: "/company/business-for-sale",
  companyPublicSaleTransfer: "/company/business-for-sale/transfer/:listingId",
} as const;

type FrontendV1PathKey = keyof typeof FRONTEND_V1_PATHS;

interface FrontendV1RouteRecord {
  key: FrontendV1PathKey;
  area: HubRoute;
  requestKind:
    | "hub"
    | "fieldsOverview"
    | "fieldDetail"
    | "assignmentCreate"
    | "assignmentDetail"
    | "buyerOrderDetail"
    | "contractCreate"
    | "contractDetail"
    | "purchaseReview"
    | "companyHome"
    | "companyProfile"
    | "companyCargo"
    | "companyWarehouse"
    | "companyWholesaleReview"
    | "companyStaff"
    | "companyStaffMember"
    | "companyApplications"
    | "companyApplicationReview"
    | "companyJobApplication"
    | "companyTreasury"
    | "companyLedger"
    | "companyLeases"
    | "companyLeaseDetail"
    | "companyRolePolicies"
    | "companyIdentity"
    | "companyBusinessSale"
    | "companySaleReview"
    | "companyPublicSale"
    | "companyOwnershipTransfer";
}

export const FRONTEND_V1_ROUTE_CATALOG = [
  { key: "today", area: "today", requestKind: "hub" },
  { key: "fields", area: "fields", requestKind: "fieldsOverview" },
  { key: "fieldDetail", area: "fields", requestKind: "fieldDetail" },
  { key: "work", area: "work", requestKind: "hub" },
  { key: "assignmentCreate", area: "work", requestKind: "assignmentCreate" },
  { key: "assignmentDetail", area: "work", requestKind: "assignmentDetail" },
  { key: "buyerOrderDetail", area: "work", requestKind: "buyerOrderDetail" },
  { key: "contractCreate", area: "work", requestKind: "contractCreate" },
  { key: "contractDetail", area: "work", requestKind: "contractDetail" },
  { key: "activeContract", area: "work", requestKind: "contractDetail" },
  { key: "contractProgress", area: "work", requestKind: "contractDetail" },
  { key: "contractCompletion", area: "work", requestKind: "contractDetail" },
  { key: "supplies", area: "supplies", requestKind: "hub" },
  { key: "purchaseReview", area: "supplies", requestKind: "purchaseReview" },
  { key: "company", area: "company", requestKind: "companyHome" },
  { key: "companyProfile", area: "company", requestKind: "companyProfile" },
  { key: "companyCargo", area: "company", requestKind: "companyCargo" },
  { key: "companyWarehouse", area: "company", requestKind: "companyWarehouse" },
  { key: "companyWholesaleReview", area: "company", requestKind: "companyWholesaleReview" },
  { key: "companyStaff", area: "company", requestKind: "companyStaff" },
  { key: "companyStaffMember", area: "company", requestKind: "companyStaffMember" },
  { key: "companyApplications", area: "company", requestKind: "companyApplications" },
  { key: "companyApplicationReview", area: "company", requestKind: "companyApplicationReview" },
  { key: "companyJobApplication", area: "company", requestKind: "companyJobApplication" },
  { key: "companyTreasury", area: "company", requestKind: "companyTreasury" },
  { key: "companyLedger", area: "company", requestKind: "companyLedger" },
  { key: "companyLeases", area: "company", requestKind: "companyLeases" },
  { key: "companyLeaseDetail", area: "company", requestKind: "companyLeaseDetail" },
  { key: "companyRolePolicies", area: "company", requestKind: "companyRolePolicies" },
  { key: "companyIdentity", area: "company", requestKind: "companyIdentity" },
  { key: "companyBusinessSale", area: "company", requestKind: "companyBusinessSale" },
  { key: "companySaleReview", area: "company", requestKind: "companySaleReview" },
  { key: "companySaleTransfer", area: "company", requestKind: "companyOwnershipTransfer" },
  { key: "companyPublicSale", area: "company", requestKind: "companyPublicSale" },
  { key: "companyPublicSaleTransfer", area: "company", requestKind: "companyOwnershipTransfer" },
] as const satisfies readonly FrontendV1RouteRecord[];

export const FRONTEND_V1_ROLES = [
  "visitor",
  "contractor",
  "worker",
  "procurement",
  "supervisor",
  "manager",
  "owner",
] as const satisfies readonly FarmRole[];

export const FRONTEND_V1_SURFACES = ["office", "tablet"] as const satisfies readonly HubSurface[];
export const FRONTEND_V1_PRESENCES = ["remote", "office", "warehouse", "registry"] as const satisfies readonly HubPresence[];
export const FRONTEND_V1_VIEW_STATES = ["ready", "loading", "empty", "blocked", "error", "restricted", "unavailable"] as const satisfies readonly ViewState[];

export const FRONTEND_V1_ESSENTIAL_FLOWS = [
  "business.initialPurchase",
  "staff.applicationHire",
  "contract.publicLifecycle",
  "assignment.internalLifecycle",
  "supplies.personalPurchase",
  "supplies.companyProcurement",
  "cargo.deposit",
  "buyerOrder.fulfillment",
  "warehouse.wholesale",
  "lease.gracePeriod",
  "business.resaleTransfer",
] as const;

export const FRONTEND_V1_INTEGRATION_BOUNDARY = Object.freeze({
  adapter: "HubAdapter",
  viewRequest: "HubViewRequest",
  actionIntent: "ActionIntent",
  result: "IntentResult",
  transportDefined: false,
  persistenceDefined: false,
});
