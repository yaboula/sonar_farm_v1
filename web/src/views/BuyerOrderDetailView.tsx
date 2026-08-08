import { ArrowSquareOut, CalendarBlank, CheckCircle, ClipboardText, CurrencyDollar, MapPin, Package, ShieldCheck, Truck, Warning } from "@phosphor-icons/react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate, useParams } from "react-router-dom";
import { fixtureHubAdapter } from "../adapters/FixtureHubAdapter";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../components/DeepViewShell";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { BuyerOrderAction, BuyerOrderDetail, HubContextModel, HubViewModel } from "../types";

const ACTION_COPY: Record<BuyerOrderAction, { label: string; title: string }> = {
  accept: { label: "Accept Order", title: "Accept this Buyer Order?" },
  plan: { label: "Plan Fulfillment", title: "Start fulfillment planning?" },
  create_assignment: { label: "Create Assignment", title: "Create linked Assignment?" },
  reserve: { label: "Reserve Stock", title: "Reserve available stock?" },
  prepare: { label: "Prepare Delivery", title: "Mark cargo ready for delivery?" },
  complete: { label: "Complete Delivery", title: "Confirm destination acceptance?" },
  reject: { label: "Reject Order", title: "Reject this Buyer Order?" },
};

export function BuyerOrderDetailView() {
  const { orderId = "" } = useParams();
  const hub = useHub(); const navigate = useNavigate(); const location = useLocation();
  const returnTo = (location.state as { returnTo?: string } | null)?.returnTo ?? "/work?area=buyerOrders";
  const context = useMemo<HubContextModel>(() => ({ actorId: hub.actorId, role: hub.role, surface: hub.surface, presence: hub.presence, capabilitiesRevision: hub.capabilitiesRevision, viewState: hub.viewState, capabilities: hub.capabilities }), [hub.actorId, hub.role, hub.surface, hub.presence, hub.capabilitiesRevision, hub.viewState, hub.capabilities]);
  const [model, setModel] = useState<HubViewModel<BuyerOrderDetail> | null>(null);
  const [dialog, setDialog] = useState<BuyerOrderAction>(); const [notice, setNotice] = useState<string>(); const [pending, setPending] = useState(false);
  const reload = useCallback(() => fixtureHubAdapter.load<BuyerOrderDetail>({ kind: "buyerOrderDetail", orderId }, context).then(setModel), [context, orderId]);
  useEffect(() => { void reload(); }, [reload]);
  if (!model) return <StatePanel state="loading" />;
  if (model.state !== "ready") return <StatePanel state={model.state} onAction={() => navigate(returnTo)} />;
  const order = model.data;
  if (!order) return <StatePanel state="empty" onAction={() => navigate(returnTo)} />;

  const act = async (action: BuyerOrderAction) => {
    if (action === "create_assignment") { navigate("/work/assignments/new", { state: { returnTo: `/work/orders/${order.id}` } }); return; }
    setPending(true); const result = await fixtureHubAdapter.dispatch({ type: "buyerOrder.transition", orderId: order.id, action }, context); setPending(false); setDialog(undefined); setNotice(result.message); if (result.changed) await reload();
  };
  const tone = order.status === "completed" ? "success" : order.status === "rejected" ? "danger" : order.status === "open" ? "warning" : "active";

  return <DeepViewShell eyebrow="Buyer commitment" title={`${order.reference} · ${order.buyer}`} subtitle={`${order.quantity} ${order.product} · ${order.quality}`} breadcrumb={["Work", "Buyer Orders", order.reference]} backLabel="Back to Buyer Orders" onBack={() => navigate(returnTo)} status={<StatusPill tone={tone}>{order.statusLabel}</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{order.status === "completed" || order.status === "rejected" ? "Order closed" : `${order.availableActions.length} authorized next actions`}</span><p>{order.fulfillment}</p></div><div className="domain-action-group">{order.availableActions.map((action) => <button key={action} type="button" className={action === "reject" ? "domain-secondary-action danger" : action === "complete" || action === "accept" ? "domain-primary-action" : "domain-secondary-action"} onClick={() => action === "create_assignment" ? void act(action) : setDialog(action)}>{ACTION_COPY[action].label}</button>)}</div></>}>
    {notice ? <div className="domain-notice">{notice}</div> : null}
    <div className="domain-two-column"><div className="domain-card-stack">
      <DetailCard eyebrow="Fulfillment" title="Order requirement"><div className="domain-order-hero"><Package size={42} weight="thin" /><div><strong>{order.quantity} {order.unit}</strong><span>{order.product}</span></div><div><strong>{order.reservedQuantity} reserved</strong><span>{Math.round(order.reservedQuantity / order.quantity * 100)}% secured</span></div></div><div className="domain-progress"><i style={{ width: `${Math.round(order.reservedQuantity / order.quantity * 100)}%` }} /></div><FactList facts={[{ label: "Quality", value: order.quality }, { label: "Deadline", value: <><CalendarBlank size={15} />{order.deadline}</> }, { label: "Destination", value: <><MapPin size={15} />{order.destination}</> }]} /></DetailCard>
      <DetailCard eyebrow="Execution" title="Linked Assignments">{order.linkedAssignments.length ? <div className="linked-list">{order.linkedAssignments.map((assignment) => <button type="button" key={assignment.id} onClick={() => navigate(`/work/assignments/${assignment.id}`, { state: { returnTo: `/work/orders/${order.id}` } })}><ClipboardText size={20} /><span><strong>{assignment.title}</strong><small>{assignment.id.toUpperCase()} · {assignment.status}</small></span><ArrowSquareOut size={17} /></button>)}</div> : <div className="inline-empty compact">No Assignments linked yet.</div>}</DetailCard>
      <DetailCard eyebrow="Acceptance" title="Buyer terms"><ul className="domain-check-list">{order.terms.map((term) => <li key={term}><CheckCircle size={18} />{term}</li>)}</ul></DetailCard>
    </div><aside className="domain-card-stack">
      <DetailCard eyebrow="Delivery" title="Custody"><p className="domain-emphasis"><Truck size={25} />{order.fulfillment}</p><FactList facts={[{ label: "Cargo", value: order.cargoOwnership }, { label: "Destination", value: order.destination }, { label: "Warehouse", value: "Reference only · no false handoff" }]} /></DetailCard>
      <DetailCard eyebrow="Reserved value" title={`$${order.payout.toLocaleString()}`}><p className="domain-emphasis"><CurrencyDollar size={25} />Payment releases after buyer acceptance.</p><FactList facts={[{ label: "Payer", value: order.buyer }, { label: "Settlement", value: "Destination acceptance" }]} /></DetailCard>
      {order.status === "rejected" ? <DetailCard eyebrow="Closed" title="Order rejected"><p className="domain-emphasis warning"><Warning size={24} />No stock or payout remains reserved.</p></DetailCard> : null}
    </aside></div>
    {dialog ? <ConfirmDialog eyebrow="Buyer Order control" title={ACTION_COPY[dialog].title} confirmLabel={ACTION_COPY[dialog].label} tone={dialog === "reject" ? "danger-confirm" : "confirm"} pending={pending} onClose={() => setDialog(undefined)} onConfirm={() => void act(dialog)}><p>The adapter will revalidate current status, permissions and availability before applying this transition.</p>{dialog === "complete" ? <p className="dialog-callout"><ShieldCheck size={18} />This releases the fixture payout and closes fulfillment.</p> : null}</ConfirmDialog> : null}
  </DeepViewShell>;
}
