import { CheckCircle, CurrencyDollar, Package, ShieldCheck, Storefront, Warning } from "@phosphor-icons/react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate, useParams } from "react-router-dom";
import { fixtureHubAdapter } from "../adapters/FixtureHubAdapter";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../components/DeepViewShell";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { HubContextModel, HubViewModel, PurchaseReview } from "../types";

const failureCopy: Record<NonNullable<PurchaseReview["failureReason"]>, string> = {
  insufficient_funds: "The selected payer no longer has enough available funds.",
  budget_exceeded: "This purchase exceeds the remaining budget or transaction authority.",
  permission_lost: "Company purchasing permission was removed while review was open.",
  stock_changed: "Supplier stock changed after the draft was created.",
  sold_out: "A required line is now sold out.",
  inventory_full: "The destination inventory cannot receive this purchase.",
  unavailable: "The supplier service is currently unavailable.",
};

export function PurchaseReviewView() {
  const { purchaseId = "" } = useParams(); const hub = useHub(); const navigate = useNavigate(); const location = useLocation();
  const returnTo = (location.state as { returnTo?: string } | null)?.returnTo ?? "/supplies?area=market";
  const context = useMemo<HubContextModel>(() => ({ role: hub.role, surface: hub.surface, viewState: hub.viewState, capabilities: hub.capabilities }), [hub.role, hub.surface, hub.viewState, hub.capabilities]);
  const [model, setModel] = useState<HubViewModel<PurchaseReview> | null>(null); const [confirm, setConfirm] = useState(false); const [pending, setPending] = useState(false); const [notice, setNotice] = useState<string>(); const [handoff, setHandoff] = useState(false);
  const reload = useCallback(() => fixtureHubAdapter.load<PurchaseReview>({ kind: "purchaseReview", purchaseId }, context).then(setModel), [context, purchaseId]);
  useEffect(() => { void reload(); }, [reload]);
  if (!model) return <StatePanel state="loading" />;
  if (model.state !== "ready") return <StatePanel state={model.state} onAction={() => navigate(returnTo)} />;
  const purchase = model.data; if (!purchase) return <StatePanel state="empty" onAction={() => navigate(returnTo)} />;
  const confirmPurchase = async () => { setPending(true); const result = await fixtureHubAdapter.dispatch({ type: "purchase.confirm", purchaseId }, context); setPending(false); setConfirm(false); setNotice(result.message); if (result.closeSurface) setHandoff(true); await reload(); };
  const completed = purchase.status === "completed";

  return <DeepViewShell eyebrow="Physical purchase control" title={completed ? "Purchase Receipt" : "Purchase Review"} subtitle={`${purchase.reference} · ${purchase.ownership} ownership`} breadcrumb={["Supplies", "Purchase Review", purchase.reference]} backLabel="Back to Supply Market" onBack={() => navigate(returnTo)} status={<StatusPill tone={completed ? "success" : purchase.failureReason ? "danger" : "warning"}>{completed ? "Completed" : purchase.failureReason ? "Review Required" : "Draft"}</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{completed ? `Receipt ${purchase.receiptId}` : hub.surface === "office" ? "Physical confirmation available" : "Office presence required"}</span><p>{completed ? `${purchase.ownership} inventory updated` : "Stock and funds revalidate at confirmation"}</p></div>{completed ? <button type="button" className="domain-secondary-action" onClick={() => navigate(returnTo)}>Return to Supplies</button> : <button type="button" className="domain-primary-action" onClick={() => hub.surface === "office" ? setConfirm(true) : setHandoff(true)}><ShieldCheck size={19} />{hub.surface === "office" ? "Confirm Purchase" : "Complete at Office Terminal"}</button>}</>}>
    {notice ? <div className="domain-notice">{notice}</div> : null}
    {purchase.failureReason ? <div className="purchase-failure"><Warning size={24} /><div><strong>{purchase.failureReason.replaceAll("_", " ")}</strong><p>{failureCopy[purchase.failureReason]}</p></div></div> : null}
    <div className="domain-two-column"><div className="domain-card-stack">
      <DetailCard eyebrow="Order lines" title={`${purchase.lines.length} supplier item${purchase.lines.length === 1 ? "" : "s"}`}><div className="purchase-lines">{purchase.lines.map((line) => <div key={line.productId}><Package size={22} /><span><strong>{line.name}</strong><small>{line.quantity} × {`$${line.unitPrice}`} per {line.unit}</small></span><b>{`$${(line.quantity * line.unitPrice).toLocaleString()}`}</b></div>)}</div></DetailCard>
      <DetailCard eyebrow="Collection" title="Physical fulfillment"><p className="domain-emphasis"><Storefront size={25} />{purchase.fulfillment}</p><FactList facts={[{ label: "Capacity", value: purchase.inventoryCapacity }, { label: "Ownership", value: purchase.ownership }, { label: "Surface", value: hub.surface === "office" ? "Office Terminal · authorized" : "Farm Tablet · review only" }]} /></DetailCard>
      {completed ? <DetailCard eyebrow="Audit receipt" title={purchase.receiptId ?? "Receipt issued"}><ul className="domain-check-list"><li><CheckCircle size={18} />Supplier stock updated</li><li><CheckCircle size={18} />{purchase.ownership} balance debited</li><li><CheckCircle size={18} />{purchase.ownership} ownership recorded</li>{purchase.payer === "company" ? <li><CheckCircle size={18} />Procurement ledger entry created</li> : null}</ul></DetailCard> : null}
    </div><aside className="domain-card-stack">
      <DetailCard eyebrow="Settlement" title={`$${purchase.total.toLocaleString()}`}><FactList facts={[{ label: "Subtotal", value: `$${purchase.subtotal.toLocaleString()}` }, { label: "Supplier fees", value: `$${purchase.fees.toLocaleString()}` }, { label: "Payer", value: purchase.payer === "company" ? "Sonar Farm Treasury" : "Personal Funds" }, { label: "Balance before", value: `$${purchase.balance.toLocaleString()}` }, { label: "Projected balance", value: `$${purchase.projectedBalance.toLocaleString()}` }]} /></DetailCard>
      {purchase.payer === "company" ? <DetailCard eyebrow="Procurement authority" title="Company policy"><FactList facts={[{ label: "Budget remaining", value: `$${purchase.budgetRemaining?.toLocaleString()}` }, { label: "Transaction limit", value: `$${purchase.transactionLimit?.toLocaleString()}` }, { label: "Audit", value: "Required" }]} /></DetailCard> : <DetailCard eyebrow="Personal purchase" title="Private ownership"><p className="domain-muted">This purchase never changes Company Treasury, stock or audit records.</p></DetailCard>}
      <DetailCard eyebrow="Final validation" title="At confirmation"><ul className="domain-check-list"><li><CheckCircle size={18} />Permission and payer</li><li><CheckCircle size={18} />Funds and budget</li><li><CheckCircle size={18} />Supplier stock</li><li><CheckCircle size={18} />Inventory capacity</li></ul></DetailCard>
    </aside></div>
    {confirm ? <ConfirmDialog eyebrow="Physical transaction" title="Confirm purchase and collection?" confirmLabel="Confirm Purchase" pending={pending} onClose={() => setConfirm(false)} onConfirm={() => void confirmPurchase()}><p>This will debit {purchase.payer === "company" ? "Sonar Farm Treasury" : "your personal funds"}, update supplier stock and record {purchase.ownership.toLowerCase()} ownership.</p><p className="dialog-callout"><CurrencyDollar size={18} />Final charge: ${purchase.total.toLocaleString()}</p></ConfirmDialog> : null}
    {handoff ? <div className="domain-handoff"><Storefront size={52} /><span>Office presence required</span><h2>Complete at Office Terminal</h2><p>Your fixture draft remains available in this session. No funds or stock changed.</p><button type="button" className="secondary-button" onClick={() => setHandoff(false)}>Return to Review</button></div> : null}
  </DeepViewShell>;
}
