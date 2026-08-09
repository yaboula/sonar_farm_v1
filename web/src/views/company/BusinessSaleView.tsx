import { ArrowRight, Buildings, Coins, Scales, ShieldWarning, UsersThree, Warehouse } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../../components/DeepViewShell";
import { StatePanel } from "../../components/StatePanel";
import type { BusinessSaleListing } from "../../types";
import { useCompanyData } from "./useCompanyData";

const money = (value: number) => `$${value.toLocaleString()}`;

export function BusinessSaleView() {
  const request = useMemo(() => ({ kind: "companyBusinessSale" } as const), []);
  const { model, data, notice, pending, act } = useCompanyData<BusinessSaleListing>(request);
  const navigate = useNavigate();
  const [draft, setDraft] = useState<number>();
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready" || !data) return <StatePanel state={model.state === "ready" ? "empty" : model.state} />;
  const askingPrice = draft ?? data.askingPrice;
  const editable = ["draft", "not_listed", "cancelled", "listing_changed"].includes(data.status);
  const save = async () => { const result = await act({ type: "businessSale.saveDraft", askingPrice }); if (result.ok) navigate("/company/sale/review"); };
  return <DeepViewShell eyebrow="Owner transfer authority" title="Business Sale" subtitle="The complete company changes Owner; Staff, Warehouse, Treasury, Leases and obligations remain together" breadcrumb={["Company", "Business Sale"]} backLabel="Back to Company" onBack={() => navigate("/company")} status={<StatusPill tone={data.status === "listing_changed" ? "danger" : ["published", "reserved", "awaiting_seller"].includes(data.status) ? "warning" : "neutral"}>{data.status.replace("_", " ")}</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{money(data.askingPrice)} asking price</span><p>Listing version {data.version} · {data.buyerName ?? "No reserved buyer"}</p></div><div className="domain-action-group">{data.status === "awaiting_seller" ? <button type="button" className="domain-primary-action" onClick={() => navigate(`/company/sale/transfer/${data.id}`)}>Review Transfer<ArrowRight size={17} /></button> : editable ? <button type="button" className="domain-primary-action" disabled={pending || askingPrice < 10000} onClick={() => void save()}>Review Listing<ArrowRight size={17} /></button> : <button type="button" className="domain-secondary-action" onClick={() => navigate("/company/sale/review")}>Open Listing<ArrowRight size={17} /></button>}</div></>}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    {data.status === "listing_changed" ? <div className="sale-change-banner"><ShieldWarning size={24} /><span><strong>Material Company data changed</strong><small>The prior public version is invalid. Cancel it, then save and publish a newly reviewed snapshot.</small></span></div> : null}
    <div className="sale-value-strip"><span><Scales size={21} /><small>Informative valuation</small><strong>{money(data.suggestedValuation)}</strong></span><span><Coins size={21} /><small>Treasury included</small><strong>{money(data.treasuryIncluded)}</strong></span><span><Warehouse size={21} /><small>Warehouse valuation</small><strong>{money(data.warehouseValuation)}</strong></span><span><UsersThree size={21} /><small>Staff continuity</small><strong>{data.staffCount} members</strong></span></div>
    <div className="domain-two-column sale-layout"><DetailCard eyebrow="Commercial terms" title="Set asking price"><label className="company-number-field"><span>Asking price</span><input disabled={!editable} type="number" min="10000" max="9999999" step="1000" value={askingPrice} onChange={(event) => setDraft(Math.max(10000, Math.floor(Number(event.target.value) || 10000)))} /><small>Valuation is guidance only · asking price is the Owner's decision</small></label><FactList facts={[{ label: "Registry fee (5%)", value: money(Math.round(askingPrice * 0.05)) }, { label: "Seller proceeds", value: money(Math.round(askingPrice * 0.95)) }, { label: "Buyer escrow required", value: money(askingPrice) }]} /></DetailCard><DetailCard eyebrow="Transfer perimeter" title="What stays with the company"><ul className="domain-check-list"><li><Buildings size={18} />Identity and operational records</li><li><Coins size={18} />Treasury balance and reserved obligations</li><li><Warehouse size={18} />Warehouse stock and reservations</li><li><UsersThree size={18} />Staff, Work and issued materials</li></ul><p className="domain-muted">The current Owner leaves Staff only after an atomic transfer succeeds.</p></DetailCard></div>
  </DeepViewShell>;
}
