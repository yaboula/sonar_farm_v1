import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { FieldDetail, FieldLayer, FieldRow, FieldSlot } from "../types";

type Props = {
  field: FieldDetail;
  layer: FieldLayer;
  selectedRowId?: string;
  selectedSlotId?: string;
  onSelectRow: (rowId?: string) => void;
  onSelectSlot: (slotId?: string, rowId?: string) => void;
};

const ROWS_PER_VIEW = 10;
const ROW_UNIT_HEIGHT = 10;
const ROW_PIXEL_HEIGHT = 30;
const FIELD_WIDTH = 300;
const fieldScrollMemory = new Map<string, number>();

const LAYER_LEGEND: Record<FieldLayer, { copy: string; items: Array<{ label: string; tone: string }> }> = {
  overview: { copy: "Occupancy with explicit critical exceptions", items: [{ label: "Occupied", tone: "good" }, { label: "Empty", tone: "empty" }, { label: "Critical", tone: "critical" }] },
  water: { copy: "Authoritative plant water band", items: [{ label: "Safe", tone: "good" }, { label: "Watch", tone: "warning" }, { label: "Low", tone: "critical" }] },
  health: { copy: "Current plant health band", items: [{ label: "Healthy", tone: "good" }, { label: "Watch", tone: "warning" }, { label: "Low", tone: "critical" }] },
  growth: { copy: "Growth progress, not harvest quality", items: [{ label: "Early", tone: "early" }, { label: "Developing", tone: "warning" }, { label: "Mature", tone: "ready" }] },
  readiness: { copy: "Harvest window including spoilage risk", items: [{ label: "Growing", tone: "good" }, { label: "Ready", tone: "ready" }, { label: "At risk", tone: "critical" }] },
  work: { copy: "Accountable Work attached to each Slot", items: [{ label: "Assignment", tone: "assigned" }, { label: "Contract", tone: "contract" }, { label: "Unlinked", tone: "empty" }] },
  plan: { copy: "Planned scope never means planted", items: [{ label: "Reserved", tone: "planned" }, { label: "Occupied", tone: "good" }, { label: "Available", tone: "empty" }] },
};

function slotTone(field: FieldDetail, slot: FieldSlot, layer: FieldLayer) {
  const hasCritical = slot.diagnosticIds.some((id) => field.diagnostics.find((item) => item.id === id)?.severity === "critical");
  if (hasCritical) return "critical";
  if (!slot.visible) return "restricted";
  if (layer === "plan") return slot.status === "planned" ? "planned" : slot.status;
  if (layer === "work") return slot.assignmentId ? "assigned" : slot.contractId ? "contract" : "neutral";
  if (!slot.plant) return slot.status;
  if (layer === "water") return slot.plant.water < 35 ? "low" : slot.plant.water < 55 ? "warning" : "good";
  if (layer === "health") return slot.plant.health < 50 ? "low" : slot.plant.health < 75 ? "warning" : "good";
  if (layer === "growth") return slot.plant.progress >= 95 ? "ready" : slot.plant.progress >= 60 ? "mid" : "early";
  if (layer === "readiness") return slot.plant.readiness === "ready" ? (slot.plant.spoilage >= 8 ? "critical" : "ready") : slot.plant.readiness === "at_risk" ? "warning" : "growing";
  return slot.status === "occupied" ? "growing" : slot.status;
}

function slotValue(slot: FieldSlot, layer: FieldLayer) {
  if (!slot.visible) return "Restricted detail";
  if (!slot.plant) return slot.status === "planned" ? `${slot.plannedCrop} planned` : "Empty planting slot";
  if (layer === "water") return `Water ${slot.plant.water}%`;
  if (layer === "health") return `Health ${slot.plant.health}%`;
  if (layer === "growth") return `Growth ${slot.plant.progress}%`;
  if (layer === "readiness") return `${slot.plant.readiness} · spoilage ${slot.plant.spoilage}%`;
  if (layer === "work") return slot.assignmentId ? `Assignment ${slot.assignmentId.toUpperCase()}` : slot.contractId ? `Contract ${slot.contractId.toUpperCase()}` : "No linked Work";
  return `${slot.plant.cropLabel} · ${slot.plant.stage}`;
}

function slotX(slot: FieldSlot, row: FieldRow) {
  const index = row.slotIds.indexOf(slot.id);
  if (row.slotIds.length <= 1) return 162;
  return 45 + index * (235 / (row.slotIds.length - 1));
}

