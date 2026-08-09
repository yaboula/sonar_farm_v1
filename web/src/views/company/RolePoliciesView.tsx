import { Check, LockKey, ShieldCheck, UsersThree, Warning } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ConfirmDialog } from "../../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../../components/DeepViewShell";
import { StatePanel } from "../../components/StatePanel";
import type { FarmRole, RolePolicy } from "../../types";
import { useCompanyData } from "./useCompanyData";

export function RolePoliciesView() {
  const request = useMemo(() => ({ kind: "companyRolePolicies" } as const), []);
  const { model, data, notice, pending, act } = useCompanyData<RolePolicy[]>(request);
  const navigate = useNavigate();
  const [role, setRole] = useState<FarmRole>("worker");
  const [permissionDrafts, setPermissionDrafts] = useState<Partial<Record<FarmRole, string[]>>>({});
  const [limitDrafts, setLimitDrafts] = useState<Partial<Record<FarmRole, number | undefined>>>({});
  const [confirm, setConfirm] = useState<"save" | "reset">();
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  const policy = data.find((item) => item.role === role) ?? data[0];
  const enabled = permissionDrafts[policy.role] ?? policy.permissions.filter((item) => item.enabled).map((item) => item.id);
  const transactionLimit = Object.prototype.hasOwnProperty.call(limitDrafts, policy.role) ? limitDrafts[policy.role] : policy.transactionLimit;
  const protectedPolicy = policy.role === "owner";
  const toggle = (permissionId: string, locked?: boolean) => {
    if (locked || protectedPolicy) return;
    setPermissionDrafts((current) => ({ ...current, [policy.role]: enabled.includes(permissionId) ? enabled.filter((id) => id !== permissionId) : [...enabled, permissionId] }));
  };
  const submit = async () => {
    const result = confirm === "save"
      ? await act({ type: "rolePolicy.save", role: policy.role, permissions: enabled, transactionLimit })
      : await act({ type: "rolePolicy.reset", role: policy.role });
    if (result.ok) { setPermissionDrafts((current) => ({ ...current, [policy.role]: undefined })); setLimitDrafts((current) => ({ ...current, [policy.role]: undefined })); }
    setConfirm(undefined);
  };
  return <DeepViewShell eyebrow="Owner governance" title="Roles & Permissions" subtitle="Role templates define authority; individual exceptions remain explicit and audited on Staff records" breadcrumb={["Company", "Roles & Permissions"]} backLabel="Back to Company" onBack={() => navigate("/company")} status={<StatusPill tone="success">Revision {data.reduce((sum, item) => sum + item.pendingChanges, 1)}</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{policy.role} template</span><p>{policy.memberCount} active member{policy.memberCount === 1 ? "" : "s"} affected after revalidation</p></div><div className="domain-action-group">{!protectedPolicy ? <><button type="button" className="domain-secondary-action" onClick={() => setConfirm("reset")}>Restore Defaults</button><button type="button" className="domain-primary-action" disabled={!enabled.length} onClick={() => setConfirm("save")}><ShieldCheck size={18} />Save Policy</button></> : null}</div></>}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    <div className="role-policy-layout"><nav className="role-policy-rail" aria-label="Role templates">{data.map((item) => <button type="button" className={item.role === policy.role ? "is-selected" : ""} key={item.role} onClick={() => setRole(item.role)}><UsersThree size={19} /><span><strong>{item.role}</strong><small>{item.memberCount} members · {item.permissions.filter((permission) => permission.enabled).length} permissions</small></span>{item.role === "owner" ? <LockKey size={14} /> : null}</button>)}</nav><div className="domain-card-stack"><DetailCard eyebrow={`${policy.role} authority`} title="Permission template"><div className="role-permission-list">{policy.permissions.map((permission) => { const active = enabled.includes(permission.id); return <button type="button" role="checkbox" aria-checked={active} disabled={permission.locked || protectedPolicy} className={active ? "is-enabled" : ""} key={permission.id} onClick={() => toggle(permission.id, permission.locked)}><i>{active ? <Check size={13} weight="bold" /> : null}</i><span><strong>{permission.label}</strong><small>{permission.group} · {permission.locked ? "Non-editable protection" : "Template permission"}</small></span>{permission.locked ? <LockKey size={15} /> : null}</button>; })}</div></DetailCard>{policy.transactionLimit !== undefined ? <DetailCard eyebrow="Financial boundary" title="Per-transaction limit"><label className="company-number-field"><span>Maximum Company spend</span><input disabled={protectedPolicy} type="number" min="0" step="100" value={transactionLimit ?? 0} onChange={(event) => setLimitDrafts((current) => ({ ...current, [policy.role]: Math.max(0, Math.floor(Number(event.target.value) || 0)) }))} /><small>This limit does not grant purchase permission by itself.</small></label></DetailCard> : null}</div><div className="domain-card-stack"><DetailCard eyebrow="Access model" title="Enforcement boundaries"><FactList facts={[{ label: "Navigation", value: "Unauthorized views removed" }, { label: "Remote actions", value: "Capability controlled" }, { label: "Physical actions", value: "Presence revalidated" }, { label: "Open sessions", value: "Reload on revision" }, { label: "Owner transfer", value: "Protected workflow only" }]} /></DetailCard><div className="role-policy-warning"><Warning size={20} /><span><strong>Permission loss is immediate</strong><small>An open restricted view reloads and closes its actionable state as soon as this policy is saved.</small></span></div></div></div>
    {confirm ? <ConfirmDialog eyebrow="Policy revision" title={confirm === "save" ? `Apply the ${policy.role} policy?` : `Restore ${policy.role} defaults?`} confirmLabel={confirm === "save" ? "Apply Policy" : "Restore Defaults"} tone={confirm === "reset" ? "danger-confirm" : "confirm"} pending={pending} onClose={() => setConfirm(undefined)} onConfirm={() => void submit()}><FactList facts={[{ label: "Affected members", value: policy.memberCount }, { label: "Enabled permissions", value: enabled.length }, { label: "Transaction limit", value: transactionLimit === undefined ? "Not applicable" : `$${transactionLimit.toLocaleString()}` }, { label: "Audit effect", value: "Capabilities revision increments" }]} /><p>Current sessions using this role are revalidated before their next render or action.</p></ConfirmDialog> : null}
  </DeepViewShell>;
}
