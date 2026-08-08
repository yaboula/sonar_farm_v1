import type {
  ActionIntent,
  HubAdapter,
  HubContextModel,
  HubRoute,
  HubViewModel,
  IntentResult,
} from "../types";

const wait = (duration: number) => new Promise((resolve) => window.setTimeout(resolve, duration));

export class FixtureHubAdapter implements HubAdapter {
  async load<TData>(route: HubRoute, context: HubContextModel): Promise<HubViewModel<TData>> {
    await wait(80);
    return {
      route,
      state: context.viewState,
      data: {} as TData,
    };
  }

  async dispatch(_intent: ActionIntent, _context: HubContextModel): Promise<IntentResult> {
    await wait(90);
    return { ok: true };
  }
}

export const fixtureHubAdapter = new FixtureHubAdapter();
