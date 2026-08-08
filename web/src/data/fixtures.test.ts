import { describe, expect, it } from "vitest";
import { capabilitiesFor } from "./fixtures";

describe("capabilitiesFor", () => {
  it("keeps private routes away from visitors", () => {
    const capabilities = capabilitiesFor("visitor", "office");
    expect(capabilities.routes).toEqual(["work", "supplies", "company"]);
    expect(capabilities.viewPrivateCompany).toBe(false);
    expect(capabilities.manageStaff).toBe(false);
  });

  it("gives the owner the complete office capability set", () => {
    const capabilities = capabilitiesFor("owner", "office");
    expect(capabilities.routes).toHaveLength(5);
    expect(capabilities.viewFinancials).toBe(true);
    expect(capabilities.manageStaff).toBe(true);
    expect(capabilities.physicalTransactions).toBe(true);
  });

  it("removes physical transactions on the tablet without changing routes", () => {
    const office = capabilitiesFor("owner", "office");
    const tablet = capabilitiesFor("owner", "tablet");
    expect(tablet.routes).toEqual(office.routes);
    expect(tablet.physicalTransactions).toBe(false);
  });
});
