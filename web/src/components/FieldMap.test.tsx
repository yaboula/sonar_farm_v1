import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { useState } from "react";
import { describe, expect, it } from "vitest";
import { createScaleFieldFixture } from "../data/fieldFixtures";
import { FieldMap } from "./FieldMap";

function ScaleMapHarness() {
  const field = createScaleFieldFixture();
  const [row, setRow] = useState<string>();
  const [slot, setSlot] = useState<string>();
  return <FieldMap field={field} layer="overview" selectedRowId={row} selectedSlotId={slot} onSelectRow={setRow} onSelectSlot={(slotId, rowId) => { setSlot(slotId); setRow(rowId); }} />;
}

describe("FieldMap", () => {
  it("renders the 20 by 20 limit and moves slot focus by stable identity", async () => {
    const { container } = render(<ScaleMapHarness />);
    fireEvent.click(screen.getByRole("button", { name: "Zoom in" }));
    fireEvent.click(screen.getByRole("button", { name: "Zoom in" }));
    expect(container.querySelectorAll("[data-slot-id]")).toHaveLength(400);
    const first = container.querySelector<SVGGElement>('[data-slot-id="scale-field:scale-r01:s01"]')!;
    first.focus();
    fireEvent.keyDown(first, { key: "ArrowRight" });
    await waitFor(() => expect(document.activeElement).toHaveAttribute("data-slot-id", "scale-field:scale-r01:s02"));
  });
});
