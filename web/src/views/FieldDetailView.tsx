import {
  ArrowRight,
  ClipboardText,
  ClockCounterClockwise,
  Drop,
  Leaf,
  MapPin,
  Package,
  Plant,
  ShieldWarning,
  TrendUp,
  Warning,
} from "@phosphor-icons/react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useLocation, useNavigate, useParams, useSearchParams } from "react-router-dom";
import { applyFieldDelta, createFieldSyncState, projectFieldDelta } from "../adapters/fieldSync";
import { DeepViewShell, StatusPill } from "../components/DeepViewShell";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { CropPlanDialog } from "../components/CropPlanDialog";
import { FieldMap } from "../components/FieldMap";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { CropPlan, CropPlanInput, FieldDetail, FieldLayer, FieldRow, FieldSlot, FieldSyncState, HubContextModel, HubViewModel } from "../types";

const LAYERS: Array<{ id: FieldLayer; label: string }> = [
  { id: "overview", label: "Overview" },
  { id: "water", label: "Water" },
  { id: "health", label: "Health" },
  { id: "growth", label: "Growth" },
  { id: "readiness", label: "Readiness" },
  { id: "work", label: "Work" },
  { id: "plan", label: "Crop Plan" },
];
type DetailPanel = "diagnostics" | "work" | "history" | "plans";

function metric(value: number | undefined, label: string) {
  return value === undefined ? "Not available" : `${Math.round(value)}% ${label}`;
}

