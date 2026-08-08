import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { useState } from "react";
import { describe, expect, it } from "vitest";
import { createScaleFieldFixture } from "../data/fieldFixtures";
import { FieldMap } from "./FieldMap";

function ScaleMapHarness() {
  const field = createScaleFieldFixture();
  const [row, setRow] = useState<string | undefined>("scale-r01");
  const [slot, setSlot] = useState<string>();
  return <FieldMap field={field} layer="overview" selectedRowId={row} selectedSlotId={slot} onSelectRow={setRow} onSelectSlot={(slotId, rowId) => { setSlot(slotId); setRow(rowId); }} />;
}

describe("FieldMap", () => {
  it("shows a fixed 10-Row viewport and fits 20 Slots without zoom", async () => {
    const { container } = render(<ScaleMapHarness />);
    expect(container.querySelectorAll("[data-row-id]")).toHaveLength(20);
    expect(container.querySelectorAll("[data-slot-id]")).toHaveLength(20);
    expect(screen.queryByRole("button", { name: /zoom/i })).not.toBeInTheDocument();
    expect(container.querySelector("[data-map-content]")).not.toHaveAttribute("transform");
    expect(container.querySelector("svg")).toHaveStyle({ height: "600px" });
    expect(screen.getByText(/Rows 1–10/i)).toBeInTheDocument();

    const scroller = screen.getByTestId("field-map-scroll");
    scroller.scrollTop = 300;
    fireEvent.scroll(scroller);
    expect(screen.getByText(/Rows 11–20/i)).toBeInTheDocument();

    const first = container.querySelector<SVGGElement>('[data-slot-id="scale-field:scale-r01:s01"]')!;
    first.focus();
    fireEvent.keyDown(first, { key: "ArrowRight" });
    await waitFor(() => expect(document.activeElement).toHaveAttribute("data-slot-id", "scale-field:scale-r01:s02"));
  });
});
