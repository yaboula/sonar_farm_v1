import {
  createContext,
  type PropsWithChildren,
  useContext,
  useMemo,
  useReducer,
} from "react";
import { capabilitiesFor } from "../data/fixtures";
import type {
  ActionIntent,
  FarmRole,
  HubContextModel,
  HubSurface,
  SelectionKind,
  ViewState,
} from "../types";

interface HubStore extends HubContextModel {
  setRole: (role: FarmRole) => void;
  setSurface: (surface: HubSurface) => void;
  setViewState: (viewState: ViewState) => void;
  select: (kind?: SelectionKind, id?: string) => void;
  dispatchIntent: (intent: ActionIntent) => void;
}

type Action =
  | { type: "role"; value: FarmRole }
  | { type: "surface"; value: HubSurface }
  | { type: "viewState"; value: ViewState }
  | { type: "select"; kind?: SelectionKind; id?: string }
  | { type: "intent"; intent: ActionIntent };

const initialState: HubContextModel = {
  role: "owner",
  surface: "office",
  viewState: "ready",
  capabilities: capabilitiesFor("owner", "office"),
  selectedKind: "assignment",
  selectedId: "asg-1048",
};

function reducer(state: HubContextModel, action: Action): HubContextModel {
  if (action.type === "role") {
    return {
      ...state,
      role: action.value,
      capabilities: capabilitiesFor(action.value, state.surface),
      selectedKind: undefined,
      selectedId: undefined,
    };
  }

  if (action.type === "surface") {
    return {
      ...state,
      surface: action.value,
      capabilities: capabilitiesFor(state.role, action.value),
    };
  }

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
      setSurface: (surface) => dispatch({ type: "surface", value: surface }),
      setViewState: (viewState) => dispatch({ type: "viewState", value: viewState }),
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
