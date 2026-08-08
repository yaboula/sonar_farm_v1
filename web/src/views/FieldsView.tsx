import {
  CaretRight,
  CheckCircle,
  Drop,
  Funnel,
  Leaf,
  MapTrifold,
  Warning,
} from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { HubScaffold } from "../components/HubScaffold";
import { StatePanel } from "../components/StatePanel";
import { FIELDS } from "../data/fixtures";
import { useHub } from "../store/HubContext";

type FieldFilter = "all" | "attention" | "leased";

export function FieldsView() {
  const { viewState, selectedId, select, setViewState } = useHub();
  const [filter, setFilter] = useState<FieldFilter>("all");
  const visibleFields = useMemo(
    () =>
      FIELDS.filter((field) => {
        if (filter === "attention") return ["Needs attention", "Grace period"].includes(field.status);
        if (filter === "leased") return field.lease !== "Company owned";
        return true;
      }),
    [filter],
  );
  const selected = FIELDS.find((field) => field.id === selectedId) ?? visibleFields[0];

  if (viewState !== "ready") {
    return <StatePanel state={viewState} onAction={() => setViewState("ready")} />;
  }

  const toolbar = (
    <div className="segmented-filter" aria-label="Field filter">
      <Funnel size={18} />
      {(["all", "attention", "leased"] as FieldFilter[]).map((item) => (
        <button
          type="button"
          key={item}
          className={filter === item ? "is-selected" : ""}
          onClick={() => setFilter(item)}
        >
          {item === "all" ? "All fields" : item === "attention" ? "Needs attention" : "Leased"}
        </button>
      ))}
    </div>
  );

  const aside = selected ? (
    <div className="detail-inspector">
      <span className="inspector-kicker">Selected field</span>
      <MapTrifold size={38} weight="thin" />
      <h2>{selected.name}</h2>
      <p>{selected.crop} · {selected.detail}</p>
      <div className="inspector-rule" />
      <dl>
        <div><dt>Status</dt><dd>{selected.status}</dd></div>
        <div><dt>Capacity</dt><dd>{selected.capacity}</dd></div>
        <div><dt>Moisture</dt><dd>{selected.moisture}%</dd></div>
        <div><dt>Land</dt><dd>{selected.lease}</dd></div>
      </dl>
      <div className="moisture-readout">
        <span>Soil moisture</span>
        <div><i style={{ width: selected.moisture + "%" }} /></div>
      </div>
      <button type="button" className="inspector-action" onClick={() => select("field", selected.id)}>
        Focus field
        <CaretRight size={18} />
      </button>
    </div>
  ) : null;

  return (
    <HubScaffold
      eyebrow="Land & cultivation"
      title="Fields"
      subtitle="See where the company can operate and what needs a decision."
      toolbar={toolbar}
      aside={aside}
    >
      <div className="field-grid">
        {visibleFields.map((field) => {
          const Icon = field.status === "Healthy" || field.status === "Ready" ? CheckCircle : Warning;
          return (
            <button
              className={selected?.id === field.id ? "field-card is-selected" : "field-card"}
              type="button"
              key={field.id}
              onClick={() => select("field", field.id)}
            >
              <div className="card-topline">
                <span className={"status-dot status-" + field.status.toLowerCase().replace(" ", "-")}>
                  <Icon size={17} />
                  {field.status}
                </span>
                <CaretRight size={18} />
              </div>
              <div className="field-icon"><Leaf size={34} weight="thin" /></div>
              <h2>{field.name}</h2>
              <p>{field.crop}</p>
              <span>{field.detail}</span>
              <div className="field-card-footer">
                <span><Drop size={17} /> {field.moisture}%</span>
                <span>{field.capacity}</span>
              </div>
            </button>
          );
        })}
      </div>
    </HubScaffold>
  );
}
