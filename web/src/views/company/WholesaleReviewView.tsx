import { CheckCircle, CurrencyDollar, ShieldCheck, Warehouse } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useLocation, useNavigate, useParams } from "react-router-dom";
import { ConfirmDialog } from "../../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../../components/DeepViewShell";
import { StatePanel } from "../../components/StatePanel";
import type { WholesaleSale } from "../../types";
import { useCompanyData } from "./useCompanyData";

export function WholesaleReviewView() {
  const { saleId = "" } = useParams();
  const request = useMemo(() => ({ kind: "companyWholesaleReview", saleId } as const), [saleId]);
  const { model, data, notice, pending, act, context } = useCompanyData<WholesaleSale>(request);
  const [confirm, setConfirm] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();
  const returnTo = (location.state as { returnTo?: string } | null)?.returnTo ?? "/company/warehouse";
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} title="Wholesale draft unavailable" body="The draft identifier is missing, expired or outside your authority." actionLabel="Back to Warehouse" onAction={() => navigate(returnTo)} />;
  const completed = data.status === "completed";
  const submit = async () => { const result = await act({ type: "warehouse.confirmWholesale", saleId: data.id }); setConfirm(false); if (result.ok) return; };
  return <DeepViewShell eyebrow="Guaranteed surplus channel" title={completed ? "Wholesale Receipt" : "Wholesale Review"} subtitle={`${data.reference} · ${data.itemName} · ${data.quality}`} breadcrumb={["Company", "Warehouse", data.reference]} backLabel="Back to Warehouse" onBack={() => navigate(returnTo)} status={<StatusPill tone={completed ? "success" : "warning"}>{completed ? "Completed" : "Draft"}</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{completed ? `Ledger ${data.ledgerEntryId}` : context.presence === "warehouse" ? "Physical transfer available" : "Warehouse presence required"}</span><p>{completed ? "Stock and Treasury updated atomically" : "Stock revalidates at confirmation"}</p></div>{completed ? <button type="button" className="domain-secondary-action" onClick={() => navigate(returnTo)}>Return to Warehouse</button> : context.presence === "warehouse" ? <button type="button" className="domain-primary-action" onClick={() => setConfirm(true)}><ShieldCheck size={18} />Confirm Wholesale Sale</button> : <button type="button" className="domain-primary-action" onClick={() => void act({ type: "company.setRoute", destination: "warehouse" })}>Set Route to Warehouse</button>}</>}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    <div className="domain-two-column"><div className="domain-card-stack"><DetailCard eyebrow="Stock transfer" title={`${data.quantity} units`}><p className="domain-emphasis"><Warehouse size={24} />{data.itemName} · {data.quality}</p><FactList facts={[{ label: "Available before", value: data.availableBefore }, { label: "Transfer quantity", value: data.quantity }, { label: "Available after", value: data.availableAfter }, { label: "Reserved stock", value: "Unaffected" }]} /></DetailCard>{completed ? <DetailCard eyebrow="Atomic result" title="Company records updated"><ul className="domain-check-list"><li><CheckCircle size={18} />Unreserved Warehouse stock reduced</li><li><CheckCircle size={18} />Treasury credited</li><li><CheckCircle size={18} />Immutable Ledger entry issued</li></ul></DetailCard> : null}</div><DetailCard eyebrow="Settlement" title={`$${data.payout.toLocaleString()}`}><p className="domain-emphasis"><CurrencyDollar size={24} />Guaranteed wholesale payout</p><FactList facts={[{ label: "Unit price", value: `$${data.unitPrice}` }, { label: "Quantity", value: data.quantity }, { label: "Destination", value: "Grapeseed Farm Co. Treasury" }, { label: "Channel", value: "System wholesaler · below Buyer Orders" }]} /></DetailCard></div>
    {confirm ? <ConfirmDialog eyebrow="Warehouse transfer" title="Sell this unreserved stock?" confirmLabel="Confirm Wholesale Sale" pending={pending} onClose={() => setConfirm(false)} onConfirm={() => void submit()}><p>This removes {data.quantity} {data.itemName} from available stock and credits ${data.payout.toLocaleString()} to Treasury.</p><p className="dialog-callout"><ShieldCheck size={18} />Reservations and Buyer Orders remain untouched.</p></ConfirmDialog> : null}
  </DeepViewShell>;
}
