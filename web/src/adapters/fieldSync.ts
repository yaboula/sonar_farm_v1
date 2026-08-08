import type { FieldDelta, FieldDetail, FieldSyncState } from "../types";

export function createFieldSyncState(detail: FieldDetail): FieldSyncState {
  return {
    topologyRevision: detail.topology.topologyRevision,
    sequence: detail.sequence,
    slots: Object.fromEntries(detail.topology.slots.map((slot) => [slot.id, structuredClone(slot)])),
    plans: Object.fromEntries(detail.cropPlans.map((plan) => [plan.id, structuredClone(plan)])),
    resyncRequired: false,
  };
}

export function applyFieldDelta(state: FieldSyncState, delta: FieldDelta): FieldSyncState {
  if (state.resyncRequired) return state;
  if (delta.topologyRevision !== state.topologyRevision) return { ...state, resyncRequired: true };
  if (delta.sequence <= state.sequence) return state;
  if (delta.sequence !== state.sequence + 1 || delta.kind === "invalidate") {
    return { ...state, resyncRequired: true };
  }

  if (delta.kind === "slot_upsert") {
    return { ...state, sequence: delta.sequence, slots: { ...state.slots, [delta.slot.id]: structuredClone(delta.slot) } };
  }
  if (delta.kind === "plan_upsert") {
    return { ...state, sequence: delta.sequence, plans: { ...state.plans, [delta.plan.id]: structuredClone(delta.plan) } };
  }
  const plans = { ...state.plans };
  delete plans[delta.planId];
  return { ...state, sequence: delta.sequence, plans };
}

export function projectFieldDelta(detail: FieldDetail, delta: FieldDelta): FieldDetail {
  if (delta.kind === "invalidate") return detail;
  if (delta.kind === "slot_upsert") {
    return {
      ...detail,
      sequence: delta.sequence,
      topology: {
        ...detail.topology,
        slots: detail.topology.slots.map((slot) => slot.id === delta.slot.id ? structuredClone(delta.slot) : slot),
      },
    };
  }
  if (delta.kind === "plan_upsert") {
    const exists = detail.cropPlans.some((plan) => plan.id === delta.plan.id);
    return {
      ...detail,
      sequence: delta.sequence,
      cropPlans: exists
        ? detail.cropPlans.map((plan) => plan.id === delta.plan.id ? structuredClone(delta.plan) : plan)
        : [structuredClone(delta.plan), ...detail.cropPlans],
    };
  }
  return { ...detail, sequence: delta.sequence, cropPlans: detail.cropPlans.filter((plan) => plan.id !== delta.planId) };
}
