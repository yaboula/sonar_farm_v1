import {
  ArrowRight,
  CheckCircle,
  ClockCountdown,
  Drop,
  Funnel,
  Leaf,
  MagnifyingGlass,
  MapTrifold,
  Package,
  Plant,
  Warning,
} from "@phosphor-icons/react";
import { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { HubScaffold } from "../components/HubScaffold";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { FieldOperationalStatus, FieldsOverviewData, HubContextModel, HubViewModel } from "../types";

type FieldFilter = "all" | "attention" | "ready" | "planned";

const statusIcon = (status: FieldOperationalStatus) => {
  if (status === "ready") return CheckCircle;
  if (["attention", "grace", "lease_expired", "planting_suspended"].includes(status)) return Warning;
  return Leaf;
};

export function FieldsView() {
  const hub = useHub();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const [model, setModel] = useState<HubViewModel<FieldsOverviewData> | null>(null);
  const [filter, setFilter] = useState<FieldFilter>((searchParams.get("filter") as FieldFilter) || "all");
  const [query, setQuery] = useState(searchParams.get("query") ?? "");
  const context = useMemo<HubContextModel>(() => ({
    actorId: hub.actorId,
    role: hub.role,
    surface: hub.surface,
    presence: hub.presence,
    capabilitiesRevision: hub.capabilitiesRevision,
    viewState: hub.viewState,
    capabilities: hub.capabilities,
  }), [hub.actorId, hub.role, hub.surface, hub.presence, hub.capabilitiesRevision, hub.viewState, hub.capabilities]);

  useEffect(() => {
    let active = true;
    void hub.adapter.load<FieldsOverviewData>({ kind: "fieldsOverview" }, context).then((next) => {
      if (active) setModel(next);
    });
    return () => { active = false; };
  }, [context, hub.adapter]);

  const data = model?.data;
  const visibleFields = useMemo(() => (data?.fields ?? []).filter((field) => {
    const matchesQuery = `${field.name} ${field.cropSummary} ${field.location}`.toLowerCase().includes(query.toLowerCase());
    if (!matchesQuery) return false;
    if (filter === "attention") return field.criticalCount > 0 || field.attentionCount > 0;
    if (filter === "ready") return field.status === "ready";
    if (filter === "planned") return field.planned > 0;
    return true;
  }), [data?.fields, filter, query]);

  const requestedFocus = searchParams.get("focus");
  const selected = visibleFields.find((field) => field.id === requestedFocus) ?? visibleFields[0];
  const updateFilter = (next: FieldFilter) => {
    setFilter(next);
    const params = new URLSearchParams(searchParams);
    if (next === "all") params.delete("filter"); else params.set("filter", next);
    setSearchParams(params, { replace: true });
  };
  const updateQuery = (next: string) => {
    setQuery(next);
    const params = new URLSearchParams(searchParams);
    if (next) params.set("query", next); else params.delete("query");
    setSearchParams(params, { replace: true });
  };
  const focusField = (id: string) => {
    const params = new URLSearchParams(searchParams);
    params.set("focus", id);
    setSearchParams(params, { replace: true });
  };

  if (!model) return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;

  const toolbar = (
    <>
      <div className="segmented-filter" aria-label="Field filter">
        <Funnel size={18} />
        {(["all", "attention", "ready", "planned"] as FieldFilter[]).map((item) => (
          <button type="button" key={item} className={filter === item ? "is-selected" : ""} onClick={() => updateFilter(item)}>
            {item === "all" ? "All Fields" : item === "attention" ? "Attention" : item === "ready" ? "Harvest Ready" : "Crop Plans"}
          </button>
        ))}
      </div>
      <label className="search-control">
        <MagnifyingGlass size={18} />
        <input value={query} onChange={(event) => updateQuery(event.target.value)} placeholder="Search Fields" />
      </label>
    </>
  );

  const aside = selected ? (
    <div className="detail-inspector field-overview-inspector">
      <span className="inspector-kicker">Selected Field</span>
      <MapTrifold size={38} weight="thin" />
      <h2>{selected.name}</h2>
      <p>{selected.location}</p>
      <div className="inspector-rule" />
      <dl>
        <div><dt>Status</dt><dd>{selected.statusLabel}</dd></div>
        <div><dt>Capacity</dt><dd>{selected.occupied + selected.planned} / {selected.capacity}</dd></div>
        <div><dt>Attention</dt><dd>{selected.criticalCount ? `${selected.criticalCount} critical` : `${selected.attentionCount} open`}</dd></div>
        <div><dt>Land</dt><dd>{selected.ownership}</dd></div>
        {selected.yieldForecast ? <div><dt>Yield range</dt><dd>{selected.yieldForecast}</dd></div> : null}
      </dl>
      <div className="field-capacity-readout">
        <div><span>Occupied</span><strong>{selected.occupied}</strong></div>
        <div><span>Planned</span><strong>{selected.planned}</strong></div>
        <div><span>Available</span><strong>{selected.capacity - selected.occupied - selected.planned}</strong></div>
      </div>
      <button type="button" className="inspector-action" onClick={() => navigate(`/fields/${selected.id}`, { state: { returnTo: `/fields?${searchParams.toString()}` } })}>
        Open Field Map
        <ArrowRight size={18} />
      </button>
    </div>
  ) : undefined;

  return (
    <HubScaffold
      eyebrow="Land & cultivation"
      title="Fields"
      subtitle="Move from company-wide attention to the exact Row that needs work."
      toolbar={toolbar}
      aside={aside}
    >
      <div className="fields-portfolio">
        <section className={`field-landing field-landing--${data.landing}`}>
          <div className="field-landing-icon">
            {data.landing === "materials" ? <Package size={27} /> : data.landing === "contract" ? <MapTrifold size={27} /> : data.landing === "assignment" ? <ClockCountdown size={27} /> : <Warning size={27} />}
          </div>
          <div>
            <span>{data.landing === "attention" ? "Operational priority" : data.landing === "assignment" ? "My active scope" : data.landing === "materials" ? "Material demand" : "Contract access"}</span>
            <strong>{data.headline}</strong>
          </div>
          {data.activeScope ? <button type="button" onClick={() => navigate(`/fields/${data.activeScope?.fieldId}?row=${data.activeScope?.rowIds?.[0] ?? ""}`, { state: { returnTo: `/fields?${searchParams.toString()}` } })}>Open scope<ArrowRight size={16} /></button> : null}
        </section>

        {visibleFields.length ? (
          <div className={`field-grid field-grid--${visibleFields.length}`}>
            {visibleFields.map((field) => {
              const Icon = statusIcon(field.status);
              const usedPercent = Math.round(((field.occupied + field.planned) / field.capacity) * 100);
              const occupiedPercent = Math.round((field.occupied / field.capacity) * 100);
              return (
                <button className={selected?.id === field.id ? "field-card field-card--operational is-selected" : "field-card field-card--operational"} type="button" key={field.id} onClick={() => focusField(field.id)} onDoubleClick={() => navigate(`/fields/${field.id}`, { state: { returnTo: `/fields?${searchParams.toString()}` } })}>
                  <div className="card-topline">
                    <span className={`status-dot status-${field.status}`}><Icon size={17} />{field.statusLabel}</span>
                    {field.criticalCount ? <strong className="field-critical-count">{field.criticalCount} critical</strong> : <ArrowRight size={18} />}
                  </div>
                  <div className="field-card-title"><Plant size={28} weight="thin" /><div><h2>{field.name}</h2><p>{field.cropSummary}</p></div></div>
                  <div className="field-capacity-track" aria-label={`${usedPercent}% of Field capacity committed`}>
                    <i style={{ width: `${occupiedPercent}%` }} />
                    <b style={{ left: `${occupiedPercent}%`, width: `${Math.max(0, usedPercent - occupiedPercent)}%` }} />
                  </div>
                  <div className="field-card-operational-meta">
                    <span><Drop size={16} />{field.nextMilestone}</span>
                    <span>{field.occupied + field.planned} / {field.capacity} committed</span>
                  </div>
                </button>
              );
            })}
          </div>
        ) : <div className="inline-empty">No Fields match this operating view.</div>}
      </div>
    </HubScaffold>
  );
}
