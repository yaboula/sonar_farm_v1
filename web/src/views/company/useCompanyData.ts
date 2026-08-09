import { useCallback, useEffect, useMemo, useState } from "react";
import { useHub } from "../../store/HubContext";
import type { ActionIntent, HubContextModel, HubViewModel, HubViewRequest } from "../../types";

export function useCompanyData<TData>(request: HubViewRequest) {
  const hub = useHub();
  const context = useMemo<HubContextModel>(() => ({ actorId: hub.actorId, role: hub.role, surface: hub.surface, presence: hub.presence, capabilitiesRevision: hub.capabilitiesRevision, viewState: hub.viewState, capabilities: hub.capabilities, selectedId: hub.selectedId, selectedKind: hub.selectedKind }), [hub.actorId, hub.role, hub.surface, hub.presence, hub.capabilitiesRevision, hub.viewState, hub.capabilities, hub.selectedId, hub.selectedKind]);
  const [model, setModel] = useState<HubViewModel<TData> | null>(null);
  const [notice, setNotice] = useState<string>();
  const [pending, setPending] = useState(false);

  const reload = useCallback(async () => {
    setModel(await hub.adapter.load<TData>(request, context));
  }, [request, context, hub.adapter]);

  useEffect(() => {
    let active = true;
    void hub.adapter.load<TData>(request, context).then((next) => { if (active) setModel(next); });
    return () => { active = false; };
  }, [request, context, hub.adapter]);

  const act = useCallback(async (intent: ActionIntent) => {
    setPending(true);
    try {
      const result = await hub.adapter.dispatch(intent, context);
      setNotice(result.message);
      if (result.contextUpdate?.role) hub.transitionRole(result.contextUpdate.role);
      else if (result.contextUpdate?.capabilitiesRevision) hub.refreshCapabilities(result.contextUpdate.capabilitiesRevision);
      if (result.changed) await reload();
      return result;
    } finally {
      setPending(false);
    }
  }, [context, hub, reload]);

  return { hub, context, model, data: model?.data, notice, setNotice, pending, reload, act };
}
