import { X } from "@phosphor-icons/react";
import { type PropsWithChildren, useEffect, useRef } from "react";

export function ConfirmDialog({
  title,
  eyebrow,
  confirmLabel,
  tone = "confirm",
  pending = false,
  onConfirm,
  onClose,
  children,
}: PropsWithChildren<{
  title: string;
  eyebrow: string;
  confirmLabel: string;
  tone?: "confirm" | "danger-confirm";
  pending?: boolean;
  onConfirm: () => void;
  onClose: () => void;
}>) {
  const closeRef = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    closeRef.current?.focus();
    const escape = (event: KeyboardEvent) => event.key === "Escape" && onClose();
    window.addEventListener("keydown", escape);
    return () => window.removeEventListener("keydown", escape);
  }, [onClose]);
  return (
    <div className="assignment-dialog-layer" role="presentation" onMouseDown={onClose}>
      <section className="assignment-dialog" role="dialog" aria-modal="true" aria-labelledby="confirm-dialog-title" onMouseDown={(event) => event.stopPropagation()}>
        <button ref={closeRef} className="dialog-close" type="button" onClick={onClose} aria-label="Close dialog"><X size={20} /></button>
        <span className="dialog-eyebrow">{eyebrow}</span>
        <h2 id="confirm-dialog-title">{title}</h2>
        <div className="dialog-content">{children}</div>
        <footer className="dialog-actions">
          <button type="button" onClick={onClose}>Go Back</button>
          <button type="button" className={tone} disabled={pending} onClick={onConfirm}>{pending ? "Working…" : confirmLabel}</button>
        </footer>
      </section>
    </div>
  );
}
