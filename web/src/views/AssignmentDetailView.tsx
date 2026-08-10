import {
  ArrowLeft,
  ArrowSquareOut,
  Briefcase,
  CalendarBlank,
  CaretDown,
  CheckCircle,
  Circle,
  Clock,
  FileText,
  MapPin,
  Package,
  ShieldCheck,
  User,
  Warning,
  X,
} from "@phosphor-icons/react";
import {
  type ReactNode,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";
import { useLocation, useNavigate, useParams } from "react-router-dom";
import { FarmSelect } from "../components/FarmSelect";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type {
  ActionIntent,
  AssignmentDetail,
  AvailableAssignmentAction,
  HubContextModel,
  HubViewModel,
} from "../types";

type DialogKind = "submit" | "review" | "reassign" | "cancel" | "resolve";

const STATUS_TONE: Record<AssignmentDetail["status"], string> = {
  assigned: "neutral",
  accepted: "neutral",
  in_progress: "active",
  blocked: "warning",
  awaiting_review: "review",
  completed: "success",
  failed: "danger",
  expired: "danger",
  cancelled: "muted",
};

function DetailDialog({
  title,
  eyebrow,
  children,
  onClose,
  footer,
}: {
  title: string;
  eyebrow: string;
  children: ReactNode;
  onClose: () => void;
  footer: ReactNode;
}) {
  useEffect(() => {
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [onClose]);

  return (
    <div className="assignment-dialog-layer" role="presentation" onMouseDown={onClose}>
      <section
        className="assignment-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="assignment-dialog-title"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <button className="dialog-close" type="button" onClick={onClose} aria-label="Close dialog">
          <X size={20} />
        </button>
        <span className="dialog-eyebrow">{eyebrow}</span>
        <h2 id="assignment-dialog-title">{title}</h2>
        <div className="dialog-content">{children}</div>
        <footer className="dialog-actions">{footer}</footer>
      </section>
    </div>
  );
}

function FactRow({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="assignment-fact-row">
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  );
}

export function AssignmentDetailView() {
  const { assignmentId = "" } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const hub = useHub();
  const requestContext = useMemo<HubContextModel>(
    () => ({
      actorId: hub.actorId,
      role: hub.role,
      surface: hub.surface,
      presence: hub.presence,
      capabilitiesRevision: hub.capabilitiesRevision,
      viewState: hub.viewState,
      capabilities: hub.capabilities,
      selectedKind: hub.selectedKind,
      selectedId: hub.selectedId,
    }),
    [
      hub.actorId,
      hub.capabilities,
      hub.capabilitiesRevision,
      hub.presence,
      hub.role,
      hub.selectedId,
      hub.selectedKind,
      hub.surface,
      hub.viewState,
    ],
  );
  const [model, setModel] = useState<HubViewModel<AssignmentDetail> | null>(null);
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState<string>();
  const [dialog, setDialog] = useState<DialogKind>();
  const [notes, setNotes] = useState("");
  const [assigneeId, setAssigneeId] = useState("");
  const [controlsOpen, setControlsOpen] = useState(false);
  const [handoff, setHandoff] = useState<{ title: string; detail: string }>();

  const returnTo =
    (location.state as { returnTo?: string } | null)?.returnTo ?? "/work?tab=assignment";

  const reload = useCallback(async () => {
    const next = await hub.adapter.load<AssignmentDetail>(
      { kind: "assignmentDetail", assignmentId },
      requestContext,
    );
    setModel(next);
  }, [assignmentId, requestContext, hub.adapter]);

  useEffect(() => {
    let active = true;
    void hub.adapter
      .load<AssignmentDetail>({ kind: "assignmentDetail", assignmentId }, requestContext)
      .then((next) => {
        if (active) setModel(next);
      });
    return () => {
      active = false;
    };
  }, [assignmentId, requestContext, hub.adapter]);

  const assignment = model?.data;
  const eligibleAssignees = assignment?.eligibleAssignees ?? (assignment ? [assignment.assignee] : []);
  const selectedAssigneeId = assigneeId || assignment?.assignee.id || "";
  const totals = useMemo(() => {
    if (!assignment) return { current: 0, target: 0, percent: 0 };
    const current = assignment.requirements.reduce(
      (sum, requirement) => sum + Math.min(requirement.current, requirement.target),
      0,
    );
    const target = assignment.requirements.reduce((sum, requirement) => sum + requirement.target, 0);
    return { current, target, percent: target ? Math.round((current / target) * 100) : 0 };
  }, [assignment]);

  const hasAction = (action: AvailableAssignmentAction) =>
    Boolean(assignment?.availableActions.includes(action));

  const send = async (intent: ActionIntent) => {
    setPending(true);
    setNotice(undefined);
    const result = await hub.adapter.dispatch(intent, requestContext);
    setPending(false);

    if (!result.ok) {
      setNotice(result.message ?? "The assignment could not be updated.");
      return false;
    }

    if (result.closeSurface && assignment) {
      setHandoff({
        title: `${assignment.field.name} · ${assignment.field.scope}`,
        detail: result.message ?? "Return to the assigned work area.",
      });
    }

    setNotice(result.message);
    if (result.changed) await reload();
    return true;
  };

  const closeDialog = useCallback(() => {
    setDialog(undefined);
    setNotes("");
  }, []);

  const completeDialogAction = async (intent: ActionIntent) => {
    const success = await send(intent);
    if (success) closeDialog();
  };

  if (!model) {
    return <StatePanel state="loading" />;
  }

  if (model.state !== "ready") {
    return <StatePanel state={model.state} onAction={() => navigate(returnTo)} />;
  }

  if (!assignment) {
    return (
      <section className="assignment-detail-view assignment-detail-state">
        <div className="detail-backdrop" aria-hidden="true" />
        <div className="assignment-missing">
          <FileText size={56} weight="thin" />
          <span>Assignment unavailable</span>
          <h1>Record not found</h1>
          <p>The requested Assignment no longer exists or its identifier has changed.</p>
          <button type="button" className="secondary-button" onClick={() => navigate(returnTo)}>
            <ArrowLeft size={18} /> Back to Assignments
          </button>
        </div>
      </section>
    );
  }

  const workerPrimary = () => {
    if (hasAction("accept")) {
      return { label: "Accept Assignment", action: () => send({ type: "assignment.accept", assignmentId }) };
    }
    if (hasAction("resume")) {
      return { label: "Resume Field Work", action: () => send({ type: "assignment.resume", assignmentId }) };
    }
    if (hasAction("submit")) {
      return { label: "Submit for Review", action: () => setDialog("submit") };
    }
    if (hasAction("resolve_blocker")) {
      return { label: "Resolve Blocker", action: () => setDialog("resolve") };
    }
    if (hasAction("approve") || hasAction("request_correction")) {
      return { label: "Review Result", action: () => setDialog("review") };
    }
    return undefined;
  };
  const primaryAction = workerPrimary();
  const managementControls = hasAction("reassign") || hasAction("cancel");

  if (handoff) {
    return (
      <section className="assignment-handoff" aria-live="polite">
        <div className="handoff-pulse"><ArrowSquareOut size={42} /></div>
        <span>World handoff</span>
        <h1>Returning to field work</h1>
        <strong>{handoff.title}</strong>
        <p>{handoff.detail}</p>
        <small>Verified progress remains {totals.current} of {totals.target}.</small>
        {import.meta.env.DEV ? (
          <button type="button" className="secondary-button" onClick={() => setHandoff(undefined)}>
            Return to Hub preview
          </button>
        ) : null}
      </section>
    );
  }

  return (
    <section className="assignment-detail-view">
      <div className="detail-backdrop" aria-hidden="true" />

      <div className="assignment-detail-topbar">
        <button type="button" onClick={() => navigate(returnTo)}>
          <ArrowLeft size={18} /> Back to Assignments
        </button>
        <nav aria-label="Breadcrumb">
          <span>Work</span><i>/</i><span>Assignments</span><i>/</i><strong>{assignment.reference}</strong>
        </nav>
      </div>

      <header className="assignment-detail-header">
        <div className="assignment-title-block">
          <span className={`assignment-status assignment-status--${STATUS_TONE[assignment.status]}`}>
            <Clock size={17} /> {assignment.statusLabel}
          </span>
          <div className="assignment-reference">{assignment.reference} · {assignment.workType}</div>
          <h1>{assignment.title}</h1>
          <p>{assignment.objective}</p>
        </div>
        <div className="assignment-header-facts">
          <div><CalendarBlank size={22} /><span>Deadline<strong>{assignment.deadline}</strong></span></div>
          <div><MapPin size={22} /><span>Work area<strong>{assignment.field.name} · {assignment.field.scope}</strong></span></div>
          <div><User size={22} /><span>Assigned to<strong>{assignment.assignee.name}</strong></span></div>
        </div>
      </header>

      <div className="assignment-detail-scroll">
        <main className="assignment-detail-main">
          {assignment.blocker ? (
            <section className="assignment-blocker">
              <Warning size={26} weight="fill" />
              <div><span>Active blocker · {assignment.blocker.raisedAt}</span><h2>{assignment.blocker.title}</h2><p>{assignment.blocker.detail}</p></div>
            </section>
          ) : null}

          {assignment.reviewerNote ? (
            <section className="assignment-review-note">
              <FileText size={23} />
              <div><span>Supervisor note</span><p>{assignment.reviewerNote}</p></div>
            </section>
          ) : null}

          <section className="assignment-section requirements-section">
            <div className="assignment-section-heading">
              <div><span>Verified objective</span><h2>Work requirements</h2></div>
              <strong>{totals.current} / {totals.target}</strong>
            </div>
            <div className="assignment-progress-track" aria-label={`${totals.percent}% verified`}>
              <i style={{ width: `${totals.percent}%` }} />
            </div>
            <div className="requirement-list">
              {assignment.requirements.map((requirement) => (
                <article key={requirement.id} className={`requirement-row requirement-row--${requirement.status}`}>
                  {requirement.status === "verified" ? <CheckCircle size={24} weight="fill" /> : <Circle size={24} />}
                  <div><h3>{requirement.label}</h3><p>{requirement.detail}</p></div>
                  <strong>{requirement.current} / {requirement.target} {requirement.unit}</strong>
                  <small>{requirement.lastVerifiedAt ?? "Waiting for farm verification"}</small>
                </article>
              ))}
            </div>
          </section>

          <section className="assignment-section progress-history">
            <div className="assignment-section-heading"><div><span>Audit trail</span><h2>Progress history</h2></div></div>
            <div className="progress-event-list">
              {assignment.progress.map((event) => (
                <article key={event.id} className={`progress-event progress-event--${event.tone}`}>
                  <time>{event.at}</time><i />
                  <div><h3>{event.title}</h3><p>{event.detail}</p><span>{event.actor}</span></div>
                </article>
              ))}
            </div>
          </section>
        </main>

        <aside className="assignment-detail-aside">
          <section className="assignment-side-card">
            <span className="side-card-kicker"><Briefcase size={18} /> Assignment terms</span>
            <dl>
              <FactRow label="Assignee" value={assignment.assignee.name} />
              <FactRow label="Supervisor" value={assignment.supervisor.name} />
              <FactRow label="Crop" value={assignment.crop} />
              <FactRow label="Route" value={assignment.field.routeLabel} />
            </dl>
          </section>

          <section className="assignment-side-card payout-card">
            <span className="side-card-kicker"><ShieldCheck size={18} /> Reserved pay</span>
            <div className="payout-value">${assignment.payout.amount}</div>
            <strong>{assignment.payout.status.replace("_", " ")}</strong>
            <ul>{assignment.payout.conditions.map((condition) => <li key={condition}>{condition}</li>)}</ul>
          </section>

          <section className="assignment-side-card materials-card">
            <span className="side-card-kicker"><Package size={18} /> Issued materials</span>
            {assignment.issuedMaterials.length ? assignment.issuedMaterials.map((material) => (
              <article key={material.id}>
                <Package size={25} weight="thin" />
                <div><h3>{material.name}</h3><p>{material.quantity} · {material.ownership}</p></div>
                <span className={`material-status material-status--${material.status}`}>{material.status}</span>
              </article>
            )) : <p className="no-materials">No company materials were issued.</p>}
          </section>

          <section className="assignment-cancellation-copy">
            <span>Cancellation terms</span><p>{assignment.cancellationSummary}</p>
          </section>
        </aside>
      </div>

      <footer className="assignment-action-bar">
        <div className="assignment-action-summary">
          <span>{assignment.status === "awaiting_review" ? "Result ready for decision" : `${totals.percent}% verified`}</span>
          <p>{notice ?? (assignment.availableActions.length ? "Actions are validated against the current role and Assignment state." : "This Assignment is read-only in its current state.")}</p>
        </div>
        {managementControls ? (
          <div className="assignment-controls">
            <button type="button" className="assignment-controls-button" onClick={() => setControlsOpen((value) => !value)} aria-expanded={controlsOpen}>
              Assignment Controls <CaretDown size={17} />
            </button>
            {controlsOpen ? (
              <div className="assignment-controls-menu">
                {hasAction("reassign") ? <button type="button" onClick={() => { setControlsOpen(false); setDialog("reassign"); }}>Reassign Worker</button> : null}
                {hasAction("cancel") ? <button type="button" className="danger" onClick={() => { setControlsOpen(false); setDialog("cancel"); }}>Cancel Assignment</button> : null}
              </div>
            ) : null}
          </div>
        ) : null}
        {primaryAction ? (
          <button type="button" className="assignment-primary-action" onClick={primaryAction.action} disabled={pending}>
            {pending ? "Updating..." : primaryAction.label}<ArrowSquareOut size={21} />
          </button>
        ) : (
          <span className="assignment-final-state">{assignment.statusLabel}</span>
        )}
      </footer>

      {dialog === "submit" ? (
        <DetailDialog
          eyebrow="Worker submission"
          title="Submit verified result?"
          onClose={closeDialog}
          footer={<><button type="button" onClick={closeDialog}>Keep working</button><button type="button" className="confirm" disabled={pending} onClick={() => completeDialogAction({ type: "assignment.submit", assignmentId })}>Submit for Review</button></>}
        >
          <p>The Supervisor will review {totals.current} verified requirements. Reserved pay remains held until approval.</p>
          <div className="dialog-callout"><CheckCircle size={22} /> All requirements are verified by the farm service.</div>
        </DetailDialog>
      ) : null}

      {dialog === "review" ? (
        <DetailDialog
          eyebrow="Supervisor review"
          title="Review Assignment Result"
          onClose={closeDialog}
          footer={<><button type="button" disabled={pending || !notes.trim()} onClick={() => completeDialogAction({ type: "assignment.requestCorrection", assignmentId, note: notes })}>Request Correction</button><button type="button" className="confirm" disabled={pending} onClick={() => completeDialogAction({ type: "assignment.approve", assignmentId, note: notes })}>Approve Result</button></>}
        >
          <p>Approval releases ${assignment.payout.amount} reserved pay. Requesting correction returns the Assignment without altering verified progress.</p>
          <label className="dialog-field"><span>Supervisor note</span><textarea autoFocus value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Required for correction; optional for approval" /></label>
        </DetailDialog>
      ) : null}

      {dialog === "reassign" ? (
        <DetailDialog
          eyebrow="Assignment controls"
          title="Reassign this work?"
          onClose={closeDialog}
          footer={<><button type="button" onClick={closeDialog}>Keep assignee</button><button type="button" className="confirm" disabled={pending || selectedAssigneeId === assignment.assignee.id} onClick={() => completeDialogAction({ type: "assignment.reassign", assignmentId, assigneeId: selectedAssigneeId })}>Confirm Reassignment</button></>}
        >
          <p>Verified progress, deadline and reserved pay stay attached to the Assignment.</p>
          <FarmSelect
            autoFocus
            className="dialog-field"
            label="Eligible Worker"
            value={selectedAssigneeId}
            options={eligibleAssignees.map((worker) => ({ value: worker.id, label: worker.name }))}
            onChange={setAssigneeId}
          />
        </DetailDialog>
      ) : null}

      {dialog === "cancel" ? (
        <DetailDialog
          eyebrow="Destructive control"
          title="Cancel Assignment?"
          onClose={closeDialog}
          footer={<><button type="button" onClick={closeDialog}>Keep Assignment</button><button type="button" className="danger-confirm" disabled={pending || !notes.trim()} onClick={() => completeDialogAction({ type: "assignment.cancel", assignmentId, reason: notes })}>Cancel Assignment</button></>}
        >
          <p>{assignment.cancellationSummary}</p>
          <label className="dialog-field"><span>Cancellation reason</span><textarea autoFocus value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Explain why this work cannot continue" /></label>
        </DetailDialog>
      ) : null}

      {dialog === "resolve" ? (
        <DetailDialog
          eyebrow="Supervisor control"
          title="Resolve active blocker"
          onClose={closeDialog}
          footer={<><button type="button" onClick={closeDialog}>Leave Blocked</button><button type="button" className="confirm" disabled={pending || !notes.trim()} onClick={() => completeDialogAction({ type: "assignment.resolveBlocker", assignmentId, note: notes })}>Resolve Blocker</button></>}
        >
          <p>Record what changed so the Worker can safely resume field work.</p>
          <label className="dialog-field"><span>Resolution note</span><textarea autoFocus value={notes} onChange={(event) => setNotes(event.target.value)} placeholder="Example: Six plant ties issued from warehouse stock" /></label>
        </DetailDialog>
      ) : null}
    </section>
  );
}
