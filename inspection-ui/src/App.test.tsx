import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { App } from "./App";
import { inspectionFixture } from "./fixture";

describe("Crop Inspection Pulse Rail", () => {
  function open(payload = inspectionFixture()) {
    fireEvent(window, new MessageEvent("message", { data: { type: "inspection:open", payload } }));
  }

  it("renders nothing until an authoritative open payload arrives", () => {
    render(<App />);
    expect(screen.queryByRole("article")).not.toBeInTheDocument();
  });

  it("renders real metrics, temporal references and a non-interactive recommendation", () => {
    render(<App />);
    open();
    expect(screen.getByRole("article", { name: /Tomato crop inspection/i })).toBeInTheDocument();
    expect(screen.getByText("WEEDS → FASTER WATER LOSS")).toBeInTheDocument();
    expect(screen.getByText("REMOVE WEEDS")).toBeInTheDocument();
    expect(screen.getByText(/NO CARE FORECAST/)).toBeInTheDocument();
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
  });

  it("merges lightweight updates without losing the last curve series", () => {
    render(<App />);
    open();
    const next = inspectionFixture(2_000_000_000);
    next.health = 72;
    next.series = undefined;
    fireEvent(window, new MessageEvent("message", { data: { type: "inspection:update", payload: next } }));
    expect(screen.getByText("72%")).toBeInTheDocument();
    expect(screen.getAllByRole("img", { name: /trend/ })).toHaveLength(4);
  });

  it("closes on an inspection close message", () => {
    render(<App />);
    open();
    fireEvent(window, new MessageEvent("message", { data: { type: "inspection:close", payload: { reason: "distance" } } }));
    expect(screen.queryByRole("article")).not.toBeInTheDocument();
  });
});
