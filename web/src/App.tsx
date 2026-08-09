import { useEffect } from "react";
import { Navigate, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { SurfaceStage } from "./components/SurfaceStage";
import { useHub } from "./store/HubContext";
import type { HubRoute } from "./types";
import { CompanyView } from "./views/CompanyView";
import { AssignmentDetailView } from "./views/AssignmentDetailView";
import { FieldsView } from "./views/FieldsView";
import { SuppliesView } from "./views/SuppliesView";
import { TodayView } from "./views/TodayView";
import { WorkView } from "./views/WorkView";
import { WorkCreateView } from "./views/WorkCreateView";
import { BuyerOrderDetailView } from "./views/BuyerOrderDetailView";
import { ContractDetailView } from "./views/ContractDetailView";
import { PurchaseReviewView } from "./views/PurchaseReviewView";
import { FieldDetailView } from "./views/FieldDetailView";
import { CompanyProfileView } from "./views/company/CompanyProfileView";
import { CompanyCargoView } from "./views/company/CompanyCargoView";
import { WarehouseView } from "./views/company/WarehouseView";
import { WholesaleReviewView } from "./views/company/WholesaleReviewView";
import { StaffView } from "./views/company/StaffView";
import { StaffMemberView } from "./views/company/StaffMemberView";
import { ApplicationsView } from "./views/company/ApplicationsView";
import { ApplicationReviewView } from "./views/company/ApplicationReviewView";
import { JobApplicationView } from "./views/company/JobApplicationView";
import { TreasuryView } from "./views/company/TreasuryView";
import { LedgerView } from "./views/company/LedgerView";
import { LeasesView } from "./views/company/LeasesView";
import { LeaseDetailView } from "./views/company/LeaseDetailView";
import { RolePoliciesView } from "./views/company/RolePoliciesView";
import { CompanyIdentityView } from "./views/company/CompanyIdentityView";
import { BusinessSaleView } from "./views/company/BusinessSaleView";
import { SaleReviewView } from "./views/company/SaleReviewView";
import { PublicBusinessSaleView } from "./views/company/PublicBusinessSaleView";
import { OwnershipTransferView } from "./views/company/OwnershipTransferView";
import { FRONTEND_V1_PATHS } from "./frontendV1Contract";

const PATH_TO_ROUTE: Record<string, HubRoute> = {
  [FRONTEND_V1_PATHS.today]: "today",
  [FRONTEND_V1_PATHS.fields]: "fields",
  [FRONTEND_V1_PATHS.work]: "work",
  [FRONTEND_V1_PATHS.supplies]: "supplies",
  [FRONTEND_V1_PATHS.company]: "company",
};

export function App() {
  const { capabilities } = useHub();
  const location = useLocation();
  const navigate = useNavigate();

  useEffect(() => {
    const current = PATH_TO_ROUTE[location.pathname] ?? (location.pathname.startsWith("/fields/") ? "fields" : location.pathname.startsWith("/work/") ? "work" : location.pathname.startsWith("/supplies/") ? "supplies" : location.pathname.startsWith("/company/") ? "company" : undefined);
    if (current && !capabilities.routes.includes(current)) {
      navigate("/" + capabilities.routes[0], { replace: true });
    }
  }, [capabilities.routes, location.pathname, navigate]);

  return (
    <SurfaceStage>
      <Routes>
        <Route path={FRONTEND_V1_PATHS.today} element={<TodayView />} />
        <Route path={FRONTEND_V1_PATHS.fields} element={<FieldsView />} />
        <Route path={FRONTEND_V1_PATHS.fieldDetail} element={<FieldDetailView />} />
        <Route path={FRONTEND_V1_PATHS.work} element={<WorkView />} />
        <Route path={FRONTEND_V1_PATHS.supplies} element={<SuppliesView />} />
        <Route path={FRONTEND_V1_PATHS.company} element={<CompanyView />} />
        <Route path={FRONTEND_V1_PATHS.companyProfile} element={<CompanyProfileView />} />
        <Route path={FRONTEND_V1_PATHS.companyCargo} element={<CompanyCargoView />} />
        <Route path={FRONTEND_V1_PATHS.companyWarehouse} element={<WarehouseView />} />
        <Route path={FRONTEND_V1_PATHS.companyWholesaleReview} element={<WholesaleReviewView />} />
        <Route path={FRONTEND_V1_PATHS.companyStaff} element={<StaffView />} />
        <Route path={FRONTEND_V1_PATHS.companyStaffMember} element={<StaffMemberView />} />
        <Route path={FRONTEND_V1_PATHS.companyApplications} element={<ApplicationsView />} />
        <Route path={FRONTEND_V1_PATHS.companyApplicationReview} element={<ApplicationReviewView />} />
        <Route path={FRONTEND_V1_PATHS.companyJobApplication} element={<JobApplicationView />} />
        <Route path={FRONTEND_V1_PATHS.companyTreasury} element={<TreasuryView />} />
        <Route path={FRONTEND_V1_PATHS.companyLedger} element={<LedgerView />} />
        <Route path={FRONTEND_V1_PATHS.companyLeases} element={<LeasesView />} />
        <Route path={FRONTEND_V1_PATHS.companyLeaseDetail} element={<LeaseDetailView />} />
        <Route path={FRONTEND_V1_PATHS.companyRolePolicies} element={<RolePoliciesView />} />
        <Route path={FRONTEND_V1_PATHS.companyIdentity} element={<CompanyIdentityView />} />
        <Route path={FRONTEND_V1_PATHS.companyBusinessSale} element={<BusinessSaleView />} />
        <Route path={FRONTEND_V1_PATHS.companySaleReview} element={<SaleReviewView />} />
        <Route path={FRONTEND_V1_PATHS.companySaleTransfer} element={<OwnershipTransferView />} />
        <Route path={FRONTEND_V1_PATHS.companyPublicSale} element={<PublicBusinessSaleView />} />
        <Route path={FRONTEND_V1_PATHS.companyPublicSaleTransfer} element={<OwnershipTransferView />} />
        <Route path={FRONTEND_V1_PATHS.assignmentDetail} element={<AssignmentDetailView />} />
        <Route path={FRONTEND_V1_PATHS.assignmentCreate} element={<WorkCreateView kind="assignment" />} />
        <Route path={FRONTEND_V1_PATHS.buyerOrderDetail} element={<BuyerOrderDetailView />} />
        <Route path={FRONTEND_V1_PATHS.contractCreate} element={<WorkCreateView kind="contract" />} />
        <Route path={FRONTEND_V1_PATHS.contractDetail} element={<ContractDetailView mode="public" />} />
        <Route path={FRONTEND_V1_PATHS.activeContract} element={<ContractDetailView mode="active" />} />
        <Route path={FRONTEND_V1_PATHS.contractProgress} element={<ContractDetailView mode="progress" />} />
        <Route path={FRONTEND_V1_PATHS.contractCompletion} element={<ContractDetailView mode="completion" />} />
        <Route path={FRONTEND_V1_PATHS.purchaseReview} element={<PurchaseReviewView />} />
        <Route path="*" element={<Navigate to={"/" + capabilities.routes[0]} replace />} />
      </Routes>
    </SurfaceStage>
  );
}
