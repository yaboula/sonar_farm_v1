import { Bank, Buildings, CaretRight, IdentificationCard, Package, ShieldCheck, ShoppingCartSimple, UsersThree, Warehouse, WarningCircle } from "@phosphor-icons/react";
import { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import { HubScaffold } from "../components/HubScaffold";
import { StatePanel } from "../components/StatePanel";
import type { CompanyArea, CompanyHomeData } from "../types";
import { useCompanyData } from "./company/useCompanyData";

const AREA_COPY: Record<CompanyArea, { label: string; description: string }> = {
  public: { label: "Company", description: "Identity and public access" },
  operations: { label: "Operations", description: "Assets moving through the farm" },
  people: { label: "People", description: "Employment and responsibility" },
  finance: { label: "Finance", description: "Funds, obligations and audit" },
  ownership: { label: "Ownership", description: "Protected company governance" },
};

const ICONS = { profile: Buildings, cargo: Package, warehouse: Warehouse, staff: UsersThree, application: UsersThree, treasury: Bank, ledger: Bank, leases: Buildings, roles: ShieldCheck, identity: IdentificationCard, sale: ShieldCheck, "public-sale": ShieldCheck };

export function CompanyView() {
  const request = useMemo(() => ({ kind: "companyHome" } as const), []);
  const { model, data, hub } = useCompanyData<CompanyHomeData>(request);
  const navigate = useNavigate();
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  const areas = (["public", "operations", "people", "finance", "ownership"] as CompanyArea[]).filter((area) => data.modules.some((item) => item.area === area));
  return (
    <HubScaffold eyebrow={hub.role === "visitor" || hub.role === "contractor" ? "Public business record" : "Business administration"} title="Company" subtitle={data.headline}>
      <div className="company-dashboard-head">
        <div><Buildings size={29} weight="thin" /><span><strong>{data.company.name} · {data.company.status === "for_sale" ? "Operating · For Sale" : "Operating"}</strong><small>{data.company.officeLocation}</small></span></div>
        {data.procurementLink ? <button type="button" onClick={() => navigate(data.procurementLink!.path)}><ShoppingCartSimple size={19} /><span><strong>${data.procurementLink.remaining.toLocaleString()}</strong><small>Procurement remaining</small></span><CaretRight size={17} /></button> : null}
      </div>
      <div className="company-area-stack">
        {areas.map((area) => <section className="company-area" key={area}>
          <header><div><span>{AREA_COPY[area].label}</span><p>{AREA_COPY[area].description}</p></div><em>{data.modules.filter((item) => item.area === area).length}</em></header>
          <div className="company-area-grid">
            {data.modules.filter((item) => item.area === area).map((module) => {
              const Icon = ICONS[module.id as keyof typeof ICONS] ?? Buildings;
              return <button type="button" className={`company-module company-module--${module.priority}`} key={module.id} onClick={() => navigate(module.path)}>
                <Icon size={27} weight="thin" />
                <span><strong>{module.title}</strong><small>{module.detail}</small></span>
                <div><b>{module.value}</b>{module.badge ? <em><WarningCircle size={14} />{module.badge}</em> : null}</div>
                <CaretRight size={17} />
              </button>;
            })}
          </div>
        </section>)}
      </div>
    </HubScaffold>
  );
}
