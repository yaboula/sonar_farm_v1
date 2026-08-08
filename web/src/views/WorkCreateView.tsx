import { CheckCircle, CurrencyDollar, ShieldCheck } from "@phosphor-icons/react";
import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { fixtureHubAdapter } from "../adapters/FixtureHubAdapter";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../components/DeepViewShell";
import { FarmSelect } from "../components/FarmSelect";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { AssignmentCreateInput, ContractCreateInput, HubContextModel, HubViewModel } from "../types";

type FieldDraftState = {
  returnTo?: string;
  fieldDraft?: {
    fieldId: string;
    fieldName: string;
    rowIds: string[];
    rowLabels: string[];
    crop: string;
    cropLabel: string;
    sourcePlanId?: string;
  };
};

const workerOptions = [
  { value: "staff-noah", label: "Noah Reed", description: "Worker · available now" },
  { value: "staff-sofia", label: "Sofia Bennett", description: "Worker · one active Assignment" },
] as const;

const fieldOptions = [
  { value: "north-field", label: "North Field", description: "Tomatoes · rows 1–12" },
  { value: "greenhouse-2", label: "Greenhouse 2", description: "Tomatoes · rows A–F" },
  { value: "east-field", label: "East Field", description: "Lettuce · contract Row D" },
  { value: "orchard-annex", label: "Orchard Annex", description: "Planting suspended" },
] as const;

const templateOptions = [
  { value: "Planting", label: "Planting Contract", description: "Prepare, plant and initial water" },
  { value: "Care", label: "Care Contract", description: "Inspect and correct plant condition" },
  { value: "Harvest", label: "Harvest Contract", description: "Harvest and deliver verified cargo" },
] as const;

function InputField({ label, value, onChange, type = "text", min }: { label: string; value: string | number; onChange: (value: string) => void; type?: string; min?: number }) {
  return <label className="domain-input"><span>{label}</span><input type={type} min={min} value={value} onChange={(event) => onChange(event.target.value)} /></label>;
}