export function FieldDetailView() {
  const { fieldId = "" } = useParams();
  const hub = useHub();
  const navigate = useNavigate();
  const location = useLocation();
  const [searchParams, setSearchParams] = useSearchParams();
  const returnTo = (location.state as { returnTo?: string } | null)?.returnTo ?? `/fields?focus=${fieldId}`;
  const context = useMemo<HubContextModel>(() => ({ actorId: hub.actorId, role: hub.role, surface: hub.surface, presence: hub.presence, capabilitiesRevision: hub.capabilitiesRevision, viewState: hub.viewState, capabilities: hub.capabilities }), [hub.actorId, hub.role, hub.surface, hub.presence, hub.capabilitiesRevision, hub.viewState, hub.capabilities]);
  const [model, setModel] = useState<HubViewModel<FieldDetail> | null>(null);
  const [notice, setNotice] = useState<string>();
  const [handoff, setHandoff] = useState(false);
  const [planEditor, setPlanEditor] = useState<CropPlan | "new">();
  const [planPending, setPlanPending] = useState(false);
  const [selectedPlanId, setSelectedPlanId] = useState<string>();
  const [cancelPlan, setCancelPlan] = useState<CropPlan>();
  const [syncStatus, setSyncStatus] = useState<"live" | "resyncing">("live");
  const syncRef = useRef<FieldSyncState | undefined>(undefined);
  const layer = (LAYERS.some((item) => item.id === searchParams.get("layer")) ? searchParams.get("layer") : "overview") as FieldLayer;
  const panel = (["diagnostics", "work", "history", "plans"].includes(searchParams.get("panel") ?? "") ? searchParams.get("panel") : "diagnostics") as DetailPanel;
  const selectedRowId = searchParams.get("row") ?? undefined;
  const selectedSlotId = searchParams.get("slot") ?? undefined;

  const reload = useCallback(async () => {
    setSyncStatus("resyncing");
    const next = await hub.adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId }, context);
    syncRef.current = next.data ? createFieldSyncState(next.data) : undefined;
    setModel(next);
    setSyncStatus("live");
  }, [context, fieldId, hub.adapter]);

  useEffect(() => {
    let active = true;
    void hub.adapter.load<FieldDetail>({ kind: "fieldDetail", fieldId }, context).then((next) => {
      if (active) {
        syncRef.current = next.data ? createFieldSyncState(next.data) : undefined;
        setModel(next);
        setSyncStatus("live");
      }
    });
    return () => { active = false; };
  }, [context, fieldId, hub.adapter]);

  const hasFieldData = Boolean(model?.data);
  useEffect(() => {
    if (!hasFieldData) return undefined;
    const timer = window.setInterval(() => void reload(), 5000);
    return () => window.clearInterval(timer);
  }, [hasFieldData, reload]);

  useEffect(() => {
    if (!model?.data) return undefined;
    return hub.adapter.subscribeField(fieldId, model.data.sequence, context, (delta) => {
      if (delta.fieldId !== fieldId) return;
      const currentSync = syncRef.current;
      if (!currentSync) { void reload(); return; }
      const nextSync = applyFieldDelta(currentSync, delta);
      syncRef.current = nextSync;
      if (nextSync.resyncRequired) { void reload(); return; }
      setModel((current) => current?.data ? { ...current, data: projectFieldDelta(current.data, delta) } : current);
    });
  }, [context, fieldId, hub.adapter, model?.data, reload]);

  const setQuery = (updates: Record<string, string | undefined>) => {
    const next = new URLSearchParams(searchParams);
    Object.entries(updates).forEach(([key, value]) => { if (value) next.set(key, value); else next.delete(key); });
    setSearchParams(next, { replace: true });
  };

  if (!model) return <StatePanel state="loading" />;
  if (model.state !== "ready") return <StatePanel state={model.state} onAction={() => navigate(returnTo)} />;
  if (!model.data) return <StatePanel state="empty" title="Field not found" body="This Field identifier is not part of the authorized company portfolio." actionLabel="Back to Fields" onAction={() => navigate(returnTo)} />;
  const field = model.data;
  const selectedRow = field.topology.rows.find((row) => row.id === selectedRowId);
  const selectedSlot = field.topology.slots.find((slot) => slot.id === selectedSlotId && slot.visible);
  const scopeLabel = selectedSlot?.label ?? selectedRow?.label ?? field.name;
  const tone = field.criticalCount ? "danger" : field.status === "ready" ? "success" : "active";
  const diagnostics = field.diagnostics.filter((item) => !selectedSlot ? !selectedRow ? true : item.scopeId === selectedRow.id || item.scope === "field" : item.scopeId === selectedSlot.id || item.scopeId === selectedSlot.rowId || item.scope === "field");
  const linkedWork = field.linkedWork.filter((item) => !selectedRow || selectedRow.assignmentIds.includes(item.id) || selectedRow.contractIds.includes(item.id) || item.kind === "buyer_order");

  const selectDiagnostic = (scope: string, scopeId: string) => {
    if (scope === "row") setQuery({ row: scopeId, slot: undefined });
    if (scope === "slot") {
      const slot = field.topology.slots.find((item) => item.id === scopeId);
      setQuery({ row: slot?.rowId, slot: scopeId });
    }
  };
  const setRoute = async () => {
    const result = await hub.adapter.dispatch({ type: "field.setRoute", scope: { fieldId: field.id, rowIds: selectedRow ? [selectedRow.id] : undefined } }, context);
    setNotice(result.message);
    if (result.ok && result.closeSurface) setHandoff(true);
  };
  const openWork = (id: string, kind: "assignment" | "contract" | "buyer_order") => {
    if (kind === "assignment") navigate(`/work/assignments/${id}`, { state: { returnTo: `${location.pathname}?${searchParams.toString()}` } });
    if (kind === "contract") navigate(`/work/contracts/active/${id}`, { state: { returnTo: `${location.pathname}?${searchParams.toString()}` } });
    if (kind === "buyer_order") navigate(`/work/orders/${id}`, { state: { returnTo: `${location.pathname}?${searchParams.toString()}` } });
  };
  const savePlan = async (input: CropPlanInput) => {
    setPlanPending(true);
    const result = planEditor && planEditor !== "new"
      ? await hub.adapter.dispatch({ type: "cropPlan.update", planId: planEditor.id, input }, context)
      : await hub.adapter.dispatch({ type: "cropPlan.create", input }, context);
    setPlanPending(false);
    setPlanEditor(undefined);
    setNotice(result.message);
    if (result.ok) {
      setSelectedPlanId(result.entityId ?? (planEditor && planEditor !== "new" ? planEditor.id : undefined));
      setQuery({ panel: "plans", layer: "plan" });
      await reload();
    }
  };
  const resolvePlanCancellation = async () => {
    if (!cancelPlan) return;
    setPlanPending(true);
    const result = await hub.adapter.dispatch({ type: "cropPlan.cancel", planId: cancelPlan.id }, context);
    setPlanPending(false);
    setCancelPlan(undefined);
    setSelectedPlanId(undefined);
    setNotice(result.message);
    await reload();
  };
  const openWorkDraft = (kind: "assignment" | "contract", plan?: CropPlan) => {
    const rowIds = plan?.rowIds ?? (selectedRow ? [selectedRow.id] : field.topology.rows.filter((row) => row.visibleDetail).map((row) => row.id));
    const rowLabels = rowIds.map((rowId) => field.topology.rows.find((row) => row.id === rowId)?.label ?? rowId);
    const cropLabel = plan?.cropLabel ?? selectedRow?.cropLabel ?? field.cropSummary.split(" · ")[0];
    const crop = plan?.crop ?? cropLabel.toLowerCase().replace(/s$/, "");
    navigate(kind === "assignment" ? "/work/assignments/new" : "/work/contracts/new", {
      state: {
        returnTo: `${location.pathname}?${searchParams.toString()}`,
        fieldDraft: { fieldId: field.id, fieldName: field.name, rowIds, rowLabels, crop, cropLabel, sourcePlanId: plan?.id },
      },
    });
  };

  const actionBar = (
    <>
      <div className="domain-action-summary"><span>{scopeLabel}</span><p>{selectedSlot ? "Slot diagnosis only · Work remains scoped to its Row" : selectedRow ? `${selectedRow.occupied} occupied · ${selectedRow.criticalCount} critical` : field.nextMilestone}</p></div>
      <div className="field-action-buttons">
        {linkedWork[0] ? <button type="button" className="domain-secondary-action" onClick={() => openWork(linkedWork[0].id, linkedWork[0].kind)}><ClipboardText size={18} />Open Work</button> : null}
        {!selectedSlot && field.availableActions.includes("create_plan") ? <button type="button" className="domain-secondary-action" onClick={() => setPlanEditor("new")}><Plant size={18} />Crop Plan</button> : null}
        {!selectedSlot && field.availableActions.includes("create_assignment") ? <button type="button" className="domain-secondary-action" onClick={() => openWorkDraft("assignment")}><ClipboardText size={18} />Assignment</button> : null}
        {!selectedSlot && field.availableActions.includes("create_contract") ? <button type="button" className="domain-secondary-action" onClick={() => openWorkDraft("contract")}><ClipboardText size={18} />Contract</button> : null}
        {field.availableActions.includes("set_route") ? <button type="button" className="domain-primary-action" onClick={() => void setRoute()}><MapPin size={18} />Set Route</button> : null}
      </div>
    </>
  );

  return (
    <DeepViewShell eyebrow="Field operating record" title={field.name} subtitle={`${field.location} · ${field.cropSummary}`} breadcrumb={["Fields", field.name, selectedSlot?.label ?? selectedRow?.label ?? "Operating Map"]} backLabel="Back to Fields" onBack={() => navigate(returnTo)} status={<StatusPill tone={tone}>{field.statusLabel}</StatusPill>} actionBar={actionBar}>
      {notice ? <div className="domain-notice field-domain-notice">{notice}</div> : null}
      <div className="field-detail-toolbar">
        <div className="field-layer-tabs" role="tablist" aria-label="Operating layer">
          {LAYERS.map((item) => <button type="button" role="tab" aria-selected={layer === item.id} className={layer === item.id ? "is-selected" : ""} key={item.id} onClick={() => setQuery({ layer: item.id })}>{item.label}</button>)}
        </div>
        <div className={`field-sync-status field-sync-status--${syncStatus}`} role="status"><i />{syncStatus === "live" ? `Authoritative live · seq ${field.sequence}` : "Resyncing authoritative snapshot"}<span>{field.serverTime.slice(11, 16)}</span></div>
      </div>
      <div className="field-operating-layout">
        <div className="field-map-column">
          <FieldMap field={field} layer={layer} selectedRowId={selectedRow?.id} selectedSlotId={selectedSlot?.id} onSelectRow={(rowId) => setQuery({ row: rowId, slot: undefined })} onSelectSlot={(slotId, rowId) => setQuery({ row: rowId, slot: slotId })} />
          <div className="field-context-tabs" role="tablist" aria-label="Field context">
            {(["diagnostics", "work", "history", "plans"] as DetailPanel[]).filter((item) => item !== "history" || hub.capabilities.viewFieldHistory).map((item) => <button type="button" role="tab" aria-selected={panel === item} className={panel === item ? "is-selected" : ""} key={item} onClick={() => setQuery({ panel: item })}>{item === "diagnostics" ? `Attention ${field.diagnostics.length}` : item === "work" ? `Linked Work ${field.linkedWork.length}` : item === "history" ? "History" : `Crop Plans ${field.cropPlans.length}`}</button>)}
          </div>
          <div className="field-context-panel">
            {panel === "diagnostics" ? diagnostics.length ? diagnostics.map((item) => <button type="button" className={`field-diagnostic-row field-diagnostic-row--${item.severity}`} key={item.id} onClick={() => selectDiagnostic(item.scope, item.scopeId)}><Warning size={19} /><span><strong>{item.title}</strong><small>{item.evidence} · {item.window}</small></span><em>{item.severity}</em><ArrowRight size={16} /></button>) : <div className="inline-empty">No attention requirements affect this scope.</div> : null}
            {panel === "work" ? linkedWork.length ? linkedWork.map((item) => <button type="button" className="field-linked-row" key={item.id} onClick={() => openWork(item.id, item.kind)}><ClipboardText size={20} /><span><strong>{item.title}</strong><small>{item.scope}</small></span><em>{item.status}</em><ArrowRight size={16} /></button>) : <div className="inline-empty">No active Work is linked to this scope.</div> : null}
            {panel === "history" ? field.events.map((item) => <article className="field-event-row" key={item.id}><ClockCounterClockwise size={19} /><span><strong>{item.title}</strong><small>{item.detail}</small></span><time>{item.at}</time></article>) : null}
            {panel === "plans" ? field.cropPlans.length ? field.cropPlans.map((plan) => <button type="button" className={selectedPlanId === plan.id ? "field-plan-row is-selected" : "field-plan-row"} key={plan.id} onClick={() => setSelectedPlanId(plan.id)}><Plant size={20} /><span><strong>{plan.reference} · {plan.cropLabel}</strong><small>{plan.rowIds.map((rowId) => field.topology.rows.find((row) => row.id === rowId)?.label).join(", ")} · {plan.eligibleSlots} slots</small></span><em>{plan.statusLabel}</em></button>) : <div className="inline-empty">No Crop Plan currently reserves this Field.</div> : null}
          </div>
          {panel === "plans" && selectedPlanId ? <PlanFollowUp plan={field.cropPlans.find((item) => item.id === selectedPlanId)} onEdit={setPlanEditor} onAssignment={(plan) => openWorkDraft("assignment", plan)} onContract={(plan) => openWorkDraft("contract", plan)} onCancel={setCancelPlan} capabilities={field.availableActions} /> : null}
        </div>
        <aside className="field-scope-inspector">
          <span className="inspector-kicker">{selectedSlot ? "Selected Slot" : selectedRow ? "Selected Row" : "Field Scope"}</span>
          {selectedSlot ? <SlotInspector slot={selectedSlot} diagnostics={diagnostics.length} /> : selectedRow ? <RowInspector row={selectedRow} /> : <FieldInspector field={field} />}
        </aside>
      </div>
      {handoff ? <div className="field-handoff"><MapPin size={38} /><span>Authoritative route set</span><h2>{scopeLabel}</h2><p>The Hub will close in FiveM and the server-validated Field access will be marked on the map.</p><button type="button" onClick={() => setHandoff(false)}>Return to Field Map</button></div> : null}
      {planEditor ? <CropPlanDialog field={field} initialRowId={selectedRow?.id} existingPlan={planEditor === "new" ? undefined : planEditor} pending={planPending} onClose={() => setPlanEditor(undefined)} onConfirm={(input) => void savePlan(input)} /> : null}
      {cancelPlan ? <ConfirmDialog eyebrow="Crop Plan control" title={`Cancel ${cancelPlan.reference}?`} confirmLabel="Cancel Crop Plan" tone="danger-confirm" pending={planPending} onClose={() => setCancelPlan(undefined)} onConfirm={() => void resolvePlanCancellation()}><p>{cancelPlan.rowIds.length} reserved Row{cancelPlan.rowIds.length === 1 ? "" : "s"} will be released. Occupied plants and Work history are not changed.</p></ConfirmDialog> : null}
    </DeepViewShell>
  );
}

