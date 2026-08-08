import { CheckCircle, Plant, Warning } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import type { CropPlanInput, FieldDetail } from "../types";
import { ConfirmDialog } from "./ConfirmDialog";
import { FarmSelect } from "./FarmSelect";

const cropOptions = [
  { value: "tomato", label: "Tomatoes", description: "Slow, demanding fruit crop" },
  { value: "lettuce", label: "Lettuce", description: "Fast cycle · water sensitive" },
  { value: "potato", label: "Potatoes", description: "Hardy tuber · drought tolerant" },
  { value: "carrot", label: "Carrots", description: "Balanced tuber crop" },
] as const;

const labelFor = (crop: string) => cropOptions.find((item) => item.value === crop)?.label ?? crop;

export function CropPlanDialog({ field, initialRowId, existingPlan, pending, onClose, onConfirm }: {
  field: FieldDetail;
  initialRowId?: string;
  existingPlan?: FieldDetail["cropPlans"][number];
  pending: boolean;
  onClose: () => void;
  onConfirm: (input: CropPlanInput) => void;
}) {
  const initialRow = field.topology.rows.find((row) => row.id === initialRowId);
  const [crop, setCrop] = useState(existingPlan?.crop ?? initialRow?.plannedCrop ?? (initialRow?.cropLabel === "Lettuce" ? "lettuce" : "tomato"));
  const [rowIds, setRowIds] = useState<string[]>(existingPlan?.rowIds ?? (initialRowId ? [initialRowId] : []));
  const activePlanRows = new Set(field.cropPlans.filter((plan) => plan.id !== existingPlan?.id && ["reserved", "in_execution"].includes(plan.status)).flatMap((plan) => plan.rowIds));
  const eligibleRows = field.topology.rows.filter((row) => {
    const available = row.available + (existingPlan?.rowIds.includes(row.id) ? row.planned : 0);
    if (!row.visibleDetail || activePlanRows.has(row.id) || available <= 0) return false;
    if (!row.occupied) return true;
    const existing = row.cropLabel.toLowerCase();
    return existing === crop || existing === labelFor(crop).toLowerCase();
  });
  const selectedRows = field.topology.rows.filter((row) => rowIds.includes(row.id));
  const review = useMemo(() => {
    const selectedSlots = field.topology.slots.filter((slot) => rowIds.includes(slot.rowId));
    return {
      eligible: selectedSlots.filter((slot) => slot.status === "empty" || (slot.status === "planned" && existingPlan?.rowIds.includes(slot.rowId))).length,
      excluded: selectedSlots.filter((slot) => slot.status === "occupied").length,
    };
  }, [existingPlan?.rowIds, field.topology.slots, rowIds]);

  const toggleRow = (id: string) => setRowIds((current) => current.includes(id) ? current.filter((item) => item !== id) : [...current, id]);

  return (
    <ConfirmDialog eyebrow="Agronomic planning" title={existingPlan ? `Update ${existingPlan.reference}?` : "Reserve this Crop Plan?"} confirmLabel={existingPlan ? "Update Crop Plan" : "Reserve Crop Plan"} pending={pending} confirmDisabled={!rowIds.length} onClose={onClose} onConfirm={() => onConfirm({ fieldId: field.id, rowIds, crop })}>
      <div className="crop-plan-dialog-content">
        <p>Planning reserves empty slots and produces no crop. Work must still be issued and completed physically.</p>
        <FarmSelect label="Crop Identity" value={crop} options={cropOptions} onChange={(value) => { setCrop(value); setRowIds([]); }} />
        <div className="crop-plan-row-picker" role="group" aria-label="Eligible Rows">
          {field.topology.rows.map((row) => {
            const eligible = eligibleRows.some((item) => item.id === row.id);
            const selected = rowIds.includes(row.id);
            const available = row.available + (existingPlan?.rowIds.includes(row.id) ? row.planned : 0);
            return <button type="button" key={row.id} disabled={!eligible} aria-pressed={selected} className={selected ? "is-selected" : ""} onClick={() => toggleRow(row.id)}><span>{selected ? <CheckCircle size={17} /> : <Plant size={17} />}{row.label}</span><small>{eligible ? `${available} empty slots` : activePlanRows.has(row.id) ? "Reserved" : available <= 0 ? "No empty slots" : `Contains ${row.cropLabel}`}</small></button>;
          })}
        </div>
        <div className="crop-plan-review">
          <div><span>Selected Rows</span><strong>{selectedRows.length}</strong></div>
          <div><span>Eligible Slots</span><strong>{review.eligible}</strong></div>
          <div><span>Excluded</span><strong>{review.excluded}</strong></div>
        </div>
        {!rowIds.length ? <div className="crop-plan-warning"><Warning size={17} />Select at least one eligible Row.</div> : <div className="crop-plan-material"><Plant size={17} />Estimated: {labelFor(crop)} seedlings ×{review.eligible} · initial water ×{review.eligible}</div>}
      </div>
    </ConfirmDialog>
  );
}
