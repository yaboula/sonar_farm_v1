import { CaretRight, EnvelopeSimple, UserCircle, UserPlus, Warning } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ConfirmDialog } from "../../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../../components/DeepViewShell";
import { FarmSelect } from "../../components/FarmSelect";
import { StatePanel } from "../../components/StatePanel";
import type { FarmRole, StaffData } from "../../types";
import { useCompanyData } from "./useCompanyData";

export function StaffView() {
  const request = useMemo(() => ({ kind: "companyStaff" } as const), []);
  const { model, data, notice, pending, act, context } = useCompanyData<StaffData>(request);
  const navigate = useNavigate();
  const [inviteOpen, setInviteOpen] = useState(false);
  const [candidateId, setCandidateId] = useState("actor-cameron");
  const [role, setRole] = useState<FarmRole>("worker");
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  const pendingApplications = data.applications.filter((item) => ["submitted", "under_review", "interview"].includes(item.status)).length;
  const invite = async () => { const result = await act({ type: "staff.invite", candidateId, role }); if (result.ok) setInviteOpen(false); };
  return <DeepViewShell eyebrow="Employment authority" title="Staff" subtitle="Roles, custody and unresolved obligations stay visible before employment changes" breadcrumb={["Company", "Staff"]} backLabel="Back to Company" onBack={() => navigate("/company")} status={<StatusPill tone={pendingApplications ? "warning" : "success"}>{pendingApplications ? `${pendingApplications} Applications` : "Current"}</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{data.members.filter((item) => item.status === "active").length} active members</span><p>{data.invitations.filter((item) => item.status === "pending").length} pending invitations</p></div><div className="domain-action-group">{context.capabilities.reviewApplications ? <button type="button" className="domain-secondary-action" onClick={() => navigate("/company/applications")}>Review Applications</button> : null}{context.capabilities.inviteStaff ? <button type="button" className="domain-primary-action" onClick={() => setInviteOpen(true)}><UserPlus size={18} />Invite Player</button> : null}</div></>}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    <div className="domain-two-column company-staff-layout"><DetailCard eyebrow="Employment register" title={`${data.members.length} Staff members`}><div className="company-staff-list">{data.members.map((member) => <button type="button" key={member.id} onClick={() => navigate(`/company/staff/${member.id}`)}><UserCircle size={25} /><span><strong>{member.name}</strong><small>{member.role} · Joined {member.joinedAt}</small></span><div>{member.activeAssignment ? <em>{member.activeAssignment}</em> : <em>No active Assignment</em>}{member.unresolvedIssues.length ? <b><Warning size={13} />{member.unresolvedIssues.length} issue</b> : null}</div><i data-status={member.status}>{member.status.replace("_", " ")}</i><CaretRight size={16} /></button>)}</div></DetailCard><div className="domain-card-stack"><DetailCard eyebrow="Hiring queue" title={`${pendingApplications} requiring attention`}><FactList facts={[{ label: "Submitted", value: data.applications.filter((item) => item.status === "submitted").length }, { label: "Under review", value: data.applications.filter((item) => item.status === "under_review").length }, { label: "Interview", value: data.applications.filter((item) => item.status === "interview").length }]} /><button type="button" className="company-inline-link" onClick={() => navigate("/company/applications")}>Open Applications<CaretRight size={16} /></button></DetailCard><DetailCard eyebrow="Invitations" title={`${data.invitations.filter((item) => item.status === "pending").length} awaiting response`}><div className="company-mini-list">{data.invitations.length ? data.invitations.map((item) => <span key={item.id}><EnvelopeSimple size={18} /><strong>{item.candidate}</strong><small>{item.role} · {item.status}</small></span>) : <p>No pending Staff invitations.</p>}</div></DetailCard></div></div>
    {inviteOpen ? <ConfirmDialog eyebrow="Staff invitation" title="Invite this player to the company?" confirmLabel="Send Invitation" pending={pending} onClose={() => setInviteOpen(false)} onConfirm={() => void invite()}><FarmSelect label="Eligible Player" value={candidateId} options={data.candidates.map((item) => ({ value: item.id, label: item.name, description: item.eligible ? "Eligible" : item.reason }))} onChange={setCandidateId} /><FarmSelect label="Initial Role" value={role} options={data.assignableRoles.map((item) => ({ value: item, label: item, description: item === "worker" ? "Standard onboarding" : "Elevated authority" }))} onChange={(value) => setRole(value as FarmRole)} /><p>The player must accept before Staff access is granted.</p></ConfirmDialog> : null}
  </DeepViewShell>;
}