function PlanFollowUp({ plan, onEdit, onAssignment, onContract, onCancel, capabilities }: { plan?: CropPlan; onEdit: (plan: CropPlan) => void; onAssignment: (plan: CropPlan) => void; onContract: (plan: CropPlan) => void; onCancel: (plan: CropPlan) => void; capabilities: FieldDetail["availableActions"] }) {
  if (!plan) return null;
  const reserved = plan.status === "reserved";
  return <section className="crop-plan-follow-up"><div><span>Selected Crop Plan</span><strong>{plan.reference} · {plan.statusLabel}</strong><small>{reserved ? "Reservation is ready to become accountable Work." : plan.linkedAssignmentId ? `Linked to ${plan.linkedAssignmentId.toUpperCase()}` : plan.linkedContractId ? `Linked to ${plan.linkedContractId.toUpperCase()}` : "Scope is locked."}</small></div>{reserved ? <div><button type="button" onClick={() => onEdit(plan)}>Edit Plan</button>{capabilities.includes("create_assignment") ? <button type="button" onClick={() => onAssignment(plan)}>Create Assignment</button> : null}{capabilities.includes("create_contract") ? <button type="button" onClick={() => onContract(plan)}>Create Public Contract</button> : null}<button type="button" className="danger" onClick={() => onCancel(plan)}>Cancel Plan</button></div> : null}</section>;
}

