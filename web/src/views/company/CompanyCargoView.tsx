import { ArrowSquareOut, MapPin, Package, ShieldCheck, Warning } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../../components/DeepViewShell";
import { StatePanel } from "../../components/StatePanel";
import type { CargoRecord, CompanyCargoData } from "../../types";
import { useCompanyData } from "./useCompanyData";

const tone = (cargo: CargoRecord) => cargo.status === "mismatch" ? "danger" : cargo.status === "completed" ? "success" : "warning";

export function CompanyCargoView() {
  const request = useMemo(() => ({ kind: "companyCargo" } as const), []);
  const { model, data, notice, act } = useCompanyData<CompanyCargoData>(request);
  const navigate = useNavigate();
  const [selectedId, setSelectedId] = useState<string>();
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  const selected = data.records.find((item) => item.id === selectedId) ?? data.records[0];
  const openWork = (cargo: CargoRecord) => navigate(cargo.linkedKind === "assignment" ? `/work/assignments/${cargo.linkedId}` : cargo.linkedKind === "contract" ? `/work/contracts/active/${cargo.linkedId}` : `/work/orders/${cargo.linkedId}`, { state: { returnTo: "/company/cargo" } });
  return <DeepViewShell eyebrow="Company-owned inventory" title="Company Cargo" subtitle={`${data.scopeLabel} · ownership and destination remain authoritative`} breadcrumb={["Company", "Company Cargo"]} backLabel="Back to Company" onBack={() => navigate("/company")} status={<StatusPill tone={selected && tone(selected)}>{selected?.status.replace("_", " ") ?? "Empty"}</StatusPill>} actionBar={selected ? <><div className="domain-action-summary"><span>{selected.reference} · {selected.quantity} {selected.unit}</span><p>{selected.destination}</p></div><div className="domain-action-group"><button type="button" className="domain-secondary-action" onClick={() => openWork(selected)}>Open Work</button><button type="button" className="domain-primary-action" onClick={() => void act({ type: "companyCargo.setRoute", cargoId: selected.id })}><MapPin size={18} />Set Route to Warehouse</button></div></> : undefined}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    {!data.records.length ? <div className="inline-empty">No Company Cargo is currently assigned to this custody scope.</div> : <div className="domain-two-column company-cargo-layout">
      <DetailCard eyebrow="Custody register" title={`${data.records.length} active cargo record${data.records.length === 1 ? "" : "s"}`}><div className="company-cargo-list">{data.records.map((cargo) => <button type="button" className={cargo.id === selected?.id ? "is-selected" : ""} key={cargo.id} onClick={() => setSelectedId(cargo.id)}><Package size={24} /><span><strong>{cargo.product}</strong><small>{cargo.reference} · {cargo.source}</small></span><b>{cargo.quantity} {cargo.unit}</b><em data-tone={tone(cargo)}>{cargo.status.replace("_", " ")}</em></button>)}</div></DetailCard>
      {selected ? <div className="domain-card-stack"><DetailCard eyebrow="Selected cargo" title={selected.product}><p className="domain-emphasis"><Package size={24} />{selected.quantity} {selected.unit} · {selected.quality}</p><FactList facts={[{ label: "Custodian", value: selected.custodian }, { label: "Ownership", value: selected.ownership }, { label: "Source", value: selected.source }, { label: "Destination", value: selected.destination }, { label: "Linked Work", value: selected.linkedId.toUpperCase() }]} /></DetailCard><DetailCard eyebrow="Transfer control" title={selected.status === "mismatch" ? "Review required" : "Protected custody"}><p className={`domain-emphasis ${selected.status === "mismatch" ? "warning" : ""}`}>{selected.status === "mismatch" ? <Warning size={23} /> : <ShieldCheck size={23} />}{selected.restriction}</p><button type="button" className="company-inline-link" onClick={() => openWork(selected)}>Open linked Work<ArrowSquareOut size={17} /></button></DetailCard></div> : null}
    </div>}
  </DeepViewShell>;
}
