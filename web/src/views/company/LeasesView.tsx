import { ArrowRight, CalendarCheck, MapPin, Plant } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { DeepViewShell, DetailCard, StatusPill } from "../../components/DeepViewShell";
import { FarmSelect } from "../../components/FarmSelect";
import { StatePanel } from "../../components/StatePanel";
import type { CompanyLease, LeaseStatus } from "../../types";
import { useCompanyData } from "./useCompanyData";

export function LeasesView() {
  const request = useMemo(() => ({ kind: "companyLeases" } as const), []);
  const { model, data } = useCompanyData<CompanyLease[]>(request);
  const navigate = useNavigate();
  const [filter, setFilter] = useState<LeaseStatus | "all">("all");
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  const visible = data.filter((field) => filter === "all" || field.status === filter);
  const operated = data.filter((field) => field.ownedByCompany || ["starter", "owned", "purchase", "active"].includes(field.status));
  const available = data.filter((field) => field.status === "available");
  return <DeepViewShell eyebrow="Permanent Company land" title="Land & Fields" subtitle="Starter property, owned Fields and available acquisitions share one authoritative record" breadcrumb={["Company", "Land & Fields"]} backLabel="Back to Company" onBack={() => navigate("/company")} status={<StatusPill tone="success">{operated.length} Owned</StatusPill>}>
    <div className="lease-summary-strip"><span><strong>{operated.length}</strong><small>Owned Fields</small></span><span><strong>{available.length}</strong><small>Available to purchase</small></span><span><strong>{data.reduce((sum, field) => sum + field.capacity, 0)}</strong><small>Catalog capacity</small></span></div>
    <div className="company-list-toolbar"><FarmSelect size="compact" label="Property Status" value={filter} options={[{ value: "all", label: "All land" }, ...Array.from(new Set(data.map((field) => field.status))).map((value) => ({ value, label: value.replace("_", " ") }))]} onChange={setFilter} /><p>Fields are permanent Company assets. There are no recurring land charges.</p></div>
    <DetailCard eyebrow="Land portfolio" title={`${visible.length} Field records`}><div className="lease-card-grid">{visible.map((field) => <button type="button" key={field.id} data-status={field.status} onClick={() => navigate(`/company/leases/${field.id}`)}><div className="lease-card-head"><MapPin size={22} /><span><strong>{field.fieldName}</strong><small>{field.location}</small></span><em>{field.status.replace("_", " ")}</em></div><div className="lease-card-facts"><span><b>{field.capacity}</b><small>Slots</small></span><span><b>{field.ownedByCompany ? "Owned" : `$${(field.purchasePrice ?? field.recurringPrice ?? 0).toLocaleString("en-US")}`}</b><small>{field.ownedByCompany ? "Permanent asset" : "One-time purchase"}</small></span></div><div className="lease-access"><Plant size={15} />{field.ownedByCompany ? "Permanent Company access" : field.ownerName ? `Owned by ${field.ownerName}` : "Available at Office"}</div><span className="lease-open">Review Field<ArrowRight size={15} /></span></button>)}</div>{!visible.length ? <div className="inline-empty"><CalendarCheck size={21} />No Fields match this status.</div> : null}</DetailCard>
  </DeepViewShell>;
}