export function FieldMap({ field, layer, selectedRowId, selectedSlotId, onSelectRow, onSelectSlot }: Props) {
  const svgRef = useRef<SVGSVGElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const rows = field.topology.rows;
  const contentRows = Math.max(ROWS_PER_VIEW, rows.length);
  const contentHeight = contentRows * ROW_UNIT_HEIGHT;
  const [visibleWindow, setVisibleWindow] = useState({ first: 1, last: Math.min(ROWS_PER_VIEW, rows.length) });
  const visibleSlots = useMemo(() => selectedRowId ? field.topology.slots.filter((slot) => slot.visible && slot.rowId === selectedRowId) : [], [field.topology.slots, selectedRowId]);
  const legend = LAYER_LEGEND[layer];

  const focusSlot = (slotId: string) => requestAnimationFrame(() => svgRef.current?.querySelector<SVGGElement>(`[data-slot-id="${slotId}"]`)?.focus());
  const focusRow = (rowId: string) => requestAnimationFrame(() => svgRef.current?.querySelector<SVGGElement>(`[data-row-id="${rowId}"]`)?.focus());
  const updateVisibleWindow = useCallback((scrollTop: number) => {
    const first = Math.min(Math.max(1, Math.floor(scrollTop / ROW_PIXEL_HEIGHT) + 1), Math.max(1, rows.length));
    setVisibleWindow({ first, last: Math.min(rows.length, first + ROWS_PER_VIEW - 1) });
    fieldScrollMemory.set(field.id, scrollTop);
  }, [field.id, rows.length]);

  useEffect(() => {
    const scroller = scrollRef.current;
    if (!scroller) return;
    scroller.scrollTop = fieldScrollMemory.get(field.id) ?? 0;
    updateVisibleWindow(scroller.scrollTop);
  }, [field.id, updateVisibleWindow]);

  useEffect(() => {
    const scroller = scrollRef.current;
    const rowIndex = rows.findIndex((row) => row.id === selectedRowId);
    if (!scroller || rowIndex < 0) return;
    const rowTop = rowIndex * ROW_PIXEL_HEIGHT;
    const rowBottom = rowTop + ROW_PIXEL_HEIGHT;
    if (rowTop < scroller.scrollTop) scroller.scrollTop = rowTop;
    else if (rowBottom > scroller.scrollTop + ROWS_PER_VIEW * ROW_PIXEL_HEIGHT) scroller.scrollTop = rowBottom - ROWS_PER_VIEW * ROW_PIXEL_HEIGHT;
    updateVisibleWindow(scroller.scrollTop);
  }, [rows, selectedRowId, updateVisibleWindow]);

  const moveRowSelection = (row: FieldRow, offset: number) => {
    const availableRows = rows.filter((item) => item.visibleDetail);
    const current = availableRows.findIndex((item) => item.id === row.id);
    const next = availableRows[Math.max(0, Math.min(availableRows.length - 1, current + offset))];
    if (next) { onSelectRow(next.id); focusRow(next.id); }
  };

  const moveSelection = (slot: FieldSlot, direction: "left" | "right" | "up" | "down") => {
    const availableRows = rows.filter((row) => row.visibleDetail);
    const rowIndex = availableRows.findIndex((row) => row.id === slot.rowId);
    const currentRow = availableRows[rowIndex];
    const column = currentRow?.slotIds.indexOf(slot.id) ?? -1;
    let nextId: string | undefined;
    if (direction === "left") nextId = currentRow?.slotIds[Math.max(0, column - 1)];
    if (direction === "right") nextId = currentRow?.slotIds[Math.min(currentRow.slotIds.length - 1, column + 1)];
    if (direction === "up" || direction === "down") {
      const targetRowIndex = direction === "up" ? Math.max(0, rowIndex - 1) : Math.min(availableRows.length - 1, rowIndex + 1);
      const targetRow = availableRows[targetRowIndex];
      if (currentRow && targetRow) {
        const sourceLastIndex = Math.max(1, currentRow.slotIds.length - 1);
        const targetLastIndex = Math.max(0, targetRow.slotIds.length - 1);
        const proportionalColumn = Math.round((Math.max(0, column) / sourceLastIndex) * targetLastIndex);
        nextId = targetRow.slotIds[proportionalColumn];
      }
    }
    const next = field.topology.slots.find((item) => item.id === nextId && item.visible);
    if (next) { onSelectSlot(next.id, next.rowId); focusSlot(next.id); }
  };

  return (
    <section className="field-map-shell" aria-label={`${field.name} operating map`}>
      <header className="field-map-header">
        <div><span>Authoritative topology · 0° orientation</span><strong>{rows.length} {rows.length === 1 ? "Row" : "Rows"} · {field.topology.slots.length} slots</strong></div>
        <div className="field-map-scroll-hint" aria-label="Map scroll behavior"><strong>{ROWS_PER_VIEW} Rows per view</strong><span>{rows.length > ROWS_PER_VIEW ? "Scroll vertically for remaining Rows" : "All Rows are visible"}</span></div>
      </header>
      <div className="field-map-legend" aria-label={`${layer} layer legend`}><span>{legend.copy}</span><div>{legend.items.map((item) => <em key={item.label}><i data-tone={item.tone} />{item.label}</em>)}</div></div>
      <div className="field-map-stage">
        <div ref={scrollRef} className="field-map-scroll" data-testid="field-map-scroll" onScroll={(event) => updateVisibleWindow(event.currentTarget.scrollTop)}>
          <svg ref={svgRef} viewBox={`0 0 ${FIELD_WIDTH} ${contentHeight}`} style={{ height: `${contentRows * ROW_PIXEL_HEIGHT}px` }} role="group" aria-label={`${field.name} Rows and planting slots`}>
            <defs>
              <pattern id={`field-grid-pattern-${field.id}`} width="15" height="10" patternUnits="userSpaceOnUse"><path d="M 15 0 L 0 0 0 10" fill="none" stroke="currentColor" strokeWidth="0.12" /></pattern>
            </defs>
            <rect className="field-map-grid" x="0" y="0" width={FIELD_WIDTH} height={contentHeight} fill={`url(#field-grid-pattern-${field.id})`} />
            <g data-map-content="fixed-zero-orientation">
              {rows.map((row, rowIndex) => {
                const y = rowIndex * ROW_UNIT_HEIGHT + ROW_UNIT_HEIGHT / 2;
                const selected = selectedRowId === row.id;
                return (
                  <g key={row.id} data-row-id={row.id} className={`field-map-row field-map-row--${row.status}${selected ? " is-selected" : ""}`} role="button" tabIndex={selected || (!selectedRowId && row.order === 1) ? 0 : -1} aria-label={`${row.label}, ${row.status}, ${row.occupied} occupied, ${row.criticalCount} critical`} aria-current={selected ? "true" : undefined} onClick={() => onSelectRow(row.id)} onKeyDown={(event) => { if (event.key === "Enter" || event.key === " ") { event.preventDefault(); onSelectRow(row.id); } if (event.key === "Escape") { onSelectSlot(undefined); onSelectRow(undefined); } if (event.key === "ArrowUp" || event.key === "ArrowLeft") { event.preventDefault(); moveRowSelection(row, -1); } if (event.key === "ArrowDown" || event.key === "ArrowRight") { event.preventDefault(); moveRowSelection(row, 1); } }}>
                    <line className="field-map-row-hit" x1="36" y1={y} x2="286" y2={y} />
                    <line className="field-map-row-line" x1="42" y1={y} x2="280" y2={y} />
                    <text className="field-map-row-label" x="31" y={y + 1}>{row.label.replace("Row ", "")}</text>
                    {row.criticalCount ? <circle className="field-map-row-alert" cx="289" cy={y} r="1.25" /> : null}
                  </g>
                );
              })}
              {visibleSlots.map((slot, index) => {
                const row = rows.find((item) => item.id === slot.rowId);
                if (!row) return null;
                const rowIndex = rows.findIndex((item) => item.id === row.id);
                const x = slotX(slot, row);
                const y = rowIndex * ROW_UNIT_HEIGHT + ROW_UNIT_HEIGHT / 2;
                const tone = slotTone(field, slot, layer);
                const selected = slot.id === selectedSlotId;
                return (
                  <g key={slot.id} data-slot-id={slot.id} className={`field-map-slot field-map-slot--${tone}${selected ? " is-selected" : ""}`} role="button" tabIndex={selected || (!selectedSlotId && index === 0) ? 0 : -1} aria-label={`${slot.label}, ${slotValue(slot, layer)}`} onClick={(event) => { event.stopPropagation(); onSelectSlot(slot.id, slot.rowId); }} onKeyDown={(event) => {
                    if (event.key === "Enter" || event.key === " ") { event.preventDefault(); onSelectSlot(slot.id, slot.rowId); }
                    if (event.key === "Escape") { event.preventDefault(); onSelectSlot(undefined, slot.rowId); focusRow(slot.rowId); }
                    if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) { event.preventDefault(); moveSelection(slot, event.key.replace("Arrow", "").toLowerCase() as "left" | "right" | "up" | "down"); }
                  }}>
                    <circle cx={x} cy={y} r={selected ? 1.7 : 1.25} />
                    {slot.status === "planned" ? <circle className="field-map-slot-plan-ring" cx={x} cy={y} r="1.9" /> : null}
                  </g>
                );
              })}
            </g>
          </svg>
        </div>
        <div className="field-map-north" aria-hidden="true"><span>N</span><i /></div>
      </div>
      <footer className="field-map-footer"><span>Layer · {layer === "plan" ? "Crop Plan" : layer}</span><span>{selectedRowId ? rows.find((row) => row.id === selectedRowId)?.label : "All Rows"}{selectedSlotId ? ` · ${field.topology.slots.find((slot) => slot.id === selectedSlotId)?.label.split(" · ")[1]}` : ""}</span><span>Rows {visibleWindow.first}–{visibleWindow.last} · {field.topology.topologyRevision.split("-").at(-1)}</span></footer>
    </section>
  );
}
