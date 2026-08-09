import { afterEach, describe, expect, it, vi } from "vitest";
import { NuiHubAdapter } from "./NuiHubAdapter";
import type { HubContextModel } from "../types";

const context = { actorId: "citizen", role: "owner", surface: "office", presence: "office", capabilitiesRevision: 1, viewState: "ready", capabilities: { routes: ["supplies", "company"] } } as HubContextModel;

describe("NuiHubAdapter", () => {
  afterEach(() => { vi.unstubAllGlobals(); delete window.GetParentResourceName; });

  it("uses generic bootstrap, load, dispatch and close callbacks", async () => {
    window.GetParentResourceName = () => "sonar_farm";
    const fetchMock = vi.fn(async (url: string) => {
      if (url.endsWith("hub:bootstrap")) return new Response(JSON.stringify({ ok: true, data: context }));
      if (url.endsWith("hub:load")) return new Response(JSON.stringify({ ok: true, data: { request: { kind: "hub", route: "supplies" }, state: "ready", data: { products: [] } } }));
      if (url.endsWith("hub:dispatch")) return new Response(JSON.stringify({ ok: true, changed: true, entityId: "draft" }));
      return new Response(JSON.stringify({ ok: true }));
    });
    vi.stubGlobal("fetch", fetchMock);
    const adapter = new NuiHubAdapter();
    expect((await adapter.bootstrap()).actorId).toBe("citizen");
    expect((await adapter.load({ kind: "hub", route: "supplies" })).state).toBe("ready");
    expect((await adapter.dispatch({ type: "purchase.createDraft", payer: "company", lines: [{ productId: "carrot_seed", quantity: 1 }] })).entityId).toBe("draft");
    await adapter.close();
    expect(fetchMock.mock.calls.map(([url]) => url)).toEqual([
      "https://sonar_farm/hub:bootstrap", "https://sonar_farm/hub:load", "https://sonar_farm/hub:dispatch", "https://sonar_farm/hub:close",
    ]);
  });
});
