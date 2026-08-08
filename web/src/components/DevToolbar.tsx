import { Desktop, DeviceTablet } from "@phosphor-icons/react";
import { useHub } from "../store/HubContext";
import type { FarmRole, ViewState } from "../types";

const ROLES: FarmRole[] = [
  "owner",
  "manager",
  "supervisor",
  "procurement",
  "worker",
  "contractor",
  "visitor",
];

const STATES: ViewState[] = [
  "ready",
  "loading",
  "empty",
  "blocked",
  "error",
  "restricted",
  "unavailable",
];

export function DevToolbar() {
  const { role, surface, viewState, setRole, setSurface, setViewState } = useHub();

  return (
    <aside className="dev-toolbar" aria-label="Preview controls">
      <span className="dev-label">Preview</span>
      <div className="surface-toggle">
        <button
          type="button"
          className={surface === "office" ? "is-selected" : ""}
          onClick={() => setSurface("office")}
          aria-label="Office Terminal"
        >
          <Desktop size={16} />
        </button>
        <button
          type="button"
          className={surface === "tablet" ? "is-selected" : ""}
          onClick={() => setSurface("tablet")}
          aria-label="Farm Tablet"
        >
          <DeviceTablet size={16} />
        </button>
      </div>
      <select
        aria-label="Preview role"
        value={role}
        onChange={(event) => setRole(event.target.value as FarmRole)}
      >
        {ROLES.map((item) => (
          <option key={item} value={item}>
            {item}
          </option>
        ))}
      </select>
      <select
        aria-label="Preview state"
        value={viewState}
        onChange={(event) => setViewState(event.target.value as ViewState)}
      >
        {STATES.map((item) => (
          <option key={item} value={item}>
            {item}
          </option>
        ))}
      </select>
    </aside>
  );
}
