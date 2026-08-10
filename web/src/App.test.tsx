import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it } from "vitest";
import { App } from "./App";
import { fixtureHubAdapter } from "./adapters/FixtureHubAdapter";
import { HubProvider } from "./store/HubContext";

function renderApp(path = "/today") {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <HubProvider>
        <App />
      </HubProvider>
    </MemoryRouter>,
  );
}

describe("Farm Business Hub", () => {
  beforeEach(() => fixtureHubAdapter.reset());

  it("renders the master Today assignment", () => {
    renderApp();
    expect(screen.getByRole("heading", { name: "Today" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Water North Field" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /resume field work/i })).toBeInTheDocument();
  });

  it("routes the current assignment into Assignment Detail", async () => {
    const user = userEvent.setup();
    renderApp();
    await user.click(screen.getByRole("button", { name: /resume field work/i }));
    expect(await screen.findByRole("heading", { name: "Water North Field" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /back to assignments/i })).toBeInTheDocument();
  });

  it("switches surface without replacing the app content", async () => {
    const user = userEvent.setup();
    renderApp();
    await user.click(screen.getByRole("button", { name: "Farm Tablet" }));
    expect(screen.getByText("Farm Tablet")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Water North Field" })).toBeInTheDocument();
  });

  it("keeps every owner hub navigable", async () => {
    const user = userEvent.setup();
    renderApp();

    for (const label of ["Fields", "Work", "Supplies", "Company", "Today"]) {
      await user.click(screen.getByRole("link", { name: label }));
      expect(await screen.findByRole("heading", { name: label })).toBeInTheDocument();
    }
  });

  it("opens the selected Field without losing the Fields return path", async () => {
    const user = userEvent.setup();
    renderApp("/fields");
    expect(await screen.findByText(/two fields require a decision/i)).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /north field/i }));
    await user.click(screen.getByRole("button", { name: /open field map/i }));
    expect(await screen.findByRole("heading", { level: 1, name: "North Field" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /back to fields/i })).toBeInTheDocument();
  });

  it("reserves a Row Crop Plan and opens a prefilled Assignment", async () => {
    const user = userEvent.setup();
    renderApp("/fields/north-field?row=north-r12");
    await user.click(await screen.findByRole("button", { name: "Crop Plan" }));
    const dialog = screen.getByRole("dialog", { name: "Reserve this Crop Plan?" });
    expect(within(dialog).getByRole("button", { name: /Row 12.*8 empty slots/i })).toHaveAttribute("aria-pressed", "true");
    await user.click(within(dialog).getByRole("button", { name: "Reserve Crop Plan" }));
    await user.click(await screen.findByRole("button", { name: "Create Assignment" }));
    expect(await screen.findByRole("heading", { name: "Create Assignment" })).toBeInTheDocument();
    expect(screen.getByDisplayValue("Establish Tomatoes · Row 12")).toBeInTheDocument();
    expect(screen.getAllByText("Row 12").length).toBeGreaterThan(0);
  });

  it("reopens an unlinked reserved Crop Plan for editing", async () => {
    const user = userEvent.setup();
    renderApp("/fields/north-field?row=north-r12");
    await user.click(await screen.findByRole("button", { name: "Crop Plan" }));
    await user.click(within(screen.getByRole("dialog")).getByRole("button", { name: "Reserve Crop Plan" }));
    await user.click(await screen.findByRole("button", { name: "Edit Plan" }));
    expect(screen.getByRole("dialog", { name: "Update CP-205?" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Update Crop Plan" })).toBeEnabled();
  });

  it("restores Field layer and Row after a linked Work detour", async () => {
    const user = userEvent.setup();
    renderApp("/fields/greenhouse-2?row=green-ra&layer=readiness&panel=work");
    expect(await screen.findByRole("tab", { name: "Readiness" })).toHaveAttribute("aria-selected", "true");
    expect(screen.queryByRole("button", { name: /zoom/i })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Open Work" }));
    expect(await screen.findByRole("heading", { name: "Harvest Greenhouse 2" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Back to Assignments" }));
    expect(await screen.findByRole("heading", { level: 1, name: "Greenhouse 2" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "Readiness" })).toHaveAttribute("aria-selected", "true");
    expect(screen.getByRole("heading", { level: 2, name: "Row A" })).toBeInTheDocument();
  });

  it("shows an explicit Field not found state for unknown stable identity", async () => {
    renderApp("/fields/unknown-field");
    expect(await screen.findByRole("heading", { name: "Field not found" })).toBeInTheDocument();
    expect(screen.getByText(/not part of the authorized company portfolio/i)).toBeInTheDocument();
  });

  it("blocks Crop Planning while a Lease is in Grace Period", async () => {
    renderApp("/fields/orchard-annex");
    expect(await screen.findByRole("heading", { level: 1, name: "Orchard Annex" })).toBeInTheDocument();
    expect(screen.getByText("Lease Grace Period")).toBeInTheDocument();
    expect(screen.getByText(/planting is suspended/i)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Crop Plan" })).not.toBeInTheDocument();
  });

  it("redirects when a live role change removes the active route", async () => {
    const user = userEvent.setup();
    renderApp("/today");

    await user.selectOptions(screen.getByLabelText("Preview role"), "visitor");

    expect(await screen.findByRole("heading", { name: "Work" })).toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Today" })).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Fields" })).not.toBeInTheDocument();
  });

  it("renders the blocked operational state", async () => {
    const user = userEvent.setup();
    renderApp();

    await user.selectOptions(screen.getByLabelText("Preview state"), "blocked");

    expect(
      screen.getByRole("heading", { name: "Action temporarily blocked" }),
    ).toBeInTheDocument();
  });

  it("accepts an assigned worker Assignment", async () => {
    const user = userEvent.setup();
    renderApp("/work/assignments/asg-1052");
    await user.selectOptions(screen.getByLabelText("Preview role"), "worker");

    const accept = await screen.findByRole("button", { name: "Accept Assignment" });
    await user.click(accept);

    expect(await screen.findByRole("button", { name: "Resume Field Work" })).toBeInTheDocument();
    expect(screen.getByText("Assignment accepted.")).toBeInTheDocument();
  });

  it("hands Resume Field Work to the world without changing verified progress", async () => {
    const user = userEvent.setup();
    renderApp("/work/assignments/asg-1048");
    await user.selectOptions(screen.getByLabelText("Preview role"), "worker");

    await user.click(await screen.findByRole("button", { name: "Resume Field Work" }));

    expect(await screen.findByRole("heading", { name: "Returning to field work" })).toBeInTheDocument();
    expect(screen.getByText("Verified progress remains 3 of 8.")).toBeInTheDocument();
  });

  it("submits a fully verified Assignment for Supervisor review", async () => {
    const user = userEvent.setup();
    renderApp("/work/assignments/asg-1061");
    await user.selectOptions(screen.getByLabelText("Preview role"), "worker");

    await user.click(await screen.findByRole("button", { name: "Submit for Review" }));
    expect(screen.getByRole("dialog", { name: "Submit verified result?" })).toBeInTheDocument();
    await user.click(within(screen.getByRole("dialog")).getByRole("button", { name: "Submit for Review" }));

    expect(await screen.findByText("Assignment submitted for review.")).toBeInTheDocument();
    expect((await screen.findAllByText("Awaiting Review")).length).toBeGreaterThan(0);
  });

  it("lets a Supervisor approve a verified result", async () => {
    const user = userEvent.setup();
    renderApp("/work/assignments/asg-1059");
    await user.selectOptions(screen.getByLabelText("Preview role"), "supervisor");

    await user.click(await screen.findByRole("button", { name: "Review Result" }));
    await user.click(screen.getByRole("button", { name: "Approve Result" }));

    expect(await screen.findByText("Result approved and reserved pay released.")).toBeInTheDocument();
    expect((await screen.findAllByText("Completed")).length).toBeGreaterThan(0);
  });

  it("closes confirmation dialogs with Escape", async () => {
    const user = userEvent.setup();
    renderApp("/work/assignments/asg-1059");
    await user.selectOptions(screen.getByLabelText("Preview role"), "supervisor");

    await user.click(await screen.findByRole("button", { name: "Review Result" }));
    expect(screen.getByRole("dialog", { name: /Review Assignment result/i })).toBeInTheDocument();

    await user.keyboard("{Escape}");
    expect(screen.queryByRole("dialog", { name: /Review Assignment result/i })).not.toBeInTheDocument();
  });

  it("reassigns through the reusable keyboard-select control", async () => {
    const user = userEvent.setup();
    renderApp("/work/assignments/asg-1048");

    await user.click(await screen.findByRole("button", { name: "Assignment Controls" }));
    await user.click(screen.getByRole("button", { name: "Reassign Worker" }));

    const workerSelect = screen.getByRole("combobox", { name: "Eligible Worker" });
    await user.click(workerSelect);
    expect(screen.getByRole("option", { name: "Noah Reed" })).toHaveAttribute("aria-selected", "true");

    await user.keyboard("{ArrowDown}{Enter}");
    expect(workerSelect).toHaveTextContent("Sofia Bennett");
    await user.click(screen.getByRole("button", { name: "Confirm Reassignment" }));

    expect(await screen.findByText("Assignment reassigned to Sofia Bennett.")).toBeInTheDocument();
    expect(screen.getAllByText("Sofia Bennett").length).toBeGreaterThan(0);
  });

  it("shows Restricted after live permission loss", async () => {
    const user = userEvent.setup();
    renderApp("/work/assignments/asg-1048");
    expect(await screen.findByRole("heading", { name: "Water North Field" })).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText("Preview role"), "visitor");

    expect(await screen.findByRole("heading", { name: "Access restricted" })).toBeInTheDocument();
  });

  it("removes unauthorized Work areas for a Visitor", async () => {
    const user = userEvent.setup();
    renderApp("/work");
    await user.selectOptions(screen.getByLabelText("Preview role"), "visitor");
    expect(await screen.findByRole("tab", { name: "Public Contracts" })).toBeInTheDocument();
    expect(screen.queryByRole("tab", { name: "Assignments" })).not.toBeInTheDocument();
    expect(screen.queryByRole("tab", { name: "Buyer Orders" })).not.toBeInTheDocument();
  });

  it("opens a real Buyer Order Detail from Work", async () => {
    const user = userEvent.setup();
    renderApp("/work?area=buyerOrders");
    expect(await screen.findByRole("tab", { name: "Buyer Orders" })).toHaveAttribute("aria-selected", "true");
    await user.click(screen.getByRole("button", { name: "Open Buyer Order" }));
    expect(await screen.findByRole("heading", { name: /BO-204 · County Produce Depot/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Prepare Delivery" })).toBeInTheDocument();
  });

  it("preserves a purchase draft while Tablet blocks physical confirmation", async () => {
    const user = userEvent.setup();
    renderApp("/supplies");
    await user.click(await screen.findByRole("button", { name: "Add Tomato Seedling" }));
    await user.click(screen.getByRole("button", { name: "Review Purchase" }));
    expect(await screen.findByRole("heading", { name: "Purchase Review" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Farm Tablet" }));
    await user.click(screen.getByRole("button", { name: "Complete at Office Terminal" }));
    expect(screen.getByRole("heading", { name: "Complete at Office Terminal" })).toBeInTheDocument();
    expect(screen.getByText(/No funds or stock changed/)).toBeInTheDocument();
  });

  it("keeps future Supplies areas disabled and uses Company Treasury without a selector", async () => {
    const user = userEvent.setup();
    renderApp("/supplies?area=procurement");

    expect(await screen.findByRole("heading", { name: "Supplies" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: /Company Procurement.*Coming Soon/i })).toBeDisabled();
    expect(screen.getByRole("tab", { name: /Issued Materials.*Coming Soon/i })).toBeDisabled();
    expect(screen.getByText("Company Treasury")).toBeInTheDocument();
    expect(screen.queryByRole("combobox", { name: "Purchase Payer" })).not.toBeInTheDocument();

    await user.click(screen.getByRole("combobox", { name: "Category" }));
    await user.click(screen.getByRole("option", { name: "Fertilizer" }));
    expect(screen.getByRole("heading", { name: "Organic Fertilizer" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Tomato Seedling" })).not.toBeInTheDocument();
  });

  it("compacts a long purchase draft while preserving clear line prices", async () => {
    const user = userEvent.setup();
    renderApp("/supplies");

    for (const name of ["Carrot Seeds", "Potato Seeds", "Lettuce Seeds", "Tomato Seedling", "Field Watering Can"]) {
      await user.click(await screen.findByRole("button", { name: `Add ${name}` }));
    }

    const draft = screen.getByText("5 lines").closest(".supply-inspector");
    expect(draft).not.toBeNull();
    expect(within(draft as HTMLElement).getByText("+1 more selected item")).toBeInTheDocument();
    expect(within(draft as HTMLElement).getByText("$24")).toBeInTheDocument();
    expect(within(draft as HTMLElement).getByText("$28")).toBeInTheDocument();
  });

  it("renders every Owner Company deep view without an empty module", async () => {
    const routes = [
      ["/company/profile", "Grapeseed Farm Co."],
      ["/company/cargo", "Company Cargo"],
      ["/company/warehouse", "Warehouse"],
      ["/company/staff", "Staff"],
      ["/company/applications", "Applications"],
      ["/company/treasury", "Treasury"],
      ["/company/ledger", "Transaction Ledger"],
      ["/company/leases", "Land & Fields"],
      ["/company/leases/lease-orchard", "Orchard Annex"],
      ["/company/roles", "Roles & Permissions"],
      ["/company/identity", "Company Identity"],
      ["/company/sale", "Business Sale"],
      ["/company/sale/review", "Sale Listing Review"],
    ] as const;
    for (const [path, heading] of routes) {
      fixtureHubAdapter.reset();
      const view = renderApp(path);
      expect(await screen.findByRole("heading", { level: 1, name: heading })).toBeInTheDocument();
      expect(screen.queryByText("Coming Soon")).not.toBeInTheDocument();
      view.unmount();
    }
  });

  it("exposes public Company Profile and Job Application to a Visitor", async () => {
    const user = userEvent.setup();
    renderApp("/company/profile");
    await user.selectOptions(screen.getByLabelText("Preview role"), "visitor");
    expect(await screen.findByRole("heading", { name: "Grapeseed Farm Co." })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /apply for a job/i }));
    expect(await screen.findByRole("heading", { name: "Job Application" })).toBeInTheDocument();
    expect(screen.queryByText(/Treasury balance/i)).not.toBeInTheDocument();
  });

  it("uses shared unavailable state for a Company deep view", async () => {
    const user = userEvent.setup();
    renderApp("/company/warehouse");
    expect(await screen.findByRole("heading", { name: "Warehouse" })).toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText("Preview state"), "unavailable");
    expect(await screen.findByRole("heading", { name: "Farm service is unavailable" })).toBeInTheDocument();
  });
});
