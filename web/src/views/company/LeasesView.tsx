import { ArrowRight, CalendarCheck, MapPin, Plant, Warning } from "@phosphor-icons/react";
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
  const visible = data.filter((lease) => filter === "all" || lease.status === filter);
  const operated = data.filter((lease) => ["starter", "active", "grace", "payment_due"].includes(lease.status));
  const grace = data.filter((lease) => lease.status === "grace");
  return <DeepViewShell eyebrow="Territorial obligations" title="Leases" subtitle="Land access, recurring costs and planting restrictions share one authoritative record" breadcrumb={["Company", "Leases"]} backLabel="Back to Company" onBack={() => navigate("/company")} status={<StatusPill tone={grace.length ? "danger" : "success"}>{grace.length ? `${grace.length} Grace Period` : `${operated.length} Operated`}</StatusPill>}>
    <div className="lease-summary-strip"><span><strong>{operated.length}</strong><small>Operated Fields</small></span><span><strong>${data.filter((lease) => lease.status === "active").reduce((sum, lease) => sum + lease.recurringPrice, 0).toLocaleString()}</strong><small>Recurring obligations</small></span><span><strong>{data.reduce((sum, lease) => sum + lease.capacity, 0)}</strong><small>Total listed capacity</small></span>{grace[0] ? <button type="button" onClick={() => navigate(`/company/leases/${grace[0].id}`)}><Warning size={18} /><span><strong>Grace Period</strong><small>{grace[0].graceDeadline}</small></span><ArrowRight size={15} /></button> : null}</div>
    <div className="company-list-toolbar"><FarmSelect size="compact" label="Lease Status" value={filter} options={[{ value: "all", label: "All land" }, ...Array.from(new Set(data.map((lease) => lease.status))).map((value) => ({ value, label: value.replace("_", " ") }))]} onChange={setFilter} /><p>Starter Field access is permanent and carries no recurring charge.</p></div>
    <DetailCard eyebrow="Land portfolio" title={`${visible.length} Lease records`}><div className="lease-card-grid">{visible.map((lease) => <button type="button" key={lease.id} data-status={lease.status} onClick={() => navigate(`/company/leases/${lease.id}`)}><div className="lease-card-head"><MapPin size={22} /><span><strong>{lease.fieldName}</strong><small>{lease.location}</small></span><em>{lease.status.replace("_", " ")}</em></div><div className="lease-card-facts"><span><b>{lease.capacity}</b><small>Slots</small></span><span><b>{lease.recurringPrice ? `$${lease.recurringPrice.toLocaleString()}` : "Included"}</b><small>{lease.billing}</small></span></div><p>{lease.activeCrops}</p>{lease.restriction ? <div className="lease-restriction"><Warning size={15} />{lease.restriction}</div> : <div className="lease-access"><Plant size={15} />{lease.nextPayment ? `Next payment · ${lease.nextPayment}` : "Permanent company access"}</div>}<span className="lease-open">Review Lease<ArrowRight size={15} /></span></button>)}</div>{!visible.length ? <div className="inline-empty"><CalendarCheck size={21} />No Leases match this status.</div> : null}</DetailCard>
  </DeepViewShell>;
}
