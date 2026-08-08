import { useEffect } from "react";
import { Navigate, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { SurfaceStage } from "./components/SurfaceStage";
import { useHub } from "./store/HubContext";
import type { HubRoute } from "./types";
import { CompanyView } from "./views/CompanyView";
import { FieldsView } from "./views/FieldsView";
import { SuppliesView } from "./views/SuppliesView";
import { TodayView } from "./views/TodayView";
import { WorkView } from "./views/WorkView";

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
    const current = PATH_TO_ROUTE[location.pathname];
    if (current && !capabilities.routes.includes(current)) {
      navigate("/" + capabilities.routes[0], { replace: true });
    }
  }, [capabilities.routes, location.pathname, navigate]);

  return (
    <SurfaceStage>
      <Routes>
        <Route path="/today" element={<TodayView />} />
        <Route path="/fields" element={<FieldsView />} />
        <Route path="/work" element={<WorkView />} />
        <Route path="/supplies" element={<SuppliesView />} />
        <Route path="/company" element={<CompanyView />} />
        <Route path="*" element={<Navigate to={"/" + capabilities.routes[0]} replace />} />
      </Routes>
    </SurfaceStage>
  );
}
