import { Archive, CaretRight, MagnifyingGlass, Minus, Package, Plus, ShoppingCartSimple, Tag, Toolbox, Warning } from "@phosphor-icons/react";
import { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { FarmSelect } from "../components/FarmSelect";
import { HubScaffold } from "../components/HubScaffold";
import { StatePanel } from "../components/StatePanel";
import { useHub } from "../store/HubContext";
import type { HubContextModel, HubViewModel, IssuedMaterialRecord, SuppliesHubData } from "../types";

type SupplyTab = "market" | "procurement" | "issued";
const categoryOptions = ["All", "Seedlings", "Seeds", "Hand Tools", "Watering", "Fertilizer", "Pest Treatment"].map((value) => ({ value, label: value }));

export function SuppliesView() {
  const hub = useHub(); const navigate = useNavigate(); const [searchParams, setSearchParams] = useSearchParams();
  const context = useMemo<HubContextModel>(() => ({ actorId: hub.actorId, role: hub.role, surface: hub.surface, presence: hub.presence, capabilitiesRevision: hub.capabilitiesRevision, viewState: hub.viewState, capabilities: hub.capabilities }), [hub.actorId, hub.role, hub.surface, hub.presence, hub.capabilitiesRevision, hub.viewState, hub.capabilities]);
  const [model, setModel] = useState<HubViewModel<SuppliesHubData> | null>(null); const [query, setQuery] = useState(""); const [category, setCategory] = useState("All"); const [cart, setCart] = useState<Record<string, number>>({}); const [notice, setNotice] = useState<string>(); const [pending, setPending] = useState(false); const [materialAction, setMaterialAction] = useState<{ item: IssuedMaterialRecord; action: "return" | "flag" }>();
  const contextKey = `${hub.role}:${hub.surface}:${hub.viewState}`;
  const [loadedFor, setLoadedFor] = useState("");
  const returnOperations = useRef<Record<string, string>>({});
  const reload = async () => { const next = await hub.adapter.load<SuppliesHubData>({ kind: "hub", route: "supplies" }, context); setModel(next); setLoadedFor(contextKey); };
  useEffect(() => { let active = true; void hub.adapter.load<SuppliesHubData>({ kind: "hub", route: "supplies" }, context).then((next) => { if (active) { setModel(next); setLoadedFor(contextKey); } }); return () => { active = false; }; }, [context, contextKey, hub.adapter]);
  if (!model || loadedFor !== contextKey) return <StatePanel state="loading" />;
  if (model.state !== "ready") return <StatePanel state={model.state} onAction={() => hub.setViewState("ready")} />;
  const data = model.data; if (!data) return <StatePanel state="restricted" />;
  const availableTabs: SupplyTab[] = ["market"];
  const requested = searchParams.get("area") as SupplyTab | null; const tab = requested && availableTabs.includes(requested) ? requested : "market";
  const products = data.products.filter((item) => (category === "All" || item.category === category) && `${item.name} ${item.category} ${item.cropRelation}`.toLowerCase().includes(query.toLowerCase()));
  const cartLines = Object.entries(cart).filter(([, quantity]) => quantity > 0).map(([productId, quantity]) => ({ product: data.products.find((item) => item.id === productId)!, quantity })).filter((line) => line.product);
  const cartTotal = cartLines.reduce((sum, line) => sum + line.quantity * line.product.unitPrice, 0);
  const visibleCartLines = cartLines.slice(0, 4);
  const hiddenCartLines = Math.max(0, cartLines.length - visibleCartLines.length);

  const adjust = (id: string, delta: number) => setCart((current) => ({ ...current, [id]: Math.max(0, Math.min(99, (current[id] ?? 0) + delta)) }));
  const reviewPurchase = async () => {
    setPending(true); const result = await hub.adapter.dispatch({ type: "purchase.createDraft", payer: "company", lines: cartLines.map((line) => ({ productId: line.product.id, quantity: line.quantity })) }, context); setPending(false); setNotice(result.message); if (result.ok && result.entityId) navigate(`/supplies/purchases/${result.entityId}/review`, { state: { returnTo: "/supplies?area=market" } });
  };
  const resolveRequest = async (id: string, decision: "approve" | "reject") => { const result = await hub.adapter.dispatch({ type: "procurement.resolve", requestId: id, decision }, context); setNotice(result.message); if (result.changed) await reload(); };
  const resolveMaterial = async () => {
    if (!materialAction) return;
    const key = materialAction.item.id;
    const operationId = returnOperations.current[key] ?? (returnOperations.current[key] = globalThis.crypto.randomUUID());
    setPending(true);
    try {
      const result = await hub.adapter.dispatch({ type: "issuedMaterial.transition", materialId: key, action: materialAction.action, operationId }, context);
      delete returnOperations.current[key];
      setNotice(result.message); setMaterialAction(undefined); if (result.changed) await reload();
    } finally { setPending(false); }
  };

  const toolbar = <><div className="hub-tabs supply-tabs" role="tablist" aria-label="Supply area"><button type="button" role="tab" aria-selected={tab === "market"} className="is-selected" onClick={() => setSearchParams({ area: "market" })}>Supply Market</button><button type="button" role="tab" aria-selected="false" aria-label="Company Procurement — Coming Soon" disabled>Company Procurement<small>Coming Soon</small></button><button type="button" role="tab" aria-selected="false" aria-label="Issued Materials — Coming Soon" disabled>Issued Materials<small>Coming Soon</small></button></div>{tab === "market" ? <><label className="search-control"><MagnifyingGlass size={18} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search supplies" /></label><FarmSelect className="toolbar-select" size="compact" label="Category" value={category} options={categoryOptions} onChange={setCategory} /></> : null}</>;

  const cartAside = <div className="detail-inspector supply-inspector"><span className="inspector-kicker">Purchase draft</span><ShoppingCartSimple size={38} weight="thin" /><h2>{cartLines.length ? `${cartLines.length} line${cartLines.length === 1 ? "" : "s"}` : "Cart empty"}</h2><p>Company-owned on Warehouse delivery · fully audited</p><div className="supply-payer-summary"><span>Purchase payer</span><strong>Company Treasury</strong><small>Available ${data.companyBalance?.toLocaleString() ?? "0"}</small></div><div className="inspector-rule" />{cartLines.length ? <div className="mini-cart">{visibleCartLines.map((line) => <div key={line.product.id}><span className="mini-cart-quantity">{line.quantity}×</span><span className="mini-cart-name">{line.product.name}</span><strong>${(line.quantity * line.product.unitPrice).toLocaleString()}</strong></div>)}{hiddenCartLines ? <p className="mini-cart-more">+{hiddenCartLines} more selected item{hiddenCartLines === 1 ? "" : "s"}</p> : null}</div> : <p className="inspector-description">Choose quantities from the catalog. Stock and Treasury are revalidated at confirmation.</p>}<div className="supply-cart-total"><span>Subtotal</span><strong>${cartTotal.toLocaleString()}</strong></div><div className="physical-note"><Package size={19} /><span>{hub.capabilities.physicalTransactions ? "This terminal can confirm the order. Delivery remains delayed." : "Prepare here; confirm later at the Office Terminal."}</span></div><button type="button" className="inspector-action" disabled={!cartLines.length || pending} onClick={() => void reviewPurchase()}>Review Purchase<CaretRight size={18} /></button></div>;

  return <HubScaffold eyebrow="Materials & tools" title="Supplies" subtitle="Purchase, issue and account for every physical farming input." toolbar={toolbar} aside={tab === "market" ? cartAside : undefined}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    {tab === "market" ? <div className="supply-grid supply-market-grid">{products.length ? products.map((item) => {
      const quantity = cart[item.id] ?? 0;
      const soldOut = item.stock === 0;
      return <article className={quantity ? "supply-card is-selected" : "supply-card"} key={item.id}>
        <div className="supply-card-intro">
          <div className="supply-card-head">
            <span>{item.category}</span>
            <div className="supply-card-delivery"><small>{item.leadMinutes ?? 5}m ETA</small><span className="supply-card-tier" data-tier={item.tier}>{item.tier ?? "basic"}</span></div>
          </div>
          <div className="supply-card-title-row">
            <h2>{item.name}</h2>
            <div className="supply-card-visual">{item.image ? <img src={item.image} alt="" /> : <ShoppingCartSimple size={38} />}</div>
          </div>
        </div>
        <p>{item.detail}</p>
        <small className="supply-effect">{item.effect}</small>
        <small className="supply-crop">{item.cropRelation} · {item.applications ?? 1} application{item.applications === 1 ? "" : "s"}</small>
        <div className="supply-meta"><span><Package size={16} />{item.stock === "base" ? "Base stock" : soldOut ? "Sold out" : `${item.stock} available`}</span><strong><Tag size={16} />${item.unitPrice}</strong></div>
        <div className="supply-owned"><span>Warehouse {item.companyOwned}</span><small>{item.restock}</small></div>
        <div className="quantity-control"><button type="button" aria-label={`Remove ${item.name}`} disabled={!quantity} onClick={() => adjust(item.id, -1)}><Minus size={16} /></button><strong>{quantity}</strong><button type="button" aria-label={`Add ${item.name}`} disabled={soldOut || (item.stock !== "base" && quantity >= item.stock)} onClick={() => adjust(item.id, 1)}><Plus size={16} /></button></div>
      </article>;
    }) : <div className="inline-empty">No supplies match this catalog filter.</div>}</div> : null}
    {tab === "procurement" && data.procurement ? <div className="procurement-layout"><section className="procurement-summary"><span>Monthly purchasing authority</span><h2>${data.procurement.remaining.toLocaleString()} remaining</h2><div className="budget-track"><i style={{ width: `${Math.round(data.procurement.remaining / data.procurement.monthlyBudget * 100)}%` }} /></div><dl><div><dt>Monthly budget</dt><dd>${data.procurement.monthlyBudget.toLocaleString()}</dd></div><div><dt>Transaction limit</dt><dd>${data.procurement.transactionLimit.toLocaleString()}</dd></div><div><dt>Allowed categories</dt><dd>{data.procurement.allowedCategories.length}</dd></div></dl><button className="inspector-action" type="button" onClick={() => setSearchParams({ area: "market" })}>Open Company Market<CaretRight size={18} /></button></section><section className="procurement-requests"><header><div><span>Authorization queue</span><h2>Pending Requests</h2></div><strong>{data.procurement.requests.filter((item) => item.status === "pending").length}</strong></header>{data.procurement.requests.map((request) => <article key={request.id}><Archive size={24} /><div><strong>{request.summary}</strong><small>{request.id.toUpperCase()} · {request.requestedBy}</small></div><span>${request.amount}</span><em>{request.status}</em><button type="button" onClick={() => navigate(`/supplies/purchases/${request.id}/review`, { state: { returnTo: "/supplies?area=procurement" } })}>Review</button>{request.status === "pending" && hub.capabilities.approveProcurement ? <div><button type="button" onClick={() => void resolveRequest(request.id, "reject")}>Reject</button><button type="button" className="approve" onClick={() => void resolveRequest(request.id, "approve")}>Approve</button></div> : null}</article>)}{data.procurement.violations.length ? <div className="policy-note"><Warning size={19} /><span><strong>Policy attention</strong>{data.procurement.violations[0]}</span></div> : null}</section></div> : null}
    {tab === "issued" ? <div className="issued-list">{data.issuedMaterials.map((item) => <article key={item.id}><Toolbox size={28} /><div><strong>{item.asset}</strong><small>{item.assignment} · {item.worker}</small></div><dl><div><dt>Issued</dt><dd>{item.issued} {item.unit}</dd></div><div><dt>Used</dt><dd>{item.used}</dd></div><div><dt>Remaining</dt><dd>{item.remaining}</dd></div></dl><span className={`issued-status issued-status--${item.status}`}>{item.status.replace("_", " ")}</span><div className="issued-actions">{item.availableActions.map((action) => <button type="button" key={action} className={action === "flag" ? "danger" : ""} onClick={() => setMaterialAction({ item, action })}>{action === "return" ? "Record Return" : "Flag Discrepancy"}</button>)}</div></article>)}</div> : null}
    {materialAction ? <ConfirmDialog eyebrow="Custody control" title={materialAction.action === "return" ? "Close this material custody?" : "Record a material discrepancy?"} confirmLabel={materialAction.action === "return" ? "Confirm Return" : "Flag Discrepancy"} tone={materialAction.action === "flag" ? "danger-confirm" : "confirm"} pending={pending} onClose={() => setMaterialAction(undefined)} onConfirm={() => void resolveMaterial()}><p>{materialAction.item.asset} · {materialAction.item.worker}. This action creates a fixture audit event and removes further local actions.</p></ConfirmDialog> : null}
  </HubScaffold>;
}
