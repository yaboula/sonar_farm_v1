import { ArrowSquareOut, Funnel, MagnifyingGlass, Receipt, ShieldCheck } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../../components/DeepViewShell";
import { FarmSelect } from "../../components/FarmSelect";
import { StatePanel } from "../../components/StatePanel";
import type { LedgerEntry } from "../../types";
import { useCompanyData } from "./useCompanyData";

const money = (value: number) => `$${value.toLocaleString("en-US")}`;

export function LedgerView() {
  const request = useMemo(() => ({ kind: "companyLedger" } as const), []);
  const { model, data } = useCompanyData<LedgerEntry[]>(request);
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const [query, setQuery] = useState("");
  const [type, setType] = useState("all");
  const [status, setStatus] = useState("all");
  const [direction, setDirection] = useState("all");
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  const normalized = query.trim().toLowerCase();
  const filtered = data.filter((entry) => (type === "all" || entry.type === type) && (status === "all" || entry.status === status) && (direction === "all" || entry.direction === direction) && (!normalized || [entry.id, entry.actor, entry.source, entry.destination, entry.linkedId].some((value) => value?.toLowerCase().includes(normalized))));
  const selected = data.find((entry) => entry.id === params.get("transaction")) ?? filtered[0];
  const openLinked = (entry: LedgerEntry) => {
    if (!entry.linkedId) return;
    if (entry.linkedKind === "purchase") navigate(`/supplies/purchases/${entry.linkedId}/review`);
    if (entry.linkedKind === "buyer_order") navigate(`/work/orders/${entry.linkedId}`);
    if (entry.linkedKind === "assignment") navigate(`/work/assignments/${entry.linkedId}`);
    if (entry.linkedKind === "contract") navigate(`/work/contracts/active/${entry.linkedId}`);
    if (entry.linkedKind === "lease") navigate(`/company/leases/${entry.linkedId}`);
  };
  const canOpen = selected && ["purchase", "buyer_order", "assignment", "contract", "lease"].includes(selected.linkedKind ?? "");
  return <DeepViewShell eyebrow="Immutable company record" title="Transaction Ledger" subtitle="Every movement retains actor, source, destination, linked entity and settlement state" breadcrumb={["Company", "Treasury", "Ledger"]} backLabel="Back to Treasury" onBack={() => navigate("/company/treasury")} status={<StatusPill tone="success">{data.length} Entries</StatusPill>}>
    <div className="ledger-filterbar"><label><MagnifyingGlass size={16} /><input aria-label="Search Ledger" placeholder="Reference, actor or destination" value={query} onChange={(event) => setQuery(event.target.value)} /></label><FarmSelect size="compact" label="Type" value={type} options={[{ value: "all", label: "All types" }, ...Array.from(new Set(data.map((entry) => entry.type))).map((value) => ({ value, label: value.replaceAll("_", " ") }))]} onChange={setType} /><FarmSelect size="compact" label="Status" value={status} options={[{ value: "all", label: "All states" }, ...Array.from(new Set(data.map((entry) => entry.status))).map((value) => ({ value, label: value }))]} onChange={setStatus} /><FarmSelect size="compact" label="Direction" value={direction} options={[{ value: "all", label: "All movements" }, { value: "credit", label: "Credits" }, { value: "debit", label: "Debits" }, { value: "reserve", label: "Reserves" }, { value: "release", label: "Releases" }]} onChange={setDirection} /></div>
    <div className="domain-two-column ledger-layout"><DetailCard eyebrow="Audit entries" title={`${filtered.length} matching movements`}><div className="ledger-entry-list">{filtered.map((entry) => <button type="button" className={selected?.id === entry.id ? "is-selected" : ""} key={entry.id} onClick={() => setParams({ transaction: entry.id })}><Receipt size={20} /><span><strong>{entry.actor}</strong><small>{entry.id.toUpperCase()} · {entry.type.replaceAll("_", " ")} · {entry.at}</small></span><b>{entry.status}</b><em data-direction={entry.direction}>{entry.direction === "debit" ? "−" : entry.direction === "reserve" ? "↳" : "+"}{money(entry.amount)}</em></button>)}</div>{!filtered.length ? <div className="inline-empty"><Funnel size={21} />No Ledger entries match these filters.</div> : null}</DetailCard>{selected ? <div className="domain-card-stack"><DetailCard eyebrow="Selected transaction" title={selected.id.toUpperCase()}><FactList facts={[{ label: "Type", value: selected.type.replaceAll("_", " ") }, { label: "Status", value: selected.status }, { label: "Movement", value: selected.direction }, { label: "Amount", value: money(selected.amount) }, { label: "Balance after", value: money(selected.balanceAfter) }, { label: "Actor", value: selected.actor }, { label: "Idempotency key", value: selected.idempotencyKey }]} /></DetailCard><DetailCard eyebrow="Movement" title="Source to destination"><div className="ledger-route"><span>{selected.source}</span><ArrowSquareOut size={18} /><strong>{selected.destination}</strong></div>{selected.linkedId ? <p className="domain-muted">Linked record · {selected.linkedId.toUpperCase()}</p> : null}{canOpen ? <button type="button" className="company-inline-link" onClick={() => openLinked(selected)}>Open Linked Record<ArrowSquareOut size={15} /></button> : null}</DetailCard><div className="ledger-immutable-note"><ShieldCheck size={20} /><span><strong>Immutable record</strong><small>Corrections create compensating entries; this transaction cannot be edited or deleted.</small></span></div></div> : null}</div>
  </DeepViewShell>;
}
