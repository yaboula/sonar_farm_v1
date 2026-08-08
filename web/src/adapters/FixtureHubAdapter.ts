import { cloneAssignmentFixtures } from "../data/assignmentFixtures";
import type {
  ActionIntent,
  AssignmentDetail,
  AvailableAssignmentAction,
  FarmRole,
  HubAdapter,
  HubContextModel,
  HubViewRequest,
  HubViewModel,
  IntentResult,
} from "../types";

const wait = (duration: number) => new Promise((resolve) => setTimeout(resolve, duration));

const MANAGEMENT_ROLES: FarmRole[] = ["supervisor", "manager", "owner"];
const WORKER_ACTIONS: AvailableAssignmentAction[] = ["accept", "resume", "submit"];
const SUPERVISOR_ACTIONS: AvailableAssignmentAction[] = [
  "approve",
  "request_correction",
  "reassign",
  "cancel",
  "resolve_blocker",
];

function canReadAssignment(role: FarmRole, assignment: AssignmentDetail) {
  if (MANAGEMENT_ROLES.includes(role)) return true;
  return role === "worker" && assignment.assignee.id === "staff-noah";
}

function actionsForRole(role: FarmRole, assignment: AssignmentDetail) {
  const allowed = MANAGEMENT_ROLES.includes(role) ? SUPERVISOR_ACTIONS : WORKER_ACTIONS;
  return assignment.availableActions.filter((action) => allowed.includes(action));
}

function addProgress(
  assignment: AssignmentDetail,
  title: string,
  detail: string,
  actor: string,
  tone: "neutral" | "positive" | "warning",
) {
  assignment.progress.unshift({
    id: `evt-${assignment.id}-${Date.now()}`,
    at: "Just now",
    title,
    detail,
    actor,
    tone,
  });
}

export class FixtureHubAdapter implements HubAdapter {
  private assignments = cloneAssignmentFixtures();

  constructor(private readonly delayMs = 80) {}

  reset() {
    this.assignments = cloneAssignmentFixtures();
  }

  async load<TData>(
    request: HubViewRequest,
    context: HubContextModel,
  ): Promise<HubViewModel<TData>> {
    await wait(this.delayMs);

    if (context.viewState !== "ready") {
      return { request, state: context.viewState, data: null };
    }

    if (request.kind === "hub") {
      return { request, state: "ready", data: {} as TData };
    }

    const assignment = this.assignments.find((item) => item.id === request.assignmentId);
    if (!assignment) {
      return { request, state: "ready", data: null };
    }

    if (!canReadAssignment(context.role, assignment)) {
      return { request, state: "restricted", data: null };
    }

    const safeAssignment = structuredClone(assignment);
    safeAssignment.availableActions = actionsForRole(context.role, safeAssignment);
    return { request, state: "ready", data: safeAssignment as TData };
  }

  async dispatch(intent: ActionIntent, context: HubContextModel): Promise<IntentResult> {
    await wait(this.delayMs);
    const assignment = this.assignments.find((item) => item.id === intent.assignmentId);
    if (!assignment || !canReadAssignment(context.role, assignment)) {
      return { ok: false, message: "Assignment is unavailable for this role." };
    }

    const actionName = intent.type.replace("assignment.", "")
      .replace("requestCorrection", "request_correction")
      .replace("resolveBlocker", "resolve_blocker") as AvailableAssignmentAction;
    if (!actionsForRole(context.role, assignment).includes(actionName)) {
      return { ok: false, message: "This action is no longer available." };
    }

    if (intent.type === "assignment.resume") {
      return {
        ok: true,
        changed: false,
        closeSurface: true,
        message: `Return to ${assignment.field.name} · ${assignment.field.scope}`,
      };
    }

    if (intent.type === "assignment.accept") {
      assignment.status = "in_progress";
      assignment.statusLabel = "In Progress";
      assignment.availableActions = ["resume", "reassign", "cancel"];
      addProgress(assignment, "Assignment accepted", "Issued materials are now in worker custody.", assignment.assignee.name, "neutral");
      return { ok: true, changed: true, message: "Assignment accepted." };
    }

    if (intent.type === "assignment.submit") {
      const complete = assignment.requirements.every(
        (item) => item.status === "verified" && item.current >= item.target,
      );
      if (!complete) {
        return { ok: false, message: "Verified requirements are still incomplete." };
      }
      assignment.status = "awaiting_review";
      assignment.statusLabel = "Awaiting Review";
      assignment.payout.status = "pending_review";
      assignment.availableActions = ["approve", "request_correction", "reassign", "cancel"];
      addProgress(assignment, "Submitted for review", "All required results are ready for Supervisor review.", assignment.assignee.name, "positive");
      return { ok: true, changed: true, message: "Assignment submitted for review." };
    }

    if (intent.type === "assignment.approve") {
      assignment.status = "completed";
      assignment.statusLabel = "Completed";
      assignment.payout.status = "released";
      assignment.availableActions = [];
      assignment.reviewerNote = intent.note || "Verified result approved.";
      addProgress(assignment, "Result approved", `Reserved pay of $${assignment.payout.amount} released.`, "Jordan Tate", "positive");
      return { ok: true, changed: true, message: "Result approved and reserved pay released." };
    }

    if (intent.type === "assignment.requestCorrection") {
      if (!intent.note.trim()) return { ok: false, message: "Correction notes are required." };
      assignment.status = "in_progress";
      assignment.statusLabel = "Correction Requested";
      assignment.payout.status = "reserved";
      assignment.reviewerNote = intent.note.trim();
      assignment.availableActions = ["resume", "reassign", "cancel"];
      addProgress(assignment, "Correction requested", intent.note.trim(), "Jordan Tate", "warning");
      return { ok: true, changed: true, message: "Assignment returned with correction notes." };
    }

    if (intent.type === "assignment.resolveBlocker") {
      if (!intent.note.trim()) return { ok: false, message: "Resolution notes are required." };
      assignment.status = "in_progress";
      assignment.statusLabel = "In Progress";
      assignment.blocker = undefined;
      assignment.availableActions = ["resume", "reassign", "cancel"];
      addProgress(assignment, "Blocker resolved", intent.note.trim(), "Jordan Tate", "positive");
      return { ok: true, changed: true, message: "Blocker resolved." };
    }

    if (intent.type === "assignment.reassign") {
      const assignees: Record<string, string> = {
        "staff-noah": "Noah Reed",
        "staff-sofia": "Sofia Bennett",
      };
      const name = assignees[intent.assigneeId];
      if (!name) return { ok: false, message: "Selected worker is unavailable." };
      assignment.assignee = { id: intent.assigneeId, name, role: "Worker" };
      addProgress(assignment, "Assignment reassigned", `Responsibility moved to ${name}.`, "Jordan Tate", "neutral");
      return { ok: true, changed: true, message: `Assignment reassigned to ${name}.` };
    }

    if (!intent.reason.trim()) return { ok: false, message: "Cancellation reason is required." };
    assignment.status = "cancelled";
    assignment.statusLabel = "Cancelled";
    assignment.payout.status = "void";
    assignment.availableActions = [];
    addProgress(assignment, "Assignment cancelled", intent.reason.trim(), "Jordan Tate", "warning");
    return { ok: true, changed: true, message: "Assignment cancelled." };
  }
}

export const fixtureHubAdapter = new FixtureHubAdapter();
