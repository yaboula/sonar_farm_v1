import {
  ArrowClockwise,
  CircleNotch,
  LockKey,
  Tray,
  WarningCircle,
  WifiSlash,
} from "@phosphor-icons/react";
import type { ViewState } from "../types";

const COPY: Record<
  Exclude<ViewState, "ready">,
  { title: string; body: string; action?: string; icon: typeof CircleNotch }
> = {
  loading: {
    title: "Loading farm data…",
    body: "Checking current priorities and company records.",
    icon: CircleNotch,
  },
  empty: {
    title: "Nothing to show",
    body: "There are no records available for this view right now.",
    action: "Return to ready view",
    icon: Tray,
  },
  blocked: {
    title: "Action temporarily blocked",
    body: "Finish the current farm action before starting another one.",
    action: "Check current work",
    icon: LockKey,
  },
  error: {
    title: "Farm data could not load",
    body: "We couldn't load the latest records for this view.",
    action: "Try again",
    icon: WarningCircle,
  },
  restricted: {
    title: "Access restricted",
    body: "This view is not available for the current role.",
    action: "Return to company",
    icon: LockKey,
  },
  unavailable: {
    title: "Farm service is unavailable",
    body: "No changes were submitted. Try again when service returns.",
    action: "Try again",
    icon: WifiSlash,
  },
};

interface StatePanelProps {
  state: Exclude<ViewState, "ready">;
  onAction?: () => void;
}

export function StatePanel({ state, onAction }: StatePanelProps) {
  const content = COPY[state];
  const Icon = content.icon;
  return (
    <section className={"state-panel state-panel--" + state} role={state === "error" ? "alert" : undefined}>
      <Icon className={state === "loading" ? "spin" : ""} size={62} weight="thin" />
      <span className="state-kicker">{state}</span>
      <h1>{content.title}</h1>
      <p>{content.body}</p>
      {content.action ? (
        <button type="button" className="secondary-button" onClick={onAction}>
          {content.action}
          <ArrowClockwise size={18} />
        </button>
      ) : null}
      {state === "loading" ? (
        <div className="skeleton-stack" aria-hidden="true">
          <i />
          <i />
          <i />
        </div>
      ) : null}
    </section>
  );
}
