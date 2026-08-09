import { Briefcase, CaretRight, Clock, FilePlus, FileText, Handshake, MagnifyingGlass, Plus } from "@phosphor-icons/react";
import { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { HubScaffold } from "../components/HubScaffold";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { HubContextModel, HubViewModel, WorkArea, WorkFixture, WorkQueueData } from "../types";

const TAB_LABELS: Record<WorkArea, string> = {
  assignments: "Assignments",
  buyerOrders: "Buyer Orders",
  publicContracts: "Public Contracts",
  activeContract: "Active Contract",
};

function areaForItem(item: WorkFixture, activeAreas: WorkArea[]) {
  if (item.type === "assignment") return "assignments";
  if (item.type === "buyerOrder") return "buyerOrders";
  return activeAreas.includes("activeContract") ? "activeContract" : "publicContracts";
}

export function WorkView() {
  const hub = useHub();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const [model, setModel] = useState<HubViewModel<WorkQueueData> | null>(null);
  const context = useMemo<HubContextModel>(() => ({ actorId: hub.actorId, role: hub.role, surface: hub.surface, presence: hub.presence, capabilitiesRevision: hub.capabilitiesRevision, viewState: hub.viewState, capabilities: hub.capabilities, selectedId: hub.selectedId, selectedKind: hub.selectedKind }), [hub.actorId, hub.role, hub.surface, hub.presence, hub.capabilitiesRevision, hub.viewState, hub.capabilities, hub.selectedId, hub.selectedKind]);
  const contextKey = `${hub.role}:${hub.surface}:${hub.viewState}`;
  const [loadedFor, setLoadedFor] = useState("");
  useEffect(() => {
    let active = true;
    void hub.adapter.load<WorkQueueData>({ kind: "hub", route: "work" }, context).then((next) => {
      if (active) { setModel(next); setLoadedFor(contextKey); }
    });
    return () => { active = false; };
  }, [context, contextKey, hub.adapter]);

  if (!model || loadedFor !== contextKey) return <StatePanel state="loading" />;
  if (model.state !== "ready") return <StatePanel state={model.state} onAction={() => hub.setViewState("ready")} />;
  const data = model.data;
  if (!data || !data.areas.length) return <StatePanel state="restricted" />;

  const requestedArea = searchParams.get("area") as WorkArea | null;
  const activeArea = requestedArea && data.areas.includes(requestedArea) ? requestedArea : data.areas[0];
  const query = searchParams.get("q") ?? "";
  const items = data.items.filter((item) => areaForItem(item, data.areas) === activeArea).filter((item) => `${item.title} ${item.meta} ${item.status}`.toLowerCase().includes(query.toLowerCase()));
  const selected = items.find((item) => item.id === hub.selectedId) ?? items[0];

  const openItem = (item: WorkFixture) => {
    hub.select(item.type, item.id);
    const returnTo = `/work?${searchParams.toString()}`;
    if (item.type === "assignment") navigate(`/work/assignments/${item.id}`, { state: { returnTo } });
    else if (item.type === "buyerOrder") navigate(`/work/orders/${item.id}`, { state: { returnTo } });
    else if (activeArea === "activeContract") navigate(`/work/contracts/active/${item.id}`, { state: { returnTo } });
    else navigate(`/work/contracts/${item.id}`, { state: { returnTo } });
  };

  const toolbar = (
    <>
      <div className="hub-tabs" role="tablist" aria-label="Work area">
        {data.areas.map((area) => <button type="button" role="tab" aria-selected={activeArea === area} className={activeArea === area ? "is-selected" : ""} key={area} onClick={() => { const next = new URLSearchParams(); next.set("area", area); setSearchParams(next); hub.select(); }}>{TAB_LABELS[area]}</button>)}
      </div>
      <label className="search-control"><MagnifyingGlass size={18} /><input value={query} onChange={(event) => { const next = new URLSearchParams(searchParams); if (event.target.value) next.set("q", event.target.value); else next.delete("q"); next.set("area", activeArea); setSearchParams(next, { replace: true }); }} placeholder="Search work" /></label>
      {activeArea === "assignments" && data.canCreateAssignment ? <button className="toolbar-create" type="button" onClick={() => navigate("/work/assignments/new", { state: { returnTo: `/work?${searchParams.toString()}` } })}><Plus size={17} />Create Assignment</button> : null}
      {activeArea === "publicContracts" && data.canCreateContract ? <button className="toolbar-create" type="button" onClick={() => navigate("/work/contracts/new", { state: { returnTo: `/work?${searchParams.toString()}` } })}><FilePlus size={17} />Create Contract</button> : null}
    </>
  );

  const aside = selected ? (
    <div className="detail-inspector">
      <span className="inspector-kicker">{TAB_LABELS[activeArea]} selected</span>
      {selected.type === "contract" ? <Handshake size={38} weight="thin" /> : <Briefcase size={38} weight="thin" />}
      <h2>{selected.title}</h2><p>{selected.meta}</p><div className="inspector-rule" />
      <dl><div><dt>Status</dt><dd>{selected.status}</dd></div><div><dt>Deadline</dt><dd>{selected.deadline}</dd></div><div><dt>Verified</dt><dd>{selected.progress}%</dd></div></dl>
      <div className="moisture-readout"><span>Verified progress</span><div><i style={{ width: `${selected.progress}%` }} /></div></div>
      <button type="button" className="inspector-action" onClick={() => openItem(selected)}>Open {selected.type === "buyerOrder" ? "Buyer Order" : selected.type === "contract" ? "Contract" : "Assignment"}<CaretRight size={18} /></button>
    </div>
  ) : null;

  return (
    <HubScaffold eyebrow="Operational commitments" title="Work" subtitle="Every obligation has an owner, verified result and accountable next action." toolbar={toolbar} aside={aside}>
      <div className="work-list">
        {items.length ? items.map((item) => <button type="button" className={selected?.id === item.id ? "work-row is-selected" : "work-row"} key={item.id} onClick={() => hub.select(item.type, item.id)} onDoubleClick={() => openItem(item)}>
          <span className="work-type-icon">{item.type === "contract" ? <Handshake size={25} /> : <FileText size={25} />}</span>
          <span className="work-identity"><strong>{item.title}</strong><small>{item.meta}</small></span>
          <span className="work-status">{item.status}</span><span className="work-deadline"><Clock size={17} />{item.deadline}</span><span className="row-caret"><CaretRight size={19} /></span>
        </button>) : <div className="inline-empty">No matching work in this accountable queue.</div>}
      </div>
    </HubScaffold>
  );
}
