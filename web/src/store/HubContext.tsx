import {
  createContext,
  type PropsWithChildren,
  useContext,
  useEffect,
  useMemo,
  useReducer,
} from "react";
import { ACTOR_BY_ROLE } from "../data/fixtures";
import { fixtureHubAdapter } from "../adapters/FixtureHubAdapter";
import { hubAdapter, runtimeIsNui } from "../adapters/hubAdapter";
import { EMPTY_HUB_CAPABILITIES } from "../hubPresentation";
import type {
  FarmRole,
  HubContextModel,
  HubPresence,
  HubSurface,
  NavigationIntent,
  SelectionKind,
  ViewState,
  HubAdapter,
} from "../types";

interface HubStore extends HubContextModel {
  adapter: HubAdapter;
  setRole: (role: FarmRole) => void;
  transitionRole: (role: FarmRole) => void;
  setSurface: (surface: HubSurface) => void;
  setPresence: (presence: HubPresence) => void;
  setViewState: (viewState: ViewState) => void;
  refreshCapabilities: (revision?: number) => void;
  select: (kind?: SelectionKind, id?: string) => void;
  dispatchIntent: (intent: NavigationIntent) => void;
}

type Action =
  | { type: "role"; value: FarmRole }
  | { type: "transitionRole"; value: FarmRole }
  | { type: "surface"; value: HubSurface }
  | { type: "presence"; value: HubPresence }
  | { type: "viewState"; value: ViewState }
  | { type: "capabilities"; revision?: number }
  | { type: "select"; kind?: SelectionKind; id?: string }
  | { type: "intent"; intent: NavigationIntent }
  | { type: "hydrate"; value: HubContextModel };

const previewState: HubContextModel = {
  actorId: ACTOR_BY_ROLE.owner,
  role: "owner",
  surface: "office",
  presence: "office",
  capabilitiesRevision: 1,
  viewState: "ready",
  capabilities: fixtureHubAdapter.resolveCapabilities("owner", "office"),
  selectedKind: "assignment",
  selectedId: "asg-1048",
};

const initialState: HubContextModel = runtimeIsNui
  ? { ...previewState, actorId: "", role: "worker", surface: "tablet", presence: "remote", viewState: "loading",
      capabilities: EMPTY_HUB_CAPABILITIES }
  : previewState;

function reducer(state: HubContextModel, action: Action): HubContextModel {
  if (action.type === "hydrate") return action.value;
  if (action.type === "role") {
    if (runtimeIsNui) return { ...state, role: action.value };
    return {
      ...state,
      role: action.value,
      actorId: ACTOR_BY_ROLE[action.value],
      capabilities: fixtureHubAdapter.resolveCapabilities(action.value, state.surface),
      selectedKind: undefined,
      selectedId: undefined,
    };
  }

  if (action.type === "transitionRole") {
    if (runtimeIsNui) return { ...state, role: action.value };
    return {
      ...state,
      role: action.value,
      capabilities: fixtureHubAdapter.resolveCapabilities(action.value, state.surface),
      selectedKind: undefined,
      selectedId: undefined,
    };
  }

  if (action.type === "surface") {
    if (runtimeIsNui) return state;
    return {
      ...state,
      surface: action.value,
      presence: action.value === "office" ? "office" : "remote",
      capabilities: fixtureHubAdapter.resolveCapabilities(state.role, action.value),
    };
  }

  if (action.type === "presence") return { ...state, presence: action.value };

  if (action.type === "capabilities") return runtimeIsNui
    ? { ...state, capabilitiesRevision: action.revision ?? state.capabilitiesRevision + 1 }
    : { ...state, capabilitiesRevision: action.revision ?? state.capabilitiesRevision + 1, capabilities: fixtureHubAdapter.resolveCapabilities(state.role, state.surface) };

  if (action.type === "viewState") {
    return { ...state, viewState: action.value };
  }

  if (action.type === "intent") {
    return {
      ...state,
      selectedKind: action.intent.selectionKind,
      selectedId: action.intent.selectionId,
    };
  }

  return { ...state, selectedKind: action.kind, selectedId: action.id };
}

const HubContext = createContext<HubStore | null>(null);

export function HubProvider({ children }: PropsWithChildren) {
  const [state, dispatch] = useReducer(reducer, initialState);
  useEffect(() => {
    if (!hubAdapter.bootstrap) return;
    let active = true;
    const hydrate = () => void hubAdapter.bootstrap?.().then((value) => { if (active) dispatch({ type: "hydrate", value }); }).catch(() => undefined);
    const onMessage = (event: MessageEvent) => { if (event.data?.type === "hub:open" && event.data.payload) dispatch({ type: "hydrate", value: event.data.payload }); };
    const onKey = (event: KeyboardEvent) => { if (event.key === "Escape") void hubAdapter.close?.(); };
    hydrate();
    window.addEventListener("message", onMessage);
    window.addEventListener("keydown", onKey);
    return () => { active = false; window.removeEventListener("message", onMessage); window.removeEventListener("keydown", onKey); };
  }, []);
  const value = useMemo<HubStore>(
    () => ({
      ...state,
      adapter: hubAdapter,
      setRole: (role) => dispatch({ type: "role", value: role }),
      transitionRole: (role) => dispatch({ type: "transitionRole", value: role }),
      setSurface: (surface) => dispatch({ type: "surface", value: surface }),
      setPresence: (presence) => dispatch({ type: "presence", value: presence }),
      setViewState: (viewState) => dispatch({ type: "viewState", value: viewState }),
      refreshCapabilities: (revision) => dispatch({ type: "capabilities", revision }),
      select: (kind, id) => dispatch({ type: "select", kind, id }),
      dispatchIntent: (intent) => dispatch({ type: "intent", intent }),
    }),
    [state],
  );

  return <HubContext.Provider value={value}>{children}</HubContext.Provider>;
}

export function useHub() {
  const value = useContext(HubContext);
  if (!value) {
    throw new Error("useHub must be used inside HubProvider");
  }
  return value;
}
