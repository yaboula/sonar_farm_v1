import {
  CaretRight,
  Clock,
  Drop,
  FileText,
  Package,
  Plant,
} from "@phosphor-icons/react";
import { useNavigate } from "react-router-dom";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { ActionIntent } from "../types";

interface PriorityProps {
  number: number;
  icon: typeof Package;
  title: string;
  primary: string;
  secondary: string;
  tertiary?: string;
  action?: string;
  onAction?: () => void;
}

function PriorityItem({
  number,
  icon: Icon,
  title,
  primary,
  secondary,
  tertiary,
  action,
  onAction,
}: PriorityProps) {
  return (
    <article className="priority-item">
      <span className={number === 1 ? "priority-number is-first" : "priority-number"}>{number}</span>
      <Icon className="priority-icon" size={45} weight="thin" />
      <div className="priority-copy">
        <h3>{title}</h3>
        <strong>{primary}</strong>
        <p>{secondary}</p>
        {tertiary ? <p>{tertiary}</p> : null}
        {action ? (
          <button type="button" onClick={onAction}>
            {action}
            <CaretRight size={18} weight="bold" />
          </button>
        ) : null}
      </div>
    </article>
  );
}

export function TodayView() {
  const navigate = useNavigate();
  const { viewState, dispatchIntent, setViewState } = useHub();

  const go = (intent: ActionIntent) => {
    dispatchIntent(intent);
    navigate("/" + intent.target);
  };

  if (viewState !== "ready") {
    return (
      <div className="today-view today-state-view">
        <div className="today-image" aria-hidden="true" />
        <div className="today-vignette" aria-hidden="true" />
        <StatePanel state={viewState} onAction={() => setViewState("ready")} />
      </div>
    );
  }

  return (
    <section className="today-view">
      <div className="today-image" aria-hidden="true" />
      <div className="today-vignette" aria-hidden="true" />
      <header className="today-intro">
        <h1>Today</h1>
        <p>What needs my attention now?</p>
      </header>

      <article className="assignment-hero">
        <span className="status-pill">
          <Clock size={19} />
          In progress
        </span>
        <div className="assignment-main">
          <Drop className="assignment-icon" size={76} weight="thin" />
          <div className="assignment-copy">
            <h2>Water North Field</h2>
            <p>Tomatoes <span>·</span> Rows 4–8</p>
            <strong><em>3</em> of 8 rows verified</strong>
            <div className="progress-track" aria-label="3 of 8 rows verified">
              <i style={{ width: "37.5%" }} />
            </div>
            <div className="assignment-deadline">
              <Clock size={22} />
              Due today, 18:30
            </div>
          </div>
        </div>
        <div className="related-order">
          <FileText size={24} />
          <span>Buyer Order BO-204</span>
          <i>·</i>
          <span>Today, 21:00</span>
        </div>
        <button
          className="primary-button"
          type="button"
          onClick={() =>
            go({
              id: "continue-assignment",
              target: "work",
              selectionKind: "assignment",
              selectionId: "asg-1048",
            })
          }
        >
          Continue Assignment
          <CaretRight size={27} weight="bold" />
        </button>
      </article>

      <aside className="priority-rail" aria-label="Attention queue">
        <PriorityItem
          number={1}
          icon={Package}
          title="Company Cargo"
          primary="12 Tomato Crates"
          secondary="Deliver to Farm Warehouse"
          tertiary="Owned by Sonar Farm"
          action="View Cargo"
          onAction={() =>
            go({
              id: "view-cargo",
              target: "company",
              selectionKind: "cargo",
              selectionId: "cargo",
            })
          }
        />
        <PriorityItem
          number={2}
          icon={Drop}
          title="Field Attention"
          primary="North Field"
          secondary="Water level low"
          action="View Field"
          onAction={() =>
            go({
              id: "view-field",
              target: "fields",
              selectionKind: "field",
              selectionId: "north-field",
            })
          }
        />
        <PriorityItem
          number={3}
          icon={Plant}
          title="Next Work"
          primary="Harvest Greenhouse 2"
          secondary="Tomorrow, 09:00"
        />
      </aside>
    </section>
  );
}
