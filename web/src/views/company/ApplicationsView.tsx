import { CaretRight, Clock, UserCircle, UsersThree, Warning } from "@phosphor-icons/react";
import { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import { DeepViewShell, DetailCard, StatusPill } from "../../components/DeepViewShell";
import { StatePanel } from "../../components/StatePanel";
import type { StaffApplication } from "../../types";
import { useCompanyData } from "./useCompanyData";

export function ApplicationsView() {
  const request = useMemo(() => ({ kind: "companyApplications" } as const), []);
  const { model, data } = useCompanyData<StaffApplication[]>(request);
  const navigate = useNavigate();
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  const active = data.filter((item) => ["submitted", "under_review", "interview"].includes(item.status));
  return <DeepViewShell eyebrow="Hiring queue" title="Applications" subtitle="Persistent applications with one active record per character" breadcrumb={["Company", "Staff", "Applications"]} backLabel="Back to Staff" onBack={() => navigate("/company/staff")} status={<StatusPill tone={active.length ? "warning" : "success"}>{active.length} Active</StatusPill>}>
    <DetailCard eyebrow="Review queue" title={`${data.length} application records`}><div className="company-application-list">{data.map((application) => <button type="button" key={application.id} onClick={() => navigate(`/company/applications/${application.id}`)}><UserCircle size={25} /><span><strong>{application.applicant}</strong><small>{application.preferredWork} · {application.submittedAt ?? "Draft"}</small></span>{application.warning ? <b><Warning size={14} />History note</b> : null}<em data-status={application.status}>{application.status.replace("_", " ")}</em><CaretRight size={17} /></button>)}</div>{!data.length ? <div className="inline-empty"><UsersThree size={22} />No Job Applications have been submitted.</div> : null}</DetailCard>
    <div className="company-application-policy"><Clock size={20} /><span><strong>Application policy</strong><small>Only farming-relevant identity, availability and public contract history are included.</small></span></div>
  </DeepViewShell>;
}
