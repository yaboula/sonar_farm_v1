import { Briefcase, Buildings, MapPin, ShoppingCartSimple, Storefront, UsersThree } from "@phosphor-icons/react";
import { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../../components/DeepViewShell";
import { StatePanel } from "../../components/StatePanel";
import type { CompanyProfile } from "../../types";
import { useCompanyData } from "./useCompanyData";

export function CompanyProfileView() {
  const request = useMemo(() => ({ kind: "companyProfile" } as const), []);
  const { model, data, notice, act } = useCompanyData<CompanyProfile>(request);
  const navigate = useNavigate();
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  return <DeepViewShell eyebrow="Public company record" title={data.company.name} subtitle={data.company.description} breadcrumb={["Company", "Company Profile"]} backLabel="Back to Company" onBack={() => navigate("/company")} status={<StatusPill tone={data.company.status === "operating" ? "success" : "warning"}>{data.company.status === "operating" ? "Operating" : "For Sale"}</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{data.publicContracts} public opportunities</span><p>{data.ownershipLabel}</p></div><div className="domain-action-group"><button className="domain-secondary-action" type="button" onClick={() => navigate("/supplies")}>Supply Market</button><button className="domain-primary-action" type="button" onClick={() => navigate(data.sale ? "/company/business-for-sale" : "/work?area=publicContracts")}>{data.sale ? "View Business Sale" : "View Public Contracts"}</button></div></>}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    <div className="domain-two-column">
      <div className="domain-card-stack">
        <DetailCard eyebrow="Business identity" title="Player-operated farming"><p className="domain-emphasis"><Buildings size={25} />{data.ownershipLabel}</p><FactList facts={[{ label: "Office", value: data.company.officeLocation }, { label: "Founded", value: data.company.foundedAt }, { label: "Applications", value: data.applicationsOpen ? "Open" : "Closed" }]} /></DetailCard>
        <DetailCard eyebrow="Public fields" title="Where the company operates"><div className="company-public-fields">{data.publicFields.map((field) => <article key={field.name}><MapPin size={20} /><span><strong>{field.name}</strong><small>{field.cropSummary}</small></span><em>{field.status}</em></article>)}</div></DetailCard>
      </div>
      <div className="domain-card-stack">
        <DetailCard eyebrow="Contractor terms" title="Clear access and ownership"><ul className="domain-check-list">{data.contractorTerms.map((term) => <li key={term}><Briefcase size={18} />{term}</li>)}</ul></DetailCard>
        <DetailCard eyebrow="Public paths" title="Work with the company"><div className="company-path-actions"><button type="button" onClick={() => navigate("/work?area=publicContracts")}><Briefcase size={20} /><span><strong>Public Contracts</strong><small>Contractor-funded field work</small></span></button>{data.applicationsOpen ? <button type="button" onClick={() => navigate("/company/jobs/apply")}><UsersThree size={20} /><span><strong>Apply for a Job</strong><small>Join internal Staff</small></span></button> : null}<button type="button" onClick={() => navigate("/supplies")}><ShoppingCartSimple size={20} /><span><strong>Supply Market</strong><small>Personal farming materials</small></span></button><button type="button" onClick={() => void act({ type: "company.setRoute", destination: "office" })}><Storefront size={20} /><span><strong>Set Route to Office</strong><small>{data.company.officeLocation}</small></span></button></div></DetailCard>
      </div>
    </div>
  </DeepViewShell>;
}