function FieldInspector({ field }: { field: FieldDetail }) {
  return <><div className="field-inspector-icon"><Leaf size={32} /></div><h2>{field.name}</h2><p>{field.ownership}</p><dl><div><dt>Occupied</dt><dd>{field.occupied} / {field.capacity}</dd></div><div><dt>Planned</dt><dd>{field.planned}</dd></div><div><dt>Critical</dt><dd>{field.criticalCount}</dd></div>{field.yieldForecast ? <div><dt>Yield range</dt><dd>{field.yieldForecast}</dd></div> : null}</dl><div className="field-inspector-callout"><TrendUp size={18} /><span><strong>Next milestone</strong>{field.nextMilestone}</span></div>{field.restriction ? <div className="field-inspector-callout is-warning"><ShieldWarning size={18} /><span><strong>Restriction</strong>{field.restriction}</span></div> : null}</>;
}

function RowInspector({ row }: { row: FieldRow }) {
  return <><div className="field-inspector-icon"><Plant size={32} /></div><h2>{row.label}</h2><p>{row.cropLabel} · {row.status}</p>{!row.visibleDetail ? <div className="field-inspector-callout is-warning"><ShieldWarning size={18} /><span><strong>Restricted detail</strong>Plant and Slot data requires an assigned scope.</span></div> : <><dl><div><dt>Occupied</dt><dd>{row.occupied}</dd></div><div><dt>Planned</dt><dd>{row.planned}</dd></div><div><dt>Available</dt><dd>{row.available}</dd></div><div><dt>Water</dt><dd>{metric(row.averageWater, "average")}</dd></div><div><dt>Health</dt><dd>{metric(row.averageHealth, "average")}</dd></div><div><dt>Growth</dt><dd>{metric(row.averageGrowth, "average")}</dd></div></dl>{row.materialDemand ? <div className="field-inspector-callout"><Package size={18} /><span><strong>Material demand</strong>{row.materialDemand}</span></div> : null}</>}</>;
}

