import { beforeEach, describe, expect, it } from "vitest";
import { ACTOR_BY_ROLE, capabilitiesFor } from "../data/fixtures";
import type { AssignmentDetail, FarmRole, HubContextModel } from "../types";
import { FixtureHubAdapter } from "./FixtureHubAdapter";

function context(role: FarmRole): HubContextModel {
  return {
    actorId: ACTOR_BY_ROLE[role],
    role,
    surface: "office",
    presence: "office",
    capabilitiesRevision: 1,
    viewState: "ready",
    capabilities: capabilitiesFor(role, "office"),
  };
}

describe("FixtureHubAdapter Assignment Detail", () => {
  let adapter: FixtureHubAdapter;

  beforeEach(() => {
    adapter = new FixtureHubAdapter(0);
  });

  it("filters available actions for Worker and Supervisor", async () => {
    const worker = await adapter.load<AssignmentDetail>(
      { kind: "assignmentDetail", assignmentId: "asg-1048" },
      context("worker"),
    );
    const supervisor = await adapter.load<AssignmentDetail>(
      { kind: "assignmentDetail", assignmentId: "asg-1048" },
      context("supervisor"),
    );

    expect(worker.data?.availableActions).toEqual(["resume"]);
    expect(supervisor.data?.availableActions).toEqual(["reassign", "cancel"]);
  });

  it("keeps verified progress unchanged during a world handoff", async () => {
    const before = await adapter.load<AssignmentDetail>(
      { kind: "assignmentDetail", assignmentId: "asg-1048" },
      context("worker"),
    );
    const result = await adapter.dispatch(
      { type: "assignment.resume", assignmentId: "asg-1048" },
      context("worker"),
    );
    const after = await adapter.load<AssignmentDetail>(
      { kind: "assignmentDetail", assignmentId: "asg-1048" },
      context("worker"),
    );

    expect(result).toMatchObject({ ok: true, changed: false, closeSurface: true });
    expect(after.data?.requirements).toEqual(before.data?.requirements);
    expect(after.data?.status).toBe("in_progress");
  });

  it("rejects Submit when requirements are incomplete", async () => {
    const result = await adapter.dispatch(
      { type: "assignment.submit", assignmentId: "asg-1048" },
      context("worker"),
    );

    expect(result).toEqual({ ok: false, message: "This action is no longer available." });
  });

  it("submits a fully verified Assignment", async () => {
    const result = await adapter.dispatch(
      { type: "assignment.submit", assignmentId: "asg-1061" },
      context("worker"),
    );
    const assignment = await adapter.load<AssignmentDetail>(
      { kind: "assignmentDetail", assignmentId: "asg-1061" },
      context("supervisor"),
    );

    expect(result.ok).toBe(true);
    expect(assignment.data?.status).toBe("awaiting_review");
    expect(assignment.data?.payout.status).toBe("pending_review");
  });

  it("lets Manager and Owner inherit Supervisor review actions", async () => {
    for (const role of ["manager", "owner"] as const) {
      const assignment = await adapter.load<AssignmentDetail>(
        { kind: "assignmentDetail", assignmentId: "asg-1059" },
        context(role),
      );
      expect(assignment.data?.availableActions).toContain("approve");
      expect(assignment.data?.availableActions).toContain("request_correction");
    }
  });

  it("returns Restricted when the current role loses access", async () => {
    const assignment = await adapter.load<AssignmentDetail>(
      { kind: "assignmentDetail", assignmentId: "asg-1048" },
      context("visitor"),
    );

    expect(assignment.state).toBe("restricted");
    expect(assignment.data).toBeNull();
  });
});
