import { describe, expect, it } from "vitest";
import {
  FRONTEND_V1_CANVAS,
  FRONTEND_V1_ESSENTIAL_FLOWS,
  FRONTEND_V1_INTEGRATION_BOUNDARY,
  FRONTEND_V1_PATHS,
  FRONTEND_V1_PRESENCES,
  FRONTEND_V1_ROLES,
  FRONTEND_V1_ROUTE_CATALOG,
  FRONTEND_V1_SURFACES,
  FRONTEND_V1_VERSION,
  FRONTEND_V1_VIEW_STATES,
} from "./frontendV1Contract";

describe("Frontend V1 release contract", () => {
  it("freezes the approved product dimensions and context axes", () => {
    expect(FRONTEND_V1_VERSION).toBe("1.0.0");
    expect(FRONTEND_V1_CANVAS).toEqual({ width: 1440, height: 810 });
    expect(FRONTEND_V1_SURFACES).toEqual(["office", "tablet"]);
    expect(FRONTEND_V1_PRESENCES).toEqual(["remote", "office", "warehouse", "registry"]);
    expect(FRONTEND_V1_ROLES).toHaveLength(7);
    expect(FRONTEND_V1_VIEW_STATES).toContain("restricted");
    expect(FRONTEND_V1_VIEW_STATES).toContain("unavailable");
  });

  it("owns every stable route exactly once", () => {
    const registeredKeys = FRONTEND_V1_ROUTE_CATALOG.map(({ key }) => key);
    const registeredPaths = registeredKeys.map((key) => FRONTEND_V1_PATHS[key]);

    expect(new Set(registeredKeys).size).toBe(Object.keys(FRONTEND_V1_PATHS).length);
    expect(new Set(registeredPaths).size).toBe(registeredPaths.length);
    expect(registeredPaths).toEqual(expect.arrayContaining(["/today", "/fields", "/work", "/supplies", "/company"]));
  });

  it("freezes every essential product journey without defining a transport", () => {
    expect(FRONTEND_V1_ESSENTIAL_FLOWS).toHaveLength(11);
    expect(new Set(FRONTEND_V1_ESSENTIAL_FLOWS).size).toBe(11);
    expect(FRONTEND_V1_INTEGRATION_BOUNDARY).toEqual({
      adapter: "HubAdapter",
      viewRequest: "HubViewRequest",
      actionIntent: "ActionIntent",
      result: "IntentResult",
      transportDefined: false,
      persistenceDefined: false,
    });
  });
});
