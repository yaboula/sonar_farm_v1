import { CheckCircle, Circle, Clock, CurrencyDollar, MapPin, Package, Path, ShoppingCartSimple, Warning } from "@phosphor-icons/react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate, useParams } from "react-router-dom";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../components/DeepViewShell";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { ContractAction, ContractDetail, HubContextModel, HubViewModel } from "../types";

const ACTION_LABEL: Record<ContractAction, string> = {
  accept: "Accept Contract", publish: "Publish Contract", set_route_field: "Set Route to Field", open_supplies: "Open Supply Market", set_route_delivery: "Set Route to Delivery", submit: "Submit Contract", complete: "Approve Completion", abandon: "Abandon Contract", cancel: "Cancel Contract",
};

export function ContractDetailView({ mode }: { mode: "public" | "active" | "progress" | "completion" }) {
  const { contractId = "" } = useParams(); const hub = useHub(); const navigate = useNavigate(); const location = useLocation();
  const returnTo = (location.state as { returnTo?: string } | null)?.returnTo ?? `/work?area=${mode === "public" ? "publicContracts" : "activeContract"}`;
  const context = useMemo<HubContextModel>(() => ({ actorId: hub.actorId, role: hub.role, surface: hub.surface, presence: hub.presence, capabilitiesRevision: hub.capabilitiesRevision, viewState: hub.viewState, capabilities: hub.capabilities }), [hub.actorId, hub.role, hub.surface, hub.presence, hub.capabilitiesRevision, hub.viewState, hub.capabilities]);
  const [model, setModel] = useState<HubViewModel<ContractDetail> | null>(null); const [dialog, setDialog] = useState<ContractAction>(); const [notice, setNotice] = useState<string>(); const [pending, setPending] = useState(false); const [handoff, setHandoff] = useState<string>();
  const reload = useCallback(() => hub.adapter.load<ContractDetail>({ kind: "contractDetail", contractId, mode }, context).then(setModel), [contractId, context, hub.adapter, mode]);
  useEffect(() => { void reload(); }, [reload]);
  if (!model) return <StatePanel state="loading" />;
  if (model.state !== "ready") return <StatePanel state={model.state} onAction={() => navigate(returnTo)} />;
  const contract = model.data; if (!contract) return <StatePanel state="empty" onAction={() => navigate(returnTo)} />;

  const run = async (action: ContractAction) => {
    setPending(true);
    const result = action === "accept" ? await hub.adapter.dispatch({ type: "contract.accept", contractId }, context) : await hub.adapter.dispatch({ type: "contract.transition", contractId, action }, context);
    setPending(false); setDialog(undefined); setNotice(result.message);
    if (!result.ok) { await reload(); return; }
    if (result.contextUpdate?.role) hub.setRole(result.contextUpdate.role);
    if (action === "accept") { navigate(`/work/contracts/active/${contractId}`, { replace: true, state: { returnTo: "/work?area=activeContract" } }); return; }
    if (action === "open_supplies") { navigate("/supplies", { state: { contractId, returnTo: location.pathname } }); return; }
    if (result.closeSurface) setHandoff(result.message);
    if (result.changed) await reload();
  };
  const completed = contract.steps.filter((step) => step.completed).length;
  const percent = Math.round(completed / contract.steps.length * 100);
  const tone = contract.status === "completed" ? "success" : ["failed", "expired", "cancelled"].includes(contract.status) ? "danger" : contract.status === "published" || contract.status === "draft" ? "warning" : "active";
  const title = mode === "completion" ? "Contract Completion" : mode === "progress" ? "Contract Progress" : contract.title;
  const backPath = mode === "progress" || mode === "completion" ? `/work/contracts/active/${contract.id}` : returnTo;

  const actionBar = <><div className="domain-action-summary"><span>{contract.statusLabel}</span><p>{contract.escrowStatus === "reserved" ? `$${contract.reward.toLocaleString()} protected in escrow` : `Escrow ${contract.escrowStatus}`}</p></div><div className="domain-action-group">
    {mode === "active" && contract.status === "active" ? <button className="domain-primary-action" type="button" onClick={() => navigate(`/work/contracts/active/${contract.id}/progress`, { state: { returnTo } })}>Open Contract Progress</button> : null}
    {mode === "active" && contract.status === "completed" ? <button className="domain-primary-action" type="button" onClick={() => navigate(`/work/contracts/active/${contract.id}/completion`, { state: { returnTo } })}>View Completion</button> : null}
    {contract.availableActions.map((action) => <button key={action} className={action === "accept" || action === "submit" || action === "complete" || action === "publish" ? "domain-primary-action" : action === "abandon" || action === "cancel" ? "domain-secondary-action danger" : "domain-secondary-action"} type="button" onClick={() => ["set_route_field", "set_route_delivery", "open_supplies"].includes(action) ? void run(action) : setDialog(action)}>{ACTION_LABEL[action]}</button>)}
  </div></>;

  return <DeepViewShell eyebrow={mode === "public" ? "Public contract" : "Contractor workspace"} title={title} subtitle={`${contract.reference} · ${contract.field} · ${contract.scope}`} breadcrumb={["Work", mode === "public" ? "Public Contracts" : "Active Contract", contract.reference, ...(mode === "progress" ? ["Progress"] : mode === "completion" ? ["Completion"] : [])]} backLabel={mode === "progress" || mode === "completion" ? "Back to Active Contract" : "Back to Work"} onBack={() => navigate(backPath)} status={<StatusPill tone={tone}>{contract.statusLabel}</StatusPill>} actionBar={actionBar}>
    {notice ? <div className="domain-notice">{notice}</div> : null}
    <div className="domain-two-column"><div className="domain-card-stack">
      <DetailCard eyebrow="Objective" title={contract.title}><p className="domain-lead">{contract.objective}</p><FactList facts={[{ label: "Field access", value: <><MapPin size={16} />{contract.fieldAccess}</> }, { label: "Deadline", value: <><Clock size={16} />{contract.deadline}</> }, { label: "Contractor", value: contract.contractor ?? "Reserved for the first eligible person" }]} /></DetailCard>
      <DetailCard eyebrow="Verified execution" title={mode === "completion" ? "Accepted result" : "Contract steps"}><div className="contract-step-list">{contract.steps.map((step, index) => <div className={step.completed ? "is-complete" : ""} key={step.id}><span>{step.completed ? <CheckCircle size={22} weight="fill" /> : <Circle size={22} />}</span><div><strong>{index + 1}. {step.label}</strong><small>{step.completed ? step.detail : `${step.detail} · Waiting for an authoritative farming operation`}</small></div></div>)}</div><div className="domain-progress"><i style={{ width: `${percent}%` }} /></div><small className="domain-progress-label">{completed} of {contract.steps.length} verified · {percent}%</small></DetailCard>
      {mode === "completion" || contract.status === "completed" ? <DetailCard eyebrow="Receipt" title="Contract resolution"><FactList facts={[{ label: "Accepted", value: contract.acceptedResult ?? contract.producedCargo }, { label: "Adjustment", value: `$${(contract.adjustment ?? 0).toLocaleString()}` }, { label: "Final payout", value: `$${(contract.reward + (contract.adjustment ?? 0)).toLocaleString()}` }, { label: "Escrow", value: contract.escrowStatus }, { label: "Cargo", value: contract.cargoOwnership }]} /></DetailCard> : null}
    </div><aside className="domain-card-stack">
      <DetailCard eyebrow="Funded reward" title={`$${contract.reward.toLocaleString()}`}><p className="domain-emphasis"><CurrencyDollar size={25} />Reward is {contract.escrowStatus}.</p><FactList facts={[{ label: "Escrow", value: contract.escrowStatus }, { label: "Release", value: "After validated completion" }]} /></DetailCard>
      <DetailCard eyebrow="Contractor responsibility" title="Required materials"><p className="domain-muted">{contract.materialsPolicy}</p><ul className="domain-check-list">{contract.requirements.map((item) => <li key={item}><ShoppingCartSimple size={18} />{item}</li>)}</ul></DetailCard>
      <DetailCard eyebrow="Custody" title="Cargo & delivery"><FactList facts={[{ label: "Produced", value: <><Package size={16} />{contract.producedCargo}</> }, { label: "Ownership", value: contract.cargoOwnership }, { label: "Delivery", value: contract.deliveryDestination }]} /></DetailCard>
      <DetailCard eyebrow="Failure policy" title="Consequences"><ul className="domain-check-list warning">{contract.failureRules.map((rule) => <li key={rule}><Warning size={18} />{rule}</li>)}</ul></DetailCard>
    </aside></div>
    {dialog ? <ConfirmDialog eyebrow="Contract control" title={`${ACTION_LABEL[dialog]}?`} confirmLabel={ACTION_LABEL[dialog]} tone={dialog === "abandon" || dialog === "cancel" ? "danger-confirm" : "confirm"} pending={pending} onClose={() => setDialog(undefined)} onConfirm={() => void run(dialog)}><p>{dialog === "accept" ? "You will become the only reserved contractor. You supply every listed material and the reward remains protected in escrow." : dialog === "submit" ? "The completed verification set will become read-only while Sonar Farm reviews the result." : dialog === "complete" ? "The accepted result will release escrow and close this contract." : "The server will revalidate current state, permissions and consequences before committing this action."}</p></ConfirmDialog> : null}
    {handoff ? <div className="domain-handoff"><Path size={52} /><span>World handoff prepared</span><h2>{handoff}</h2><p>No contract progress was changed.</p><button type="button" className="secondary-button" onClick={() => setHandoff(undefined)}>Return to Hub Preview</button></div> : null}
  </DeepViewShell>;
}
