import {
  CaretRight,
  Package,
  ShoppingCartSimple,
  Tag,
  Toolbox,
} from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { HubScaffold } from "../components/HubScaffold";
import { StatePanel } from "../components/StatePanel";
import { SUPPLIES } from "../data/fixtures";
import { useHub } from "../store/HubContext";

type SupplyTab = "market" | "procurement" | "issued";

export function SuppliesView() {
  const { capabilities, viewState, selectedId, select, setViewState } = useHub();
  const [tab, setTab] = useState<SupplyTab>("market");
  const tabs: SupplyTab[] = capabilities.companyProcurement
    ? ["market", "procurement", "issued"]
    : ["market", "issued"];
  const visible = useMemo(() => {
    if (tab === "issued") return SUPPLIES.filter((item) => item.category === "Issued Materials");
    if (tab === "procurement") return SUPPLIES.filter((item) => item.ownership === "Supplier");
    return SUPPLIES.filter((item) => item.category !== "Issued Materials");
  }, [tab]);
  const selected = SUPPLIES.find((item) => item.id === selectedId) ?? visible[0];

  if (viewState !== "ready") {
    return <StatePanel state={viewState} onAction={() => setViewState("ready")} />;
  }

  const toolbar = (
    <div className="hub-tabs" role="tablist" aria-label="Supply area">
      {tabs.map((item) => (
        <button
          type="button"
          role="tab"
          aria-selected={tab === item}
          className={tab === item ? "is-selected" : ""}
          key={item}
          onClick={() => setTab(item)}
        >
          {item === "market" ? "Supply Market" : item === "procurement" ? "Procurement" : "Issued Materials"}
        </button>
      ))}
    </div>
  );

  const aside = selected ? (
    <div className="detail-inspector supply-inspector">
      <span className="inspector-kicker">Item selected</span>
      <Toolbox size={38} weight="thin" />
      <h2>{selected.name}</h2>
      <p>{selected.detail}</p>
      <div className="inspector-rule" />
      <dl>
        <div><dt>Category</dt><dd>{selected.category}</dd></div>
        <div><dt>Stock</dt><dd>{selected.stock}</dd></div>
        <div><dt>Ownership</dt><dd>{selected.ownership}</dd></div>
        <div><dt>Price / ID</dt><dd>{selected.price}</dd></div>
      </dl>
      <div className="physical-note">
        <Package size={19} />
        {capabilities.physicalTransactions
          ? "Physical collection is available at this terminal."
          : "Complete physical collection from an Office Terminal."}
      </div>
      <button type="button" className="inspector-action" onClick={() => select("supply", selected.id)}>
        Keep selected
        <CaretRight size={18} />
      </button>
    </div>
  ) : null;

  return (
    <HubScaffold
      eyebrow="Materials & tools"
      title="Supplies"
      subtitle="Know who owns an item, where it comes from and what can happen next."
      toolbar={toolbar}
      aside={aside}
    >
      <div className="supply-grid">
        {visible.map((item) => (
          <button
            type="button"
            className={selected?.id === item.id ? "supply-card is-selected" : "supply-card"}
            key={item.id}
            onClick={() => select("supply", item.id)}
          >
            <div className="supply-card-head">
              {item.category === "Issued Materials" ? <Toolbox size={30} /> : <ShoppingCartSimple size={30} />}
              <span>{item.ownership}</span>
            </div>
            <h2>{item.name}</h2>
            <p>{item.detail}</p>
            <div className="supply-meta">
              <span><Package size={16} /> {item.stock}</span>
              <strong><Tag size={16} /> {item.price}</strong>
            </div>
          </button>
        ))}
      </div>
    </HubScaffold>
  );
}
