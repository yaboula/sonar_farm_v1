import { CurrencyDollar, ShieldCheck } from "@phosphor-icons/react";
import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../components/DeepViewShell";
import { FarmSelect } from "../components/FarmSelect";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { FarmingWorkAction, HubContextModel, HubViewModel, WorkCreateData, WorkRequirementInput } from "../types";

type FieldDraftState = { returnTo?: string; fieldDraft?: { sourcePlanId?: string } };
const actionOptions = [
  { value: "plant", label: "Plant", description: "Establish eligible planned Slots" },
  { value: "water", label: "Water", description: "Restore authoritative crop water" },
  { value: "fertilize", label: "Fertilize", description: "Apply verified nutrient care" },
  { value: "weed", label: "Remove Weeds", description: "Reduce weed pressure" },
  { value: "treat_pest", label: "Treat Pests", description: "Reduce pest pressure" },
  { value: "harvest", label: "Harvest", description: "Create Company Cargo" },
] as const;

function cropLabel(crop: string) {
  if (crop === "tomato") return "Tomatoes";
  if (crop === "potato") return "Potatoes";
  if (crop === "carrot") return "Carrots";
  if (crop === "lettuce") return "Lettuce";
  return crop.charAt(0).toUpperCase() + crop.slice(1);
}

function rowLabel(rowId: string) {
  const match = rowId.match(/(?:row:|[-_]r)(\d+)$/i);
  return match ? `Row ${Number(match[1])}` : rowId;
}

function InputField({ label, value, onChange, type = "text", min }: { label: string; value: string | number; onChange: (value: string) => void; type?: string; min?: number }) {
  return <label className="domain-input"><span>{label}</span><input type={type} min={min} value={value} onChange={(event) => onChange(event.target.value)} /></label>;
}

