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
      expect(screen.getByRole("heading", { name: label })).toBeInTheDocument();
    }
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

  it("shows Restricted after live permission loss", async () => {
    const user = userEvent.setup();
    renderApp("/work/assignments/asg-1048");
    expect(await screen.findByRole("heading", { name: "Water North Field" })).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText("Preview role"), "visitor");

    expect(await screen.findByRole("heading", { name: "Access restricted" })).toBeInTheDocument();
  });
});