export function WorkCreateView({ kind }: { kind: "assignment" | "contract" }) {
  const hub = useHub();
  const navigate = useNavigate();
  const location = useLocation();
  const routeState = location.state as FieldDraftState | null;
  const returnTo = routeState?.returnTo ?? `/work?area=${kind === "assignment" ? "assignments" : "publicContracts"}`;
  const fieldDraft = routeState?.fieldDraft;
  const context = useMemo<HubContextModel>(() => ({ actorId: hub.actorId, role: hub.role, surface: hub.surface, presence: hub.presence, capabilitiesRevision: hub.capabilitiesRevision, viewState: hub.viewState, capabilities: hub.capabilities }), [hub.actorId, hub.role, hub.surface, hub.presence, hub.capabilitiesRevision, hub.viewState, hub.capabilities]);
  const [access, setAccess] = useState<HubViewModel<{ nextReference: string }> | null>(null);
  const [confirm, setConfirm] = useState(false);
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState<string>();
  const [assignment, setAssignment] = useState<AssignmentCreateInput>(() => ({ title: fieldDraft ? `Establish ${fieldDraft.cropLabel} · ${fieldDraft.rowLabels.join(", ")}` : "Water East Tomato Rows", objective: fieldDraft ? "Prepare and establish every eligible planting slot reserved by the Crop Plan." : "Restore safe soil moisture and verify every assigned row.", fieldId: fieldDraft?.fieldId ?? "north-field", crop: fieldDraft?.cropLabel ?? "Tomatoes", scope: fieldDraft ? fieldDraft.rowLabels.join(", ") : "Rows 9–12", assigneeId: "staff-noah", supervisorId: "staff-jordan", deadline: "Tomorrow, 18:00", payout: 220, requirement: fieldDraft ? "Verify every planned planting slot" : "Verify moisture across four rows", materialIds: ["watering-can"], scopeRef: fieldDraft ? { fieldId: fieldDraft.fieldId, rowIds: fieldDraft.rowIds } : undefined, sourcePlanId: fieldDraft?.sourcePlanId }));
  const [contract, setContract] = useState<ContractCreateInput>(() => ({ template: "Planting", title: fieldDraft ? `Establish ${fieldDraft.cropLabel} · ${fieldDraft.rowLabels.join(", ")}` : "Establish East Field Tomato Row", objective: fieldDraft ? "Prepare, plant and initially water every position reserved by the Crop Plan." : "Prepare and establish eight tomato planting positions to farm standard.", field: fieldDraft?.fieldName ?? "East Field", scope: fieldDraft ? `${fieldDraft.rowLabels.join(", ")} · reserved planting scope` : "Row E · 8 planting slots", deadline: "12 Aug, 16:00", reward: 860, requirements: "Personal seedlings ×8, hand trowel and watering can", failureRule: "Missing the deadline or unverified planting fails the contract.", scopeRef: fieldDraft ? { fieldId: fieldDraft.fieldId, rowIds: fieldDraft.rowIds } : undefined, sourcePlanId: fieldDraft?.sourcePlanId }));

  useEffect(() => { void fixtureHubAdapter.load<{ nextReference: string }>(kind === "assignment" ? { kind: "assignmentCreate" } : { kind: "contractCreate" }, context).then(setAccess); }, [context, kind]);
  if (!access) return <StatePanel state="loading" />;
  if (access.state !== "ready" || !access.data) return <StatePanel state={access.state === "ready" ? "empty" : access.state} onAction={() => navigate(returnTo)} />;

  const valid = kind === "assignment" ? Boolean(assignment.title.trim() && assignment.objective.trim() && assignment.requirement.trim() && assignment.payout > 0) : Boolean(contract.title.trim() && contract.objective.trim() && contract.requirements.trim() && contract.failureRule.trim() && contract.reward > 0);
  const submit = async () => {
    setPending(true);
    const result = await fixtureHubAdapter.dispatch(kind === "assignment" ? { type: "assignment.create", input: assignment } : { type: "contract.create", input: contract }, context);
    setPending(false); setConfirm(false); setNotice(result.message);
    if (result.ok && result.entityId) navigate(kind === "assignment" ? `/work/assignments/${result.entityId}` : `/work/contracts/${result.entityId}`, { replace: true, state: { returnTo } });
  };

  return (
    <DeepViewShell eyebrow={kind === "assignment" ? "Internal work order" : "Funded public opportunity"} title={kind === "assignment" ? "Create Assignment" : "Create Public Contract"} subtitle={kind === "assignment" ? "Define one accountable result, reserve its pay and assign responsibility." : "Publish verifiable work with explicit materials, failure terms and funded escrow."} breadcrumb={["Work", kind === "assignment" ? "Assignments" : "Public Contracts", access.data.nextReference]} backLabel={`Back to ${kind === "assignment" ? "Assignments" : "Contracts"}`} onBack={() => navigate(returnTo)} status={<StatusPill tone="warning">Draft</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{valid ? "Ready for review" : "Required terms missing"}</span><p>{kind === "assignment" ? `$${assignment.payout} reserved after confirmation` : `$${contract.reward} held in escrow after confirmation`}</p></div><button className="domain-primary-action" type="button" disabled={!valid} onClick={() => setConfirm(true)}><ShieldCheck size={19} />Review & Confirm</button></>}>
      {notice ? <div className="domain-notice">{notice}</div> : null}
      <div className="domain-two-column">
        <div className="domain-card-stack">
          <DetailCard eyebrow="01 · Identity" title={kind === "assignment" ? "Assignment scope" : "Contract scope"}>
            <div className="domain-form-grid">
              {kind === "contract" ? <FarmSelect label="Contract Template" value={contract.template} options={templateOptions} onChange={(value) => setContract({ ...contract, template: value })} /> : null}
              <InputField label="Title" value={kind === "assignment" ? assignment.title : contract.title} onChange={(value) => kind === "assignment" ? setAssignment({ ...assignment, title: value }) : setContract({ ...contract, title: value })} />
              <label className="domain-input domain-input--wide"><span>Objective</span><textarea value={kind === "assignment" ? assignment.objective : contract.objective} onChange={(event) => kind === "assignment" ? setAssignment({ ...assignment, objective: event.target.value }) : setContract({ ...contract, objective: event.target.value })} /></label>
              {kind === "assignment" ? <FarmSelect label="Field" value={assignment.fieldId} options={fieldOptions} onChange={(value) => setAssignment({ ...assignment, fieldId: value })} /> : <InputField label="Field" value={contract.field} onChange={(value) => setContract({ ...contract, field: value })} />}
              <InputField label="Scope" value={kind === "assignment" ? assignment.scope : contract.scope} onChange={(value) => kind === "assignment" ? setAssignment({ ...assignment, scope: value }) : setContract({ ...contract, scope: value })} />
              <InputField label="Deadline" value={kind === "assignment" ? assignment.deadline : contract.deadline} onChange={(value) => kind === "assignment" ? setAssignment({ ...assignment, deadline: value }) : setContract({ ...contract, deadline: value })} />
            </div>
          </DetailCard>
          <DetailCard eyebrow="02 · Verification" title="Completion terms">
            <div className="domain-form-grid">
              <label className="domain-input domain-input--wide"><span>{kind === "assignment" ? "Verified Requirement" : "Contractor Requirements"}</span><textarea value={kind === "assignment" ? assignment.requirement : contract.requirements} onChange={(event) => kind === "assignment" ? setAssignment({ ...assignment, requirement: event.target.value }) : setContract({ ...contract, requirements: event.target.value })} /></label>
              {kind === "contract" ? <label className="domain-input domain-input--wide"><span>Failure Rule</span><textarea value={contract.failureRule} onChange={(event) => setContract({ ...contract, failureRule: event.target.value })} /></label> : null}
            </div>
          </DetailCard>
        </div>
        <aside className="domain-card-stack">
          {kind === "assignment" ? <DetailCard eyebrow="Responsibility" title="People & materials"><div className="domain-form-stack"><FarmSelect label="Eligible Worker" value={assignment.assigneeId} options={workerOptions} onChange={(value) => setAssignment({ ...assignment, assigneeId: value })} /><div className="choice-row"><button type="button" className={assignment.materialIds.includes("watering-can") ? "is-selected" : ""} onClick={() => setAssignment({ ...assignment, materialIds: assignment.materialIds.includes("watering-can") ? [] : ["watering-can"] })}><CheckCircle size={18} />Watering Can</button><button type="button" className={assignment.materialIds.includes("pruners") ? "is-selected" : ""} onClick={() => setAssignment({ ...assignment, materialIds: ["pruners"] })}><CheckCircle size={18} />Field Pruners</button></div></div></DetailCard> : <DetailCard eyebrow="Escrow" title="Funding"><p className="domain-emphasis"><CurrencyDollar size={25} />Reward is reserved before publication.</p></DetailCard>}
          <DetailCard eyebrow="Economic terms" title={kind === "assignment" ? "Reserved pay" : "Escrow reward"}><InputField label="Amount (USD)" type="number" min={1} value={kind === "assignment" ? assignment.payout : contract.reward} onChange={(value) => kind === "assignment" ? setAssignment({ ...assignment, payout: Number(value) }) : setContract({ ...contract, reward: Number(value) })} /><FactList facts={[{ label: "Release", value: "After verified result" }, { label: "Ownership", value: "Sonar Farm" }, { label: "Reference", value: access.data.nextReference }]} /></DetailCard>
        </aside>
      </div>
      {confirm ? <ConfirmDialog eyebrow={kind === "assignment" ? "Assignment control" : "Public contract control"} title={kind === "assignment" ? "Issue this Assignment?" : "Fund this contract draft?"} confirmLabel={kind === "assignment" ? "Create Assignment" : "Create Funded Draft"} pending={pending} onClose={() => setConfirm(false)} onConfirm={() => void submit()}><p>{kind === "assignment" ? "Responsibility, deadline and reserved pay will become visible to the selected Worker." : "The reward will be reserved in fixture escrow. You can inspect the draft before publishing it publicly."}</p></ConfirmDialog> : null}
    </DeepViewShell>
  );
}