export function WorkCreateView({ kind }: { kind: "assignment" | "contract" }) {
  const hub = useHub();
  const navigate = useNavigate();
  const location = useLocation();
  const routeState = location.state as FieldDraftState | null;
  const returnTo = routeState?.returnTo ?? `/work?area=${kind === "assignment" ? "assignments" : "publicContracts"}`;
  const context = useMemo<HubContextModel>(() => ({ actorId: hub.actorId, role: hub.role, surface: hub.surface, presence: hub.presence, capabilitiesRevision: hub.capabilitiesRevision, viewState: hub.viewState, capabilities: hub.capabilities }), [hub.actorId, hub.role, hub.surface, hub.presence, hub.capabilitiesRevision, hub.viewState, hub.capabilities]);
  const [access, setAccess] = useState<HubViewModel<WorkCreateData> | null>(null);
  const [planId, setPlanId] = useState(routeState?.fieldDraft?.sourcePlanId ?? "");
  const [assigneeId, setAssigneeId] = useState("");
  const [title, setTitle] = useState(kind === "assignment" ? "Verified Field Work" : "Funded Field Contract");
  const [objective, setObjective] = useState("Complete the selected agronomic action across the reserved Crop Plan Rows.");
  const [action, setAction] = useState<FarmingWorkAction>("plant");
  const [target, setTarget] = useState(1);
  const [deadlineHours, setDeadlineHours] = useState(24);
  const [payout, setPayout] = useState(kind === "assignment" ? 220 : 860);
  const [confirm, setConfirm] = useState(false);
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState<string>();

  useEffect(() => {
    void hub.adapter.load<WorkCreateData>(kind === "assignment" ? { kind: "assignmentCreate" } : { kind: "contractCreate" }, context).then((next) => {
      setAccess(next);
      if (next.state === "ready" && next.data) {
        setPlanId((current) => current || next.data?.plans?.[0]?.id || "");
        setAssigneeId((current) => current || next.data?.members?.[0]?.id || "");
        const requestedPlan = next.data.plans?.find((plan) => plan.id === routeState?.fieldDraft?.sourcePlanId);
        if (requestedPlan) {
          setTitle(`Establish ${cropLabel(requestedPlan.crop)} · ${requestedPlan.rowIds.map(rowLabel).join(", ")}`);
        }
      }
    });
  }, [context, hub.adapter, kind, routeState?.fieldDraft?.sourcePlanId]);
  if (!access) return <StatePanel state="loading" />;
  if (access.state !== "ready" || !access.data) return <StatePanel state={access.state === "ready" ? "empty" : access.state} onAction={() => navigate(returnTo)} />;
  const plans = access.data.plans ?? [];
  const members = access.data.members ?? [];
  const effectivePlanId = planId || plans[0]?.id || "";
  const effectiveAssigneeId = assigneeId || members[0]?.id || "";
  const selectedPlan = plans.find((plan) => plan.id === effectivePlanId);
  const requirement: WorkRequirementInput | undefined = selectedPlan ? { action, rowIds: selectedPlan.rowIds, crop: selectedPlan.crop, target } : undefined;
  const valid = Boolean(selectedPlan && title.trim().length >= 3 && objective.trim().length >= 3 && payout > 0 && target > 0 && deadlineHours > 0 && (kind === "contract" || effectiveAssigneeId));
  const submit = async () => {
    if (!selectedPlan || !requirement) return;
    setPending(true);
    const deadlineAt = access.data!.serverNow + deadlineHours * 3600;
    const common = { title, objective, sourcePlanId: selectedPlan.id, deadline: new Date(deadlineAt * 1000).toISOString(), deadlineAt, scopeRef: { fieldId: selectedPlan.fieldId, rowIds: selectedPlan.rowIds } };
    const intent = kind === "assignment"
      ? { type: "assignment.create" as const, input: { ...common, fieldId: selectedPlan.fieldId, crop: selectedPlan.crop, scope: selectedPlan.rowIds.join(", "), assigneeId: effectiveAssigneeId, supervisorId: hub.actorId, payout, requirement: `${action} ×${target}`, requirements: [requirement], materialIds: [] } }
      : { type: "contract.create" as const, input: { ...common, template: action, field: selectedPlan.fieldId, scope: selectedPlan.rowIds.join(", "), reward: payout, requirements: `${action} ×${target}`, structuredRequirements: [requirement], failureRule: "Deadline expiry or unverified result." } };
    const result = await hub.adapter.dispatch(intent, context);
    setPending(false); setConfirm(false); setNotice(result.message);
    if (result.ok && result.entityId) navigate(kind === "assignment" ? `/work/assignments/${result.entityId}` : `/work/contracts/${result.entityId}`, { replace: true, state: { returnTo } });
  };
  const planOptions = plans.map((plan) => ({ value: plan.id, label: `${plan.reference} · ${cropLabel(plan.crop)}`, description: plan.rowIds.map(rowLabel).join(", ") }));
  const workerOptions = members.map((member) => ({ value: member.id, label: member.name, description: member.role }));
  return <DeepViewShell eyebrow={kind === "assignment" ? "Internal work order" : "Funded public opportunity"} title={kind === "assignment" ? "Create Assignment" : "Create Public Contract"} subtitle="Only structured, server-verifiable requirements can advance this Work." breadcrumb={["Work", kind === "assignment" ? "Assignments" : "Public Contracts", access.data.nextReference]} backLabel="Back to Work" onBack={() => navigate(returnTo)} status={<StatusPill tone="warning">Draft</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{valid ? "Ready for review" : "Select a free Crop Plan"}</span><p>${payout} reserved from Treasury</p></div><button className="domain-primary-action" type="button" disabled={!valid} onClick={() => setConfirm(true)}><ShieldCheck size={19} />Review & Confirm</button></>}>
    {notice ? <div className="domain-notice">{notice}</div> : null}
    <div className="domain-two-column"><div className="domain-card-stack"><DetailCard eyebrow="01 · Authority" title="Crop Plan and responsibility"><div className="domain-form-grid"><FarmSelect label="Reserved Crop Plan" value={effectivePlanId} options={planOptions} onChange={setPlanId} />{kind === "assignment" ? <FarmSelect label="Active Company Member" value={effectiveAssigneeId} options={workerOptions} onChange={setAssigneeId} /> : null}<InputField label="Title" value={title} onChange={setTitle} /><label className="domain-input domain-input--wide"><span>Objective</span><textarea value={objective} onChange={(event) => setObjective(event.target.value)} /></label></div></DetailCard><DetailCard eyebrow="02 · Verification" title="Structured requirement"><div className="domain-form-grid"><FarmSelect label="Agronomic Action" value={action} options={actionOptions} onChange={(value) => setAction(value as FarmingWorkAction)} /><InputField label="Verified actions required" type="number" min={1} value={target} onChange={(value) => setTarget(Number(value))} /></div><FactList facts={[{ label: "Field", value: selectedPlan?.fieldId ?? "No Plan" }, { label: "Rows", value: selectedPlan?.rowIds.map(rowLabel).join(", ") ?? "None" }, { label: "Crop", value: selectedPlan ? cropLabel(selectedPlan.crop) : "None" }, { label: "Progress authority", value: "Server farming events only" }]} /></DetailCard></div><aside className="domain-card-stack"><DetailCard eyebrow="Deadline" title="Real server time"><InputField label="Hours from now" type="number" min={1} value={deadlineHours} onChange={(value) => setDeadlineHours(Number(value))} /></DetailCard><DetailCard eyebrow="Economic terms" title={kind === "assignment" ? "Reserved pay" : "Escrow reward"}><p className="domain-emphasis"><CurrencyDollar size={25} />Funds leave available Treasury now and release only after review.</p><InputField label="Amount (USD)" type="number" min={1} value={payout} onChange={(value) => setPayout(Number(value))} /></DetailCard></aside></div>
    {confirm ? <ConfirmDialog eyebrow="Authoritative Work" title={kind === "assignment" ? "Issue this Assignment?" : "Fund this Contract draft?"} confirmLabel={kind === "assignment" ? "Create Assignment" : "Create Funded Draft"} pending={pending} onClose={() => setConfirm(false)} onConfirm={() => void submit()}><FactList facts={[{ label: "Plan", value: selectedPlan?.reference ?? "Missing" }, { label: "Action", value: action.replace("_", " ") }, { label: "Target", value: target }, { label: "Reserved funds", value: `$${payout}` }]} /></ConfirmDialog> : null}
  </DeepViewShell>;
}
