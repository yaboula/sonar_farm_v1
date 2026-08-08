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
import { useCallback, useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate, useParams, useSearchParams } from "react-router-dom";
import { fixtureHubAdapter } from "../adapters/FixtureHubAdapter";
import { DeepViewShell, StatusPill } from "../components/DeepViewShell";
import { FieldMap } from "../components/FieldMap";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { FieldDetail, FieldLayer, FieldRow, FieldSlot, HubContextModel, HubViewModel } from "../types";

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
  const context = useMemo<HubContextModel>(() => ({ role: hub.role, surface: hub.surface, viewState: hub.viewState, capabilities: hub.capabilities }), [hub.role, hub.surface, hub.viewState, hub.capabilities]);
  const [model, setModel] = useState<HubViewModel<FieldDetail> | null>(null);
  const [notice, setNotice] = useState<string>();
  const [handoff, setHandoff] = useState(false);
  const layer = (LAYERS.some((item) => item.id === searchParams.get("layer")) ? searchParams.get("layer") : "overview") as FieldLayer;
  const panel = (["diagnostics", "work", "history", "plans"].includes(searchParams.get("panel") ?? "") ? searchParams.get("panel") : "diagnostics") as DetailPanel;
  const selectedRowId = searchParams.get("row") ?? undefined;
  const selectedSlotId = searchParams.get("slot") ?? undefined;

  const reload = useCallback(async () => {
    const next = await fixtureHubAdapter.load<FieldDetail>({ kind: "fieldDetail", fieldId }, context);
    setModel(next);
  }, [context, fieldId]);

  useEffect(() => {
    let active = true;
    void fixtureHubAdapter.load<FieldDetail>({ kind: "fieldDetail", fieldId }, context).then((next) => {
      if (active) setModel(next);
    });
    return () => { active = false; };
  }, [context, fieldId]);

  useEffect(() => {
    if (!model?.data) return undefined;
    return fixtureHubAdapter.subscribeField(fieldId, model.data.sequence, context, () => { void reload(); });
  }, [context, fieldId, model?.data, reload]);

  const setQuery = (updates: Record<string, string | undefined>) => {
    const next = new URLSearchParams(searchParams);
    Object.entries(updates).forEach(([key, value]) => { if (value) next.set(key, value); else next.delete(key); });
    setSearchParams(next, { replace: true });
  };

  if (!model) return <StatePanel state="loading" />;
  if (model.state !== "ready") return <StatePanel state={model.state} onAction={() => navigate(returnTo)} />;
  if (!model.data) return <StatePanel state="empty" onAction={() => navigate(returnTo)} />;
  const field = model.data;
  const selectedRow = field.topology.rows.find((row) => row.id === selectedRowId);
  const selectedSlot = field.topology.slots.find((slot) => slot.id === selectedSlotId && slot.visible);
  const scopeLabel = selectedSlot?.label ?? selectedRow?.label ?? field.name;
  const tone = field.criticalCount ? "danger" : field.status === "ready" ? "success" : "active";
  const diagnostics = field.diagnostics.filter((item) => !selectedSlot ? !selectedRow ? true : item.scopeId === selectedRow.id || item.scope === "field" : item.scopeId === selectedSlot.id || item.scopeId === selectedSlot.rowId || item.scope === "field");
  const linkedWork = field.linkedWork.filter((item) => !selectedRow || item.scope.includes(selectedRow.label.replace("Row ", "Row ")) || item.scope.includes("Rows") || item.scope.includes("Field") || field.id === "greenhouse-2");

  const selectDiagnostic = (scope: string, scopeId: string) => {
    if (scope === "row") setQuery({ row: scopeId, slot: undefined });
    if (scope === "slot") {
      const slot = field.topology.slots.find((item) => item.id === scopeId);
      setQuery({ row: slot?.rowId, slot: scopeId });
    }
  };
  const setRoute = async () => {
    const result = await fixtureHubAdapter.dispatch({ type: "field.setRoute", scope: { fieldId: field.id, rowIds: selectedRow ? [selectedRow.id] : undefined } }, context);
    setNotice(result.message);
    if (result.ok && result.closeSurface) setHandoff(true);
  };
  const openWork = (id: string, kind: "assignment" | "contract" | "buyer_order") => {
    if (kind === "assignment") navigate(`/work/assignments/${id}`, { state: { returnTo: `${location.pathname}?${searchParams.toString()}` } });
    if (kind === "contract") navigate(`/work/contracts/active/${id}`, { state: { returnTo: `${location.pathname}?${searchParams.toString()}` } });
    if (kind === "buyer_order") navigate(`/work/orders/${id}`, { state: { returnTo: `${location.pathname}?${searchParams.toString()}` } });
  };

  const actionBar = (
    <>
      <div className="domain-action-summary"><span>{scopeLabel}</span><p>{selectedSlot ? "Slot diagnosis only · Work remains scoped to its Row" : selectedRow ? `${selectedRow.occupied} occupied · ${selectedRow.criticalCount} critical` : field.nextMilestone}</p></div>
      <div className="field-action-buttons">
        {linkedWork[0] ? <button type="button" className="domain-secondary-action" onClick={() => openWork(linkedWork[0].id, linkedWork[0].kind)}><ClipboardText size={18} />Open Work</button> : null}
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
        <div className="field-sync-status"><i />Live fixture · seq {field.sequence}<span>{field.serverTime.slice(11, 16)}</span></div>
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
            {panel === "plans" ? field.cropPlans.length ? field.cropPlans.map((plan) => <article className="field-plan-row" key={plan.id}><Plant size={20} /><span><strong>{plan.reference} · {plan.cropLabel}</strong><small>{plan.rowIds.map((rowId) => field.topology.rows.find((row) => row.id === rowId)?.label).join(", ")} · {plan.eligibleSlots} slots</small></span><em>{plan.statusLabel}</em></article>) : <div className="inline-empty">No Crop Plan currently reserves this Field.</div> : null}
          </div>
        </div>
        <aside className="field-scope-inspector">
          <span className="inspector-kicker">{selectedSlot ? "Selected Slot" : selectedRow ? "Selected Row" : "Field Scope"}</span>
          {selectedSlot ? <SlotInspector slot={selectedSlot} diagnostics={diagnostics.length} /> : selectedRow ? <RowInspector row={selectedRow} /> : <FieldInspector field={field} />}
        </aside>
      </div>
      {handoff ? <div className="field-handoff"><MapPin size={38} /><span>World handoff prepared</span><h2>{scopeLabel}</h2><p>The future NUI bridge will close the Hub and set the authoritative route. Fixture data has not changed.</p><button type="button" onClick={() => setHandoff(false)}>Return to Field Map</button></div> : null}
    </DeepViewShell>
  );
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
