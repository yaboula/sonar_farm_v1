import {
  createContext,
  type PropsWithChildren,
  useContext,
  useMemo,
  useReducer,
} from "react";
import { ACTOR_BY_ROLE } from "../data/fixtures";
import { fixtureHubAdapter } from "../adapters/FixtureHubAdapter";
import type {
  FarmRole,
  HubContextModel,
  HubPresence,
  HubSurface,
  NavigationIntent,
  SelectionKind,
  ViewState,
} from "../types";

interface HubStore extends HubContextModel {
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
  | { type: "intent"; intent: NavigationIntent };

const initialState: HubContextModel = {
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

function reducer(state: HubContextModel, action: Action): HubContextModel {
  if (action.type === "role") {
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
    return {
      ...state,
      role: action.value,
      capabilities: fixtureHubAdapter.resolveCapabilities(action.value, state.surface),
      selectedKind: undefined,
      selectedId: undefined,
    };
  }

  if (action.type === "surface") {
    return {
      ...state,
      surface: action.value,
      presence: action.value === "office" ? "office" : "remote",
      capabilities: fixtureHubAdapter.resolveCapabilities(state.role, action.value),
    };
  }

  if (action.type === "presence") return { ...state, presence: action.value };

  if (action.type === "capabilities") return { ...state, capabilitiesRevision: action.revision ?? state.capabilitiesRevision + 1, capabilities: fixtureHubAdapter.resolveCapabilities(state.role, state.surface) };

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
  const value = useMemo<HubStore>(
    () => ({
      ...state,
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
