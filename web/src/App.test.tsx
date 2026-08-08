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
    expect(await screen.findByRole("heading", { name: "North Field" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /back to fields/i })).toBeInTheDocument();
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
});
