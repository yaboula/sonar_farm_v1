import { act, fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { App } from "./App";
import { inspectionFixture } from "./fixture";
import { curveTone } from "./MetricChart";

describe("Crop Inspection Pulse Rail", () => {
  function open(payload = inspectionFixture()) {
    fireEvent(window, new MessageEvent("message", { data: { type: "inspection:open", payload } }));
  }

  it("renders nothing until an authoritative open payload arrives", () => {
    render(<App />);
    expect(screen.queryByRole("article")).not.toBeInTheDocument();
  });

  it("maps every authoritative status to a semantic curve tone", () => {
    expect(curveTone("critical")).toBe("risk");
    expect(curveTone("severe")).toBe("risk");
    expect(curveTone("high")).toBe("risk");
    expect(curveTone("low")).toBe("watch");
    expect(curveTone("elevated")).toBe("watch");
    expect(curveTone("stable")).toBe("good");
    expect(curveTone("unaffected")).toBe("unaffected");
  });

  it("renders real metrics, temporal references and the rotating field guide", () => {
    render(<App />);
    open();
    expect(screen.getByRole("article", { name: /Tomato crop inspection/i })).toBeInTheDocument();
    expect(screen.getByText("WEEDS DRAIN WATER AND NUTRIENTS")).toBeInTheDocument();
    expect(screen.getByText("Field guide")).toBeInTheDocument();
    expect(screen.queryByText("Recommended action")).not.toBeInTheDocument();
    expect(screen.queryByText("REMOVE WEEDS")).not.toBeInTheDocument();
    expect(screen.getByText(/NO CARE FORECAST/)).toBeInTheDocument();
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
    expect(document.querySelectorAll('svg[data-tone="watch"]')).toHaveLength(3);
    expect(document.querySelectorAll('svg[data-tone="good"]')).toHaveLength(1);
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

  it("rotates through the six agronomy lessons without user interaction", () => {
    vi.useFakeTimers();
    render(<App />);
    open();
    expect(screen.getByText("WEEDS DRAIN WATER AND NUTRIENTS")).toBeInTheDocument();
    act(() => vi.advanceTimersByTime(6500));
    expect(screen.getByText("LOW WATER SLOWS GROWTH")).toBeInTheDocument();
    expect(screen.getByText("02 / 06")).toBeInTheDocument();
    vi.useRealTimers();
  });

  it("closes on an inspection close message", () => {
    render(<App />);
    open();
    fireEvent(window, new MessageEvent("message", { data: { type: "inspection:close", payload: { reason: "distance" } } }));
    expect(screen.queryByRole("article")).not.toBeInTheDocument();
  });
});
