import { Buildings, CheckCircle, Clock, Coins, IdentificationCard, Warning } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ConfirmDialog } from "../../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../../components/DeepViewShell";
import { StatePanel } from "../../components/StatePanel";
import type { CompanyIdentityTerms } from "../../types";
import { useCompanyData } from "./useCompanyData";

export function CompanyIdentityView() {
  const request = useMemo(() => ({ kind: "companyIdentity" } as const), []);
  const { model, data, notice, pending, act, context } = useCompanyData<CompanyIdentityTerms>(request);
  const navigate = useNavigate();
  const [draftName, setDraftName] = useState<string>();
  const [confirmOpen, setConfirmOpen] = useState(false);
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  const name = draftName ?? data.currentName;
  const valid = name.trim() !== data.currentName && name.trim().length >= 3 && name.trim().length <= 28 && /^[A-Za-z0-9 '-]+$/.test(name.trim());
  const rename = async () => { const result = await act({ type: "company.rename", name }); if (result.ok) { setDraftName(undefined); setConfirmOpen(false); } };
  return <DeepViewShell eyebrow="Owner identity authority" title="Company Identity" subtitle="Sonar Farm remains the system brand; only the player-operated company name can change" breadcrumb={["Company", "Company Identity"]} backLabel="Back to Company" onBack={() => navigate("/company")} status={<StatusPill tone={data.available ? "success" : "warning"}>{data.available ? "Rename Available" : "Cooldown Active"}</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{data.currentName}</span><p>{data.available ? `$${data.renameCost.toLocaleString("en-US")} Registry fee` : `Available ${data.cooldownEndsAt}`}</p></div><div className="domain-action-group"><button type="button" className="domain-primary-action" disabled={!data.available || !valid} onClick={() => setConfirmOpen(true)}><IdentificationCard size={18} />Review Rename</button></div></>}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    <div className="company-identity-banner"><span><small>System brand</small><strong>Sonar Farm</strong><em>Interface, product and service identity</em></span><i>≠</i><span><small>Player company</small><strong>{data.currentName}</strong><em>Business name shown in contracts and records</em></span></div>
    <div className="domain-two-column identity-layout"><DetailCard eyebrow="Registered name" title="Rename the company"><label className="company-text-field"><span>New Company name</span><input disabled={!data.available} maxLength={28} value={name} onChange={(event) => setDraftName(event.target.value)} /><small>{name.trim().length} / 28 characters</small></label><ul className="domain-check-list">{data.namingRules.map((rule) => <li key={rule}><CheckCircle size={17} />{rule}</li>)}</ul>{!valid && name !== data.currentName ? <p className="identity-validation"><Warning size={16} />The proposed name does not satisfy every Registry rule or has not changed.</p> : null}</DetailCard><div className="domain-card-stack"><DetailCard eyebrow="Registry terms" title="Cost and cooldown"><FactList facts={[{ label: "Rename fee", value: `$${data.renameCost.toLocaleString("en-US")}` }, { label: "Paid by", value: "Company Treasury" }, { label: "Required terminal", value: "Office" }, { label: "Current presence", value: context.presence }, { label: "Last rename", value: data.lastRenamedAt ?? "Never" }, { label: "Cooldown ends", value: data.cooldownEndsAt ?? "No active cooldown" }]} /></DetailCard><DetailCard eyebrow="Immutable origin" title={data.originalName}><p className="domain-emphasis"><Buildings size={23} />The original registered identity remains in the audit history after every rename.</p></DetailCard></div></div>
    {confirmOpen ? <ConfirmDialog eyebrow="Registry review" title={`Rename to ${name.trim()}?`} confirmLabel="Confirm Rename" pending={pending} onClose={() => setConfirmOpen(false)} onConfirm={() => void rename()}><FactList facts={[{ label: "Current name", value: data.currentName }, { label: "New name", value: name.trim() }, { label: "Treasury fee", value: `$${data.renameCost.toLocaleString("en-US")}` }, { label: "Cooldown", value: "7 days" }, { label: "Sale listing", value: "Material change requires revalidation" }]} /><p><Coins size={17} /> The Registry fee and Ledger entry are committed together. <Clock size={17} /> The new cooldown starts immediately.</p></ConfirmDialog> : null}
  </DeepViewShell>;
}
