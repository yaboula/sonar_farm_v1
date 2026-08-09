import { CheckCircle, ClockCountdown, CurrencyDollar, Package, ShieldCheck, Storefront, Warning } from "@phosphor-icons/react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate, useParams } from "react-router-dom";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../components/DeepViewShell";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { HubContextModel, HubViewModel, PurchaseReview } from "../types";

const statusLabel: Record<PurchaseReview["status"], string> = {
  draft: "Draft", approval_required: "Approval Required", approved: "Approved",
  ordered: "Ordered", in_transit: "In Transit", delivered: "Delivered",
  failed: "Failed", rejected: "Rejected",
};

export function PurchaseReviewView() {
  const hub = useHub();
  const { purchaseId = "" } = useParams();
  const navigate = useNavigate();
  const location = useLocation();
  const returnTo = (location.state as { returnTo?: string } | null)?.returnTo ?? "/supplies";
  const context = useMemo<HubContextModel>(() => ({ actorId: hub.actorId, role: hub.role, surface: hub.surface, presence: hub.presence, capabilitiesRevision: hub.capabilitiesRevision, viewState: hub.viewState, capabilities: hub.capabilities }), [hub]);
  const [model, setModel] = useState<HubViewModel<PurchaseReview> | null>(null);
  const [confirm, setConfirm] = useState(false);
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState<string>();
  const [handoff, setHandoff] = useState(false);

  const reload = useCallback(() => hub.adapter.load<PurchaseReview>({ kind: "purchaseReview", purchaseId }, context).then(setModel), [context, hub.adapter, purchaseId]);
  useEffect(() => { void reload(); }, [reload]);

  if (!model) return <StatePanel state="loading" />;
  if (model.state !== "ready" || !model.data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  const purchase = model.data;
  const delivered = purchase.status === "delivered";
  const moving = purchase.status === "in_transit" || purchase.status === "ordered";
  const tone = delivered ? "success" : purchase.status === "failed" || purchase.status === "rejected" ? "danger" : "warning";

  const act = async (intent: Parameters<typeof hub.adapter.dispatch>[0]) => {
    setPending(true);
    const result = await hub.adapter.dispatch(intent, context);
    setPending(false);
    setConfirm(false);
    setNotice(result.message);
    await reload();
  };

  const action = purchase.canApprove ? (
    <button type="button" className="domain-primary-action" disabled={pending} onClick={() => void act({ type: "procurement.resolve", requestId: purchase.draftId ?? purchaseId, decision: "approve" })}>
      <ShieldCheck size={19} />Approve Request
    </button>
  ) : purchase.canConfirm ? (
    <button type="button" className="domain-primary-action" disabled={pending} onClick={() => hub.surface === "office" && hub.presence === "office" ? setConfirm(true) : setHandoff(true)}>
      <ShieldCheck size={19} />{hub.surface === "office" && hub.presence === "office" ? "Confirm Order" : "Complete at Office Terminal"}
    </button>
  ) : null;

  return <DeepViewShell eyebrow="Authoritative procurement" title={delivered ? "Warehouse Receipt" : "Purchase Review"} subtitle={`${purchase.reference} · Company Treasury`} breadcrumb={["Supplies", "Purchase Review", purchase.reference]} backLabel="Back to Supplies" onBack={() => navigate(returnTo)} status={<StatusPill tone={tone}>{statusLabel[purchase.status]}</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{delivered ? "Delivered to Company Warehouse" : moving ? "Supplier delivery underway" : statusLabel[purchase.status]}</span><p>{delivered ? "Available for controlled withdrawal" : "No item is delivered directly to a player"}</p></div>{action}</>}>
    {notice ? <div className="domain-notice">{notice}</div> : null}
    <div className="domain-two-column"><div className="domain-card-stack">
      <DetailCard eyebrow="Order lines" title={`${purchase.lines.length} supplier item${purchase.lines.length === 1 ? "" : "s"}`}><div className="purchase-lines">{purchase.lines.map((line) => <div key={line.productId}><Package size={22} /><span><strong>{line.name}</strong><small>{line.quantity} × ${line.unitPrice} per {line.unit}</small></span><b>${(line.quantity * line.unitPrice).toLocaleString()}</b></div>)}</div></DetailCard>
      <DetailCard eyebrow="Fulfillment" title="Delayed Warehouse delivery"><p className="domain-emphasis">{moving ? <ClockCountdown size={25} /> : delivered ? <CheckCircle size={25} /> : <Storefront size={25} />}{moving ? "In transit" : delivered ? "Warehouse received" : purchase.fulfillment}</p><FactList facts={[{ label: "Ownership", value: "Company" }, { label: "Destination", value: "Company Warehouse" }, { label: "Receipt", value: purchase.receiptId ?? "Issued at confirmation" }]} /></DetailCard>
      {delivered ? <DetailCard eyebrow="Audit receipt" title={purchase.receiptId ?? "Receipt issued"}><ul className="domain-check-list"><li><CheckCircle size={18} />Treasury debit ledgered</li><li><CheckCircle size={18} />Supplier stock reserved</li><li><CheckCircle size={18} />Warehouse lot received exactly once</li></ul></DetailCard> : null}
      {purchase.status === "failed" || purchase.status === "rejected" ? <div className="purchase-failure"><Warning size={24} /><div><strong>{statusLabel[purchase.status]}</strong><p>Create a fresh draft or ask an authorized manager to review the request.</p></div></div> : null}
    </div><aside className="domain-card-stack">
      <DetailCard eyebrow="Settlement" title={`$${purchase.total.toLocaleString()}`}><FactList facts={[{ label: "Subtotal", value: `$${purchase.subtotal.toLocaleString()}` }, { label: "Supplier fee", value: `$${purchase.fees.toLocaleString()}` }, { label: "Payer", value: "Company Treasury" }, { label: "Treasury before", value: `$${purchase.balance.toLocaleString()}` }, { label: "Projected", value: `$${purchase.projectedBalance.toLocaleString()}` }]} /></DetailCard>
      <DetailCard eyebrow="Procurement authority" title="Company policy"><FactList facts={[{ label: "Budget remaining", value: `$${purchase.budgetRemaining?.toLocaleString()}` }, { label: "Transaction limit", value: purchase.transactionLimit ? `$${purchase.transactionLimit.toLocaleString()}` : "Unlimited" }, { label: "Final confirmation", value: "Office Terminal" }]} /></DetailCard>
    </aside></div>
    {confirm ? <ConfirmDialog eyebrow="Treasury transaction" title="Confirm order for Warehouse delivery?" confirmLabel="Confirm Order" pending={pending} onClose={() => setConfirm(false)} onConfirm={() => void act({ type: "purchase.confirm", purchaseId: purchase.draftId ?? purchaseId })}><p>This debits Company Treasury, reserves supplier stock and creates a delayed Warehouse delivery.</p><p className="dialog-callout"><CurrencyDollar size={18} />Final charge: ${purchase.total.toLocaleString()}</p></ConfirmDialog> : null}
    {handoff ? <div className="domain-handoff"><Storefront size={52} /><span>Office presence required</span><h2>Complete at Office Terminal</h2><p>No funds or stock changed. The draft remains available until its expiry time.</p><button type="button" className="secondary-button" onClick={() => setHandoff(false)}>Return to Review</button></div> : null}
  </DeepViewShell>;
}
