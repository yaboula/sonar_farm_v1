import type { FarmRole, HubCapabilities } from "./types";

export const ROLE_LABELS: Record<FarmRole, string> = {
  visitor: "Visitor",
  contractor: "Contractor",
  worker: "Worker",
  procurement: "Procurement",
  supervisor: "Supervisor",
  manager: "Manager",
  owner: "Owner",
};

export const EMPTY_HUB_CAPABILITIES: HubCapabilities = {
  routes: [], viewPrivateCompany: false, viewFinancials: false, manageStaff: false,
  manageOperations: false, companyProcurement: false, physicalTransactions: false,
  viewOwnAssignments: false, viewTeamAssignments: false, createAssignments: false,
  manageBuyerOrders: false, browsePublicContracts: false, managePublicContracts: false,
  viewActiveContract: false, buyPersonalSupplies: false, buyCompanySupplies: false,
  approveProcurement: false, manageIssuedMaterials: false, viewFieldPortfolio: false,
  viewAssignedFieldDetail: false, viewTeamFieldDetail: false, viewFieldEconomics: false,
  viewFieldMaterialDemand: false, viewFieldHistory: false, createCropPlans: false,
  createFieldAssignments: false, createFieldContracts: false, setFieldRoute: false,
  viewCompanyProfile: false, viewOwnCompanyCargo: false, viewTeamCompanyCargo: false,
  viewWarehouse: false, manageWarehouse: false, sellWholesaleStock: false,
  viewStaff: false, reviewApplications: false, inviteStaff: false,
  viewProcurementLedger: false, viewTreasury: false, contributeTreasury: false,
  viewCompanyLedger: false, viewLeases: false, manageLeases: false,
  manageRolePolicies: false, renameCompany: false, sellBusiness: false, buyBusiness: false,
};
