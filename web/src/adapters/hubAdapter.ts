import type { HubAdapter } from "../types";
import { fixtureHubAdapter } from "./FixtureHubAdapter";
import { isNuiRuntime, NuiHubAdapter } from "./NuiHubAdapter";

export const runtimeIsNui = isNuiRuntime();
export const hubAdapter: HubAdapter = runtimeIsNui ? new NuiHubAdapter() : fixtureHubAdapter;
