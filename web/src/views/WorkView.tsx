import {
  Briefcase,
  CaretRight,
  Clock,
  FileText,
  Handshake,
  MagnifyingGlass,
} from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { HubScaffold } from "../components/HubScaffold";
import { StatePanel } from "../components/StatePanel";
import { WORK } from "../data/fixtures";
import { useHub } from "../store/HubContext";
import type { WorkFixture } from "../types";

type WorkTab = WorkFixture["type"];

const TAB_LABELS: Record<WorkTab, string> = {
  assignment: "Assignments",
  buyerOrder: "Buyer Orders",
  contract: "Public Contracts",
};

export function WorkView() {
  const { role, viewState, selectedId, select, setViewState } = useHub();
  const initialTab = WORK.find((item) => item.id === selectedId)?.type ?? "assignment";
  const [tab, setTab] = useState<WorkTab>(initialTab);
  const [query, setQuery] = useState("");
  const allowedTabs: WorkTab[] =
    role === "visitor" || role === "contractor"
      ? ["contract"]
      : ["assignment", "buyerOrder", "contract"];
  const safeTab = allowedTabs.includes(tab) ? tab : allowedTabs[0];
  const items = useMemo(
    () =>
      WORK.filter(
        (item) =>
          item.type === safeTab &&
          (item.title.toLowerCase().includes(query.toLowerCase()) ||
            item.meta.toLowerCase().includes(query.toLowerCase())),
      ),
    [query, safeTab],
  );
  const selected = WORK.find((item) => item.id === selectedId && item.type === safeTab) ?? items[0];

  if (viewState !== "ready") {
    return <StatePanel state={viewState} onAction={() => setViewState("ready")} />;
  }

  const toolbar = (
    <>
      <div className="hub-tabs" role="tablist" aria-label="Work type">
        {allowedTabs.map((item) => (
          <button
            type="button"
            role="tab"
            aria-selected={safeTab === item}
            className={safeTab === item ? "is-selected" : ""}
            key={item}
            onClick={() => {
              setTab(item);
              select();
            }}
          >
            {TAB_LABELS[item]}
          </button>
        ))}
      </div>
      <label className="search-control">
        <MagnifyingGlass size={18} />
        <input
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search work"
        />
      </label>
    </>
  );

  const aside = selected ? (
    <div className="detail-inspector">
      <span className="inspector-kicker">Work selected</span>
      {selected.type === "contract" ? <Handshake size={38} weight="thin" /> : <Briefcase size={38} weight="thin" />}
      <h2>{selected.title}</h2>
      <p>{selected.meta}</p>
      <div className="inspector-rule" />
      <dl>
        <div><dt>Status</dt><dd>{selected.status}</dd></div>
        <div><dt>Deadline</dt><dd>{selected.deadline}</dd></div>
        <div><dt>Verified</dt><dd>{selected.progress}%</dd></div>
      </dl>
      <div className="moisture-readout">
        <span>Verified progress</span>
        <div><i style={{ width: selected.progress + "%" }} /></div>
      </div>
      <button type="button" className="inspector-action" onClick={() => select(selected.type, selected.id)}>
        Keep selected
        <CaretRight size={18} />
      </button>
    </div>
  ) : null;

  return (
    <HubScaffold
      eyebrow="Operational commitments"
      title="Work"
      subtitle="Assignments, orders and public contracts in one accountable queue."
      toolbar={toolbar}
      aside={aside}
    >
      <div className="work-list">
        {items.length ? items.map((item) => (
          <button
            type="button"
            className={selected?.id === item.id ? "work-row is-selected" : "work-row"}
            key={item.id}
            onClick={() => select(item.type, item.id)}
          >
            <span className="work-type-icon">
              {item.type === "contract" ? <Handshake size={25} /> : <FileText size={25} />}
            </span>
            <span className="work-identity">
              <strong>{item.title}</strong>
              <small>{item.meta}</small>
            </span>
            <span className="work-status">{item.status}</span>
            <span className="work-deadline"><Clock size={17} /> {item.deadline}</span>
            <span className="row-caret"><CaretRight size={19} /></span>
          </button>
        )) : (
          <div className="inline-empty">No matching work in this queue.</div>
        )}
      </div>
    </HubScaffold>
  );
}