function SlotInspector({ slot, diagnostics }: { slot: FieldSlot; diagnostics: number }) {
  return <><div className="field-inspector-icon"><Plant size={32} /></div><h2>{slot.label}</h2><p>{slot.plant ? `${slot.plant.cropLabel} · ${slot.plant.stage}` : slot.status === "planned" ? `${slot.plannedCrop} planned` : "Empty planting position"}</p>{slot.plant ? <dl><div><dt>Growth</dt><dd>{slot.plant.progress}%</dd></div><div><dt>Water</dt><dd>{slot.plant.water}%</dd></div><div><dt>Health</dt><dd>{slot.plant.health}%</dd></div><div><dt>Readiness</dt><dd>{slot.plant.readiness}</dd></div><div><dt>Spoilage</dt><dd>{slot.plant.spoilage}%</dd></div><div><dt>Last care</dt><dd>{slot.plant.lastCareAt}</dd></div></dl> : <div className="field-inspector-callout"><Drop size={18} /><span><strong>Physical state</strong>No plant occupies this authoritative slot.</span></div>}<div className={`field-inspector-callout${diagnostics ? " is-warning" : ""}`}><Warning size={18} /><span><strong>Attention</strong>{diagnostics ? `${diagnostics} diagnostic signal${diagnostics === 1 ? "" : "s"}` : "No current exception"}</span></div><small className="slot-work-rule">Slot detail is diagnostic. Work remains scoped to its Row.</small></>;
}
