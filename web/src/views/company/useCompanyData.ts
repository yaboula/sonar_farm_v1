import { useCallback, useEffect, useMemo, useState } from "react";
import { fixtureHubAdapter } from "../../adapters/FixtureHubAdapter";
import { useHub } from "../../store/HubContext";
import type { ActionIntent, HubContextModel, HubViewModel, HubViewRequest } from "../../types";

export function useCompanyData<TData>(request: HubViewRequest) {
  const hub = useHub();
  const context = useMemo<HubContextModel>(() => ({ actorId: hub.actorId, role: hub.role, surface: hub.surface, presence: hub.presence, capabilitiesRevision: hub.capabilitiesRevision, viewState: hub.viewState, capabilities: hub.capabilities, selectedId: hub.selectedId, selectedKind: hub.selectedKind }), [hub.actorId, hub.role, hub.surface, hub.presence, hub.capabilitiesRevision, hub.viewState, hub.capabilities, hub.selectedId, hub.selectedKind]);
  const [model, setModel] = useState<HubViewModel<TData> | null>(null);
  const [notice, setNotice] = useState<string>();
  const [pending, setPending] = useState(false);

  const reload = useCallback(async () => {
    setModel(await fixtureHubAdapter.load<TData>(request, context));
  }, [request, context]);

  useEffect(() => {
    let active = true;
    void fixtureHubAdapter.load<TData>(request, context).then((next) => { if (active) setModel(next); });
    return () => { active = false; };
  }, [request, context]);

  const act = useCallback(async (intent: ActionIntent) => {
    setPending(true);
    const result = await fixtureHubAdapter.dispatch(intent, context);
    setPending(false);
    setNotice(result.message);
    if (result.contextUpdate?.role) hub.transitionRole(result.contextUpdate.role);
    else if (result.contextUpdate?.capabilitiesRevision) hub.refreshCapabilities(result.contextUpdate.capabilitiesRevision);
    if (result.changed) await reload();
    return result;
  }, [context, hub, reload]);

  return { hub, context, model, data: model?.data, notice, setNotice, pending, reload, act };
}
