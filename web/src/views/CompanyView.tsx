import {
  Bank,
  Buildings,
  CaretRight,
  HouseLine,
  IdentificationCard,
  Package,
  ShieldCheck,
  ShoppingCartSimple,
  UsersThree,
  Warehouse,
} from "@phosphor-icons/react";
import { HubScaffold } from "../components/HubScaffold";
import { StatePanel } from "../components/StatePanel";
import { COMPANY_MODULES } from "../data/fixtures";
import { useHub } from "../store/HubContext";

const ICONS = {
  cargo: Package,
  warehouse: Warehouse,
  staff: UsersThree,
  treasury: Bank,
  leases: HouseLine,
  procurement: ShoppingCartSimple,
  permissions: ShieldCheck,
  identity: IdentificationCard,
};

export function CompanyView() {
  const { capabilities, viewState, selectedId, select, setViewState } = useHub();
  const visible = COMPANY_MODULES.filter((module) => {
    if (!module.permission) return true;
    return Boolean(capabilities[module.permission]);
  });
  const selected = visible.find((module) => module.id === selectedId) ?? visible[0];

  if (viewState !== "ready") {
    return <StatePanel state={viewState} onAction={() => setViewState("ready")} />;
  }

  const aside = selected ? (
    <div className="detail-inspector company-inspector">
      <span className="inspector-kicker">Company module</span>
      <Buildings size={38} weight="thin" />
      <h2>{selected.title}</h2>
      <p>{selected.detail}</p>
      <div className="company-value">{selected.value}</div>
      <div className="inspector-rule" />
      <p className="inspector-description">
        This overview exposes only information allowed by the current role and surface.
      </p>
      <button type="button" className="inspector-action" onClick={() => select("companyModule", selected.id)}>
        Keep selected
        <CaretRight size={18} />
      </button>
    </div>
  ) : null;

  return (
    <HubScaffold
      eyebrow="Business administration"
      title="Company"
      subtitle="Operational ownership, staff, assets and obligations without vanity metrics."
      aside={aside}
    >
      <div className="company-grid">
        {visible.map((module) => {
          const Icon = ICONS[module.id as keyof typeof ICONS] ?? Buildings;
          return (
            <button
              type="button"
              className={selected?.id === module.id ? "company-card is-selected" : "company-card"}
              key={module.id}
              onClick={() => select("companyModule", module.id)}
            >
              <Icon size={31} weight="thin" />
              <div>
                <span>{module.title}</span>
                <small>{module.detail}</small>
              </div>
              <strong>{module.value}</strong>
              <CaretRight className="company-caret" size={18} />
            </button>
          );
        })}
      </div>
    </HubScaffold>
  );
}
