import { Leaf, MapTrifold, Warning } from "@phosphor-icons/react";
import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate, useParams } from "react-router-dom";
import { fixtureHubAdapter } from "../adapters/FixtureHubAdapter";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../components/DeepViewShell";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { FieldDetail, HubContextModel, HubViewModel } from "../types";

export function FieldDetailView() {
  const { fieldId = "" } = useParams();
  const hub = useHub();
  const navigate = useNavigate();
  const location = useLocation();
  const returnTo = (location.state as { returnTo?: string } | null)?.returnTo ?? `/fields?focus=${fieldId}`;
  const context = useMemo<HubContextModel>(() => ({ role: hub.role, surface: hub.surface, viewState: hub.viewState, capabilities: hub.capabilities }), [hub.role, hub.surface, hub.viewState, hub.capabilities]);
  const [model, setModel] = useState<HubViewModel<FieldDetail> | null>(null);

  useEffect(() => {
    let active = true;
    void fixtureHubAdapter.load<FieldDetail>({ kind: "fieldDetail", fieldId }, context).then((next) => {
      if (active) setModel(next);
    });
    return () => { active = false; };
  }, [context, fieldId]);

  if (!model) return <StatePanel state="loading" />;
  if (model.state !== "ready") return <StatePanel state={model.state} onAction={() => navigate(returnTo)} />;
  if (!model.data) return <StatePanel state="empty" onAction={() => navigate(returnTo)} />;
  const field = model.data;
  const tone = field.criticalCount ? "danger" : field.status === "ready" ? "success" : "active";

  return (
    <DeepViewShell
      eyebrow="Field operating record"
      title={field.name}
      subtitle={`${field.location} · ${field.cropSummary}`}
      breadcrumb={["Fields", field.name]}
      backLabel="Back to Fields"
      onBack={() => navigate(returnTo)}
      status={<StatusPill tone={tone}>{field.statusLabel}</StatusPill>}
    >
      <div className="domain-two-column">
        <div className="domain-card-stack">
          <DetailCard eyebrow="Operating scope" title="Field identity">
            <FactList facts={[
              { label: "Land", value: field.ownership },
              { label: "Capacity", value: `${field.occupied + field.planned} / ${field.capacity} committed` },
              { label: "Next milestone", value: field.nextMilestone },
              { label: "Topology", value: field.topology.topologyRevision },
            ]} />
          </DetailCard>
          <DetailCard eyebrow="Attention" title="Current operating signal">
            <div className="domain-emphasis"><Warning size={24} />{field.criticalCount ? `${field.criticalCount} critical condition${field.criticalCount === 1 ? "" : "s"}` : "No critical exceptions"}</div>
            {field.diagnostics.slice(0, 3).map((item) => <p key={item.id}>{item.title} · {item.window}</p>)}
          </DetailCard>
        </div>
        <aside className="domain-card-stack">
          <DetailCard eyebrow="Spatial inventory" title={`${field.topology.rows.length} stable Rows`}>
            <div className="domain-emphasis"><MapTrifold size={25} />{field.topology.slots.length} authoritative slots</div>
          </DetailCard>
          <DetailCard eyebrow="Crop state" title={field.cropSummary}>
            <div className="domain-emphasis"><Leaf size={25} />{field.nextMilestone}</div>
          </DetailCard>
        </aside>
      </div>
    </DeepViewShell>
  );
}
