import type {
  ActionIntent,
  FieldDeltaListener,
  HubAdapter,
  HubContextModel,
  HubViewModel,
  HubViewRequest,
  IntentResult,
} from "../types";

declare global {
  interface Window { GetParentResourceName?: () => string }
}

type NuiResponse<T> = { ok: boolean; data?: T; reason?: string; message?: string };

export function isNuiRuntime() {
  try { return typeof window.GetParentResourceName === "function" || typeof window.parent?.GetParentResourceName === "function"; } catch { return false; }
}

export class NuiHubAdapter implements HubAdapter {
  private readonly resource = window.GetParentResourceName?.() ?? window.parent?.GetParentResourceName?.() ?? "sonar_farm";

  private async request<T>(name: string, payload: unknown): Promise<T> {
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), 8000);
    try {
      const response = await fetch(`https://${this.resource}/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      if (!response.ok) throw new Error(`NUI ${name} returned HTTP ${response.status}`);
      const result = await response.json() as NuiResponse<T>;
      if (!result.ok) throw new Error(result.message ?? result.reason ?? `NUI ${name} failed`);
      return result.data as T;
    } finally {
      window.clearTimeout(timer);
    }
  }

  bootstrap() { return this.request<HubContextModel>("hub:bootstrap", {}); }

  load<TData>(request: HubViewRequest): Promise<HubViewModel<TData>> {
    return this.request<HubViewModel<TData>>("hub:load", { request });
  }

  async dispatch(intent: ActionIntent): Promise<IntentResult> {
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), 8000);
    try {
      const response = await fetch(`https://${this.resource}/hub:dispatch`, {
        method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ intent }), signal: controller.signal,
      });
      if (!response.ok) return { ok: false, message: `NUI dispatch returned HTTP ${response.status}` };
      return response.json() as Promise<IntentResult>;
    } finally {
      window.clearTimeout(timer);
    }
  }

  subscribeField(_fieldId: string, _afterSequence: number, _context: HubContextModel, _listener: FieldDeltaListener) {
    return () => undefined;
  }

  async close() { await this.request<unknown>("hub:close", {}); }
}
