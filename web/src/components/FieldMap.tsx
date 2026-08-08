import { ArrowsOut, MagnifyingGlassMinus, MagnifyingGlassPlus } from "@phosphor-icons/react";
import { useEffect, useMemo, useRef, useState } from "react";
import type { FieldDetail, FieldLayer, FieldRow, FieldSlot } from "../types";

type Props = {
  field: FieldDetail;
  layer: FieldLayer;
  selectedRowId?: string;
  selectedSlotId?: string;
  onSelectRow: (rowId?: string) => void;
  onSelectSlot: (slotId?: string, rowId?: string) => void;
};

type StoredViewport = { zoom: number; pan: { x: number; y: number } };
const fieldViewportMemory = new Map<string, StoredViewport>();

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

export function FieldMap({ field, layer, selectedRowId, selectedSlotId, onSelectRow, onSelectSlot }: Props) {
  const svgRef = useRef<SVGSVGElement>(null);
  const dragRef = useRef<{ x: number; y: number; panX: number; panY: number } | undefined>(undefined);
  const storedViewport = fieldViewportMemory.get(field.id);
  const [zoom, setZoom] = useState(storedViewport?.zoom ?? (selectedRowId ? 1.35 : 1));
  const [pan, setPan] = useState(storedViewport?.pan ?? { x: 0, y: 0 });
  const visibleSlots = useMemo(() => field.topology.slots.filter((slot) => slot.visible && (!selectedRowId || slot.rowId === selectedRowId)), [field.topology.slots, selectedRowId]);
  const showSlots = zoom > 1.18 || Boolean(selectedRowId);
  const legend = LAYER_LEGEND[layer];

  const rowSlots = (row: FieldRow) => field.topology.slots.filter((slot) => row.slotIds.includes(slot.id));
  const adjustZoom = (next: number) => setZoom(Math.max(1, Math.min(2.25, next)));
  const reset = () => { setZoom(1); setPan({ x: 0, y: 0 }); onSelectSlot(undefined); onSelectRow(undefined); };
  const focusSlot = (slotId: string) => requestAnimationFrame(() => svgRef.current?.querySelector<SVGGElement>(`[data-slot-id="${slotId}"]`)?.focus());
  const focusRow = (rowId: string) => requestAnimationFrame(() => svgRef.current?.querySelector<SVGGElement>(`[data-row-id="${rowId}"]`)?.focus());

  useEffect(() => {
    fieldViewportMemory.set(field.id, { zoom, pan });
  }, [field.id, pan, zoom]);

  const moveRowSelection = (row: FieldRow, offset: number) => {
    const rows = field.topology.rows.filter((item) => item.visibleDetail);
    const current = rows.findIndex((item) => item.id === row.id);
    const next = rows[Math.max(0, Math.min(rows.length - 1, current + offset))];
    if (next) { onSelectRow(next.id); focusRow(next.id); }
  };

  const moveSelection = (slot: FieldSlot, direction: "left" | "right" | "up" | "down") => {
    const rows = field.topology.rows.filter((row) => row.visibleDetail);
    const rowIndex = rows.findIndex((row) => row.id === slot.rowId);
    const currentRow = rows[rowIndex];
    const column = currentRow?.slotIds.indexOf(slot.id) ?? -1;
    let nextId: string | undefined;
    if (direction === "left") nextId = currentRow?.slotIds[Math.max(0, column - 1)];
    if (direction === "right") nextId = currentRow?.slotIds[Math.min(currentRow.slotIds.length - 1, column + 1)];
    if (direction === "up") nextId = rows[Math.max(0, rowIndex - 1)]?.slotIds[column];
    if (direction === "down") nextId = rows[Math.min(rows.length - 1, rowIndex + 1)]?.slotIds[column];
    const next = field.topology.slots.find((item) => item.id === nextId && item.visible);
    if (next) { onSelectSlot(next.id, next.rowId); focusSlot(next.id); }
  };

  return (
    <section className="field-map-shell" aria-label={`${field.name} operating map`}>
      <header className="field-map-header">
        <div><span>Authoritative topology</span><strong>{field.topology.rows.length} {field.topology.rows.length === 1 ? "Row" : "Rows"} · {field.topology.slots.length} slots</strong></div>
        <div className="field-map-controls" aria-label="Map controls">
          <button type="button" aria-label="Zoom out" onClick={() => adjustZoom(zoom - 0.25)}><MagnifyingGlassMinus size={17} /></button>
          <span>{Math.round(zoom * 100)}%</span>
          <button type="button" aria-label="Zoom in" onClick={() => adjustZoom(zoom + 0.25)}><MagnifyingGlassPlus size={17} /></button>
          <button type="button" aria-label="Reset map" onClick={reset}><ArrowsOut size={17} /></button>
        </div>
      </header>
      <div className="field-map-stage">
        <svg
          ref={svgRef}
          viewBox="0 0 100 100"
          role="group"
          aria-label={`${field.name} Rows and planting slots`}
          onWheel={(event) => { event.preventDefault(); adjustZoom(zoom + (event.deltaY < 0 ? 0.15 : -0.15)); }}
          onPointerDown={(event) => { if ((event.target as Element).closest("[data-slot-id], [data-row-id]")) return; dragRef.current = { x: event.clientX, y: event.clientY, panX: pan.x, panY: pan.y }; event.currentTarget.setPointerCapture(event.pointerId); }}
          onPointerMove={(event) => { const drag = dragRef.current; if (!drag || zoom === 1) return; setPan({ x: drag.panX + (event.clientX - drag.x) / 8, y: drag.panY + (event.clientY - drag.y) / 8 }); }}
          onPointerUp={() => { dragRef.current = undefined; }}
        >
          <defs>
            <pattern id="field-grid-pattern" width="5" height="5" patternUnits="userSpaceOnUse"><path d="M 5 0 L 0 0 0 5" fill="none" stroke="currentColor" strokeWidth="0.12" /></pattern>
          </defs>
          <rect className="field-map-grid" x="2" y="2" width="96" height="96" rx="1.5" fill="url(#field-grid-pattern)" />
          <g transform={`translate(${pan.x} ${pan.y}) translate(50 50) scale(${zoom}) rotate(${field.topology.orientation}) translate(-50 -50)`}>
            {field.topology.rows.map((row) => {
              const slots = rowSlots(row);
              if (!slots.length) return null;
              const first = slots[0].position;
              const last = slots[slots.length - 1].position;
              const selected = selectedRowId === row.id;
              return (
                <g key={row.id} data-row-id={row.id} className={`field-map-row field-map-row--${row.status}${selected ? " is-selected" : ""}`} role="button" tabIndex={showSlots ? -1 : selected || (!selectedRowId && row.order === 1) ? 0 : -1} aria-label={`${row.label}, ${row.status}, ${row.occupied} occupied, ${row.criticalCount} critical`} aria-current={selected ? "true" : undefined} onClick={() => { onSelectRow(row.id); setZoom(Math.max(zoom, 1.35)); }} onKeyDown={(event) => { if (event.key === "Enter" || event.key === " ") { event.preventDefault(); onSelectRow(row.id); setZoom(Math.max(zoom, 1.35)); } if (event.key === "Escape") reset(); if (event.key === "ArrowUp" || event.key === "ArrowLeft") { event.preventDefault(); moveRowSelection(row, -1); } if (event.key === "ArrowDown" || event.key === "ArrowRight") { event.preventDefault(); moveRowSelection(row, 1); } }}>
                  <line className="field-map-row-hit" x1={first.x - 2} y1={first.y} x2={last.x + 2} y2={last.y} />
                  <line className="field-map-row-line" x1={first.x} y1={first.y} x2={last.x} y2={last.y} />
                  <text className="field-map-row-label" x={first.x - 3.5} y={first.y + 1}>{row.label.replace("Row ", "")}</text>
                  {!showSlots && row.criticalCount ? <circle className="field-map-row-alert" cx={last.x + 2.5} cy={last.y} r="1.25" /> : null}
                </g>
              );
            })}
            {showSlots ? visibleSlots.map((slot, index) => {
              const tone = slotTone(field, slot, layer);
              const selected = slot.id === selectedSlotId;
              return (
                <g key={slot.id} data-slot-id={slot.id} className={`field-map-slot field-map-slot--${tone}${selected ? " is-selected" : ""}`} role="button" tabIndex={selected || (!selectedSlotId && index === 0) ? 0 : -1} aria-label={`${slot.label}, ${slotValue(slot, layer)}`} onClick={(event) => { event.stopPropagation(); onSelectSlot(slot.id, slot.rowId); }} onKeyDown={(event) => {
                  if (event.key === "Enter" || event.key === " ") { event.preventDefault(); onSelectSlot(slot.id, slot.rowId); }
                  if (event.key === "Escape") { event.preventDefault(); onSelectSlot(undefined, slot.rowId); }
                  if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) { event.preventDefault(); moveSelection(slot, event.key.replace("Arrow", "").toLowerCase() as "left" | "right" | "up" | "down"); }
                }}>
                  <circle cx={slot.position.x} cy={slot.position.y} r={selected ? 1.7 : 1.25} />
                  {slot.status === "planned" ? <circle className="field-map-slot-plan-ring" cx={slot.position.x} cy={slot.position.y} r="1.9" /> : null}
                </g>
              );
            }) : null}
          </g>
        </svg>
        <div className="field-map-north" aria-hidden="true"><span>N</span><i /></div>
        <div className="field-map-legend" aria-label={`${layer} layer legend`}><span>{legend.copy}</span><div>{legend.items.map((item) => <em key={item.label}><i data-tone={item.tone} />{item.label}</em>)}</div></div>
      </div>
      <footer className="field-map-footer"><span>Layer · {layer === "plan" ? "Crop Plan" : layer}</span><span>{selectedRowId ? field.topology.rows.find((row) => row.id === selectedRowId)?.label : "All Rows"}{selectedSlotId ? ` · ${field.topology.slots.find((slot) => slot.id === selectedSlotId)?.label.split(" · ")[1]}` : ""}</span><span>Topology {field.topology.topologyRevision.split("-").at(-1)}</span></footer>
    </section>
  );
}
