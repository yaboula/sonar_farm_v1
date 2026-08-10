import { act, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { App } from "./App";
import { inspectionFixture } from "./fixture";
import { curveTone } from "./MetricChart";

describe("Crop Inspection Pulse Rail", () => {
  afterEach(() => vi.useRealTimers());

  function open(payload = inspectionFixture()) {
    fireEvent(window, new MessageEvent("message", { data: { type: "inspection:open", payload } }));
  }

  it("renders nothing until an authoritative open payload arrives", () => {
    render(<App />);
    expect(screen.queryByRole("article")).not.toBeInTheDocument();
  });

  it("maps every authoritative status to a semantic curve tone", () => {
    expect(curveTone({ key: "water", status: "critical" })).toBe("risk");
    expect(curveTone({ key: "pests", status: "severe" })).toBe("risk");
    expect(curveTone({ key: "nutrients", status: "high" })).toBe("risk");
    expect(curveTone({ key: "water", status: "low" })).toBe("watch");
    expect(curveTone({ key: "weeds", status: "low" })).toBe("good");
    expect(curveTone({ key: "weeds", status: "elevated" })).toBe("watch");
    expect(curveTone({ key: "nutrients", status: "stable" })).toBe("good");
    expect(curveTone({ key: "pests", status: "unaffected" })).toBe("unaffected");
  });

  it("renders real metrics, temporal references and the rotating field guide", () => {
    render(<App />);
    open();
    expect(screen.getByRole("article", { name: /Tomato crop inspection/i })).toBeInTheDocument();
    expect(screen.getByText("WEEDS DRAIN WATER AND NUTRIENTS")).toBeInTheDocument();
    expect(screen.getByText("Field guide")).toBeInTheDocument();
    expect(screen.queryByText("Recommended action")).not.toBeInTheDocument();
    expect(screen.queryByText("REMOVE WEEDS")).not.toBeInTheDocument();
    expect(screen.getAllByRole("img", { name: /historical trend/i })).toHaveLength(4);
    expect(screen.queryByText(/NO CARE FORECAST/)).not.toBeInTheDocument();
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
    expect(document.querySelectorAll('svg[data-tone="watch"]')).toHaveLength(2);
    expect(document.querySelectorAll('svg[data-tone="good"]')).toHaveLength(2);
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
  });

  it("closes on an inspection close message", () => {
    render(<App />);
    open();
    fireEvent(window, new MessageEvent("message", { data: { type: "inspection:close", payload: { reason: "distance" } } }));
    expect(screen.queryByRole("article")).not.toBeInTheDocument();
  });
});
