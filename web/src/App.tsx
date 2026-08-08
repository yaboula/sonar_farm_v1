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

const PATH_TO_ROUTE: Record<string, HubRoute> = {
  "/today": "today",
  "/fields": "fields",
  "/work": "work",
  "/supplies": "supplies",
  "/company": "company",
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
        <Route path="/today" element={<TodayView />} />
        <Route path="/fields" element={<FieldsView />} />
        <Route path="/fields/:fieldId" element={<FieldDetailView />} />
        <Route path="/work" element={<WorkView />} />
        <Route path="/supplies" element={<SuppliesView />} />
        <Route path="/company" element={<CompanyView />} />
        <Route path="/company/profile" element={<CompanyProfileView />} />
        <Route path="/company/cargo" element={<CompanyCargoView />} />
        <Route path="/work/assignments/:assignmentId" element={<AssignmentDetailView />} />
        <Route path="/work/assignments/new" element={<WorkCreateView kind="assignment" />} />
        <Route path="/work/orders/:orderId" element={<BuyerOrderDetailView />} />
        <Route path="/work/contracts/new" element={<WorkCreateView kind="contract" />} />
        <Route path="/work/contracts/:contractId" element={<ContractDetailView mode="public" />} />
        <Route path="/work/contracts/active/:contractId" element={<ContractDetailView mode="active" />} />
        <Route path="/work/contracts/active/:contractId/progress" element={<ContractDetailView mode="progress" />} />
        <Route path="/work/contracts/active/:contractId/completion" element={<ContractDetailView mode="completion" />} />
        <Route path="/supplies/purchases/:purchaseId/review" element={<PurchaseReviewView />} />
        <Route path="*" element={<Navigate to={"/" + capabilities.routes[0]} replace />} />
      </Routes>
    </SurfaceStage>
  );
}
