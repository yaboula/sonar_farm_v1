import { ArrowRight, Bank, Coins, HandCoins, LockKey, Receipt, TrendUp } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ConfirmDialog } from "../../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../../components/DeepViewShell";
import { StatePanel } from "../../components/StatePanel";
import type { TreasurySnapshot } from "../../types";
import { useCompanyData } from "./useCompanyData";

const money = (value: number) => `$${value.toLocaleString()}`;

export function TreasuryView() {
  const request = useMemo(() => ({ kind: "companyTreasury" } as const), []);
  const { model, data, notice, pending, act, context } = useCompanyData<TreasurySnapshot>(request);
  const navigate = useNavigate();
  const [amount, setAmount] = useState(1000);
  const [contributeOpen, setContributeOpen] = useState(false);
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  const committed = data.escrowReserved + data.assignmentPayReserved + data.leaseObligations;
  const contribute = async () => {
    const result = await act({ type: "treasury.contribute", amount });
    if (result.ok) setContributeOpen(false);
  };
  return <DeepViewShell eyebrow="Company financial authority" title="Treasury" subtitle="Available cash, committed obligations and pending income are kept separate" breadcrumb={["Company", "Treasury"]} backLabel="Back to Company" onBack={() => navigate("/company")} status={<StatusPill tone={data.available > committed ? "success" : "warning"}>{money(data.available)} Available</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{money(committed)} committed</span><p>{money(data.pendingBuyerIncome)} pending Buyer income</p></div><div className="domain-action-group"><button type="button" className="domain-secondary-action" onClick={() => navigate("/company/ledger")}><Receipt size={18} />Open Ledger</button>{data.availableActions.includes("contribute") ? <button type="button" className="domain-primary-action" onClick={() => setContributeOpen(true)}><HandCoins size={18} />Contribute Funds</button> : null}</div></>}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    <div className="treasury-balance-grid"><article className="is-primary"><Bank size={24} /><span><small>Available balance</small><strong>{money(data.available)}</strong><em>Spendable by authorized flows</em></span></article><article><LockKey size={23} /><span><small>Escrow</small><strong>{money(data.escrowReserved)}</strong><em>Public Contracts protected</em></span></article><article><Coins size={23} /><span><small>Assignment pay</small><strong>{money(data.assignmentPayReserved)}</strong><em>Release after validation</em></span></article><article><TrendUp size={23} /><span><small>Pending income</small><strong>{money(data.pendingBuyerIncome)}</strong><em>Not yet available</em></span></article></div>
    <div className="domain-two-column treasury-layout"><DetailCard eyebrow="Obligations" title="Cash commitments"><FactList facts={[{ label: "Contract escrow", value: money(data.escrowReserved) }, { label: "Assignment payouts", value: money(data.assignmentPayReserved) }, { label: "Lease obligations", value: money(data.leaseObligations) }, { label: "Total committed", value: money(committed) }]} /><div className="treasury-boundary"><LockKey size={20} /><span><strong>No free withdrawals</strong><small>Treasury funds leave only through audited Company systems.</small></span></div></DetailCard><DetailCard eyebrow="Reference, not cash" title="Warehouse valuation"><p className="treasury-valuation">{money(data.warehouseValuation)}</p><p className="domain-muted">Estimated business asset value. It is never added to the available Treasury balance.</p>{data.personalBalance !== undefined ? <FactList facts={[{ label: "Owner personal balance", value: money(data.personalBalance) }, { label: "Contribution location", value: "Office Terminal" }, { label: "Current presence", value: context.presence }]} /> : null}</DetailCard></div>
    <DetailCard eyebrow="Audit trail" title="Recent Treasury movements"><div className="ledger-compact-list">{data.recentEntries.map((entry) => <button type="button" key={entry.id} onClick={() => navigate(`/company/ledger?transaction=${entry.id}`)}><Receipt size={18} /><span><strong>{entry.actor}</strong><small>{entry.type.replaceAll("_", " ")} · {entry.at}</small></span><em data-direction={entry.direction}>{entry.direction === "debit" ? "−" : "+"}{money(entry.amount)}</em><ArrowRight size={15} /></button>)}</div></DetailCard>
    {contributeOpen ? <ConfirmDialog eyebrow="Owner contribution" title="Add personal funds to Treasury?" confirmLabel="Confirm Contribution" pending={pending} onClose={() => setContributeOpen(false)} onConfirm={() => void contribute()}><div className="treasury-contribution-review"><label className="company-number-field"><span>Contribution amount</span><input autoFocus type="number" min="1" max={data.personalBalance} step="100" value={amount} onChange={(event) => setAmount(Math.max(1, Math.floor(Number(event.target.value) || 1)))} /><small>Personal funds available · {money(data.personalBalance ?? 0)}</small></label><FactList facts={[{ label: "Personal balance after", value: money((data.personalBalance ?? 0) - amount) }, { label: "Treasury after", value: money(data.available + amount) }, { label: "Active sale listing", value: "Material change triggers revalidation" }]} /></div></ConfirmDialog> : null}
  </DeepViewShell>;
}
