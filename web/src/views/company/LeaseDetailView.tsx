import { ArrowSquareOut, Coins, Plant, ShieldCheck } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { ConfirmDialog } from "../../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../../components/DeepViewShell";
import { StatePanel } from "../../components/StatePanel";
import type { CompanyLease } from "../../types";
import { useCompanyData } from "./useCompanyData";

export function LeaseDetailView() {
  const { leaseId = "" } = useParams();
  const request = useMemo(() => ({ kind: "companyLeaseDetail", leaseId } as const), [leaseId]);
  const { model, data, notice, pending, act } = useCompanyData<CompanyLease>(request);
  const navigate = useNavigate();
  const [confirm, setConfirm] = useState(false);
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} title="Field unavailable" body="This Field is missing or outside your authority." actionLabel="Back to Land & Fields" onAction={() => navigate("/company/leases")} />;
  const price = data.purchasePrice ?? data.recurringPrice ?? 0;
  const purchase = async () => {
    const operationId = typeof crypto.randomUUID === "function" ? crypto.randomUUID() : `field-${Date.now()}`;
    const result = await act({ type: "field.purchase", fieldId: data.fieldId, operationId });
    setConfirm(false);
    if (result.ok) navigate("/company/leases", { replace: true });
  };
  const preparePurchase = async () => {
    await act({ type: "field.preparePurchase", fieldId: data.fieldId });
  };
  return <DeepViewShell eyebrow="Permanent land record" title={data.fieldName} subtitle={data.location} breadcrumb={["Company", "Land & Fields", data.fieldName]} backLabel="Back to Land & Fields" onBack={() => navigate("/company/leases")} status={<StatusPill tone={data.ownedByCompany ? "success" : data.status === "available" ? "warning" : "neutral"}>{data.ownedByCompany ? "Owned" : data.status.replace("_", " ")}</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{data.ownedByCompany ? "Permanent Company property" : data.purchasePrepared ? "Prepared for Owner confirmation" : price ? `$${price.toLocaleString("en-US")} one-time acquisition` : "Not purchasable"}</span><p>{data.capacity} authoritative planting Slots</p></div><div className="domain-action-group">{data.availableActions.includes("open_field") ? <button type="button" className="domain-secondary-action" onClick={() => navigate(`/fields/${data.fieldId}`)}>Open Field<ArrowSquareOut size={17} /></button> : null}{data.availableActions.includes("prepare_purchase") ? <button type="button" className="domain-secondary-action" disabled={pending} onClick={() => void preparePurchase()}><ShieldCheck size={18} />Prepare Purchase</button> : null}{data.availableActions.includes("purchase") ? <button type="button" className="domain-primary-action" onClick={() => setConfirm(true)}><Coins size={18} />Purchase Field</button> : null}</div></>}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    <div className="domain-two-column lease-detail-layout"><div className="domain-card-stack"><DetailCard eyebrow="Property" title="Authority and value"><FactList facts={[{ label: "Field", value: data.fieldName }, { label: "Location", value: data.location }, { label: "Status", value: data.ownedByCompany ? "Permanent Company asset" : data.status.replace("_", " ") }, { label: "Purchase price", value: price ? `$${price.toLocaleString("en-US")}` : "Starter allocation" }, { label: "Recurring charge", value: "$0" }, { label: "Capacity", value: `${data.capacity} slots` }]} /></DetailCard><DetailCard eyebrow="Agronomic scope" title="Permitted crops"><div className="lease-crop-list">{data.allowedCrops.length ? data.allowedCrops.map((crop) => <span key={crop}><Plant size={16} />{crop}</span>) : <span><Plant size={16} />All configured crops</span>}</div></DetailCard></div><div className="domain-card-stack"><DetailCard eyebrow="Ownership boundary" title={data.ownedByCompany ? "Company controlled" : "Atomic acquisition"}><p className="domain-emphasis"><ShieldCheck size={23} />{data.ownedByCompany ? "Topology, plans and output remain attached to the Company." : data.ownerName ? `This Field is already owned by ${data.ownerName}.` : "Office presence, Owner authority, availability and Treasury are revalidated together."}</p></DetailCard><DetailCard eyebrow="Topology" title="Versioned land"><FactList facts={[{ label: "Rows", value: "Authoritative per revision" }, { label: "Slot identity", value: "Stable across runtime" }, { label: "Activation rule", value: "Field must be fully free" }]} /></DetailCard></div></div>
    {confirm ? <ConfirmDialog eyebrow="Owner authority" title={`Purchase ${data.fieldName}?`} confirmLabel="Confirm Permanent Purchase" pending={pending} onClose={() => setConfirm(false)} onConfirm={() => void purchase()}><FactList facts={[{ label: "Treasury debit", value: `$${price.toLocaleString("en-US")}` }, { label: "Ownership", value: "Permanent Company asset" }, { label: "Required presence", value: "Office Terminal" }, { label: "Ledger", value: "Immutable acquisition entry" }]} /></ConfirmDialog> : null}
  </DeepViewShell>;
}
