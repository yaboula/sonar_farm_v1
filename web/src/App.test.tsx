import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { App } from "./App";
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
  it("renders the master Today assignment", () => {
    renderApp();
    expect(screen.getByRole("heading", { name: "Today" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Water North Field" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /continue assignment/i })).toBeInTheDocument();
  });

  it("routes the current assignment into Work", async () => {
    const user = userEvent.setup();
    renderApp();
    await user.click(screen.getByRole("button", { name: /continue assignment/i }));
    expect(screen.getByRole("heading", { name: "Work" })).toBeInTheDocument();
    expect(screen.getAllByText("Water North Field").length).toBeGreaterThan(0);
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
});
