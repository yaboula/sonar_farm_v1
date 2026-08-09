import { ArrowRight, Buildings, Coins, LockKey, MapPin, ShieldCheck, UsersThree, Warehouse } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { ConfirmDialog } from "../../components/ConfirmDialog";
import { DeepViewShell, DetailCard, FactList, StatusPill } from "../../components/DeepViewShell";
import { StatePanel } from "../../components/StatePanel";
import type { BusinessSaleListing } from "../../types";
import { useCompanyData } from "./useCompanyData";

const money = (value: number) => `$${value.toLocaleString("en-US")}`;

export function PublicBusinessSaleView() {
  const request = useMemo(() => ({ kind: "companyPublicSale" } as const), []);
  const { model, data, notice, pending, act, context } = useCompanyData<BusinessSaleListing>(request);
  const navigate = useNavigate();
  const [reserveOpen, setReserveOpen] = useState(false);
  if (!model || model.state === "loading") return <StatePanel state="loading" />;
  if (model.state !== "ready") return <StatePanel state={model.state} />;
  if (!data) return <StatePanel state="empty" title="No business is currently for sale" body="Grapeseed Farm Co. remains player-operated. Public contracts, jobs and supplies are still available." actionLabel="Open Company Profile" onAction={() => navigate("/company/profile")} />;
  const isMyReservation = data.buyerId === context.actorId;
  const reserve = async () => { const result = await act({ type: "businessSale.reserve", listingId: data.id }); setReserveOpen(false); if (result.ok) navigate(`/company/business-for-sale/transfer/${data.id}`); };
  return <DeepViewShell eyebrow="Public ownership opportunity" title="Business for Sale" subtitle={`${data.companyName} · complete operating company · listing v${data.version}`} breadcrumb={["Company Profile", "Business for Sale"]} backLabel="Back to Company Profile" onBack={() => navigate("/company/profile")} status={<StatusPill tone={data.status === "published" ? "success" : "warning"}>{data.status === "published" ? "Available" : "Reserved"}</StatusPill>} actionBar={<><div className="domain-action-summary"><span>{money(data.askingPrice)} asking price</span><p>{data.expiresAt ? `Listing expires ${data.expiresAt}` : "Registry listing"}</p></div><div className="domain-action-group">{context.presence !== "registry" ? <button type="button" className="domain-secondary-action" onClick={() => void act({ type: "company.setRoute", destination: "registry" })}><MapPin size={17} />Set Route to Registry</button> : null}{isMyReservation ? <button type="button" className="domain-primary-action" onClick={() => navigate(`/company/business-for-sale/transfer/${data.id}`)}>Continue Transfer<ArrowRight size={17} /></button> : data.availableActions.includes("reserve") || data.status === "published" ? <button type="button" className="domain-primary-action" onClick={() => setReserveOpen(true)}><LockKey size={18} />Reserve with Escrow</button> : null}</div></>}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    <div className="public-sale-hero"><Buildings size={42} /><span><small>PLAYER-OPERATED AGRICULTURAL COMPANY</small><strong>{data.companyName}</strong><p>Treasury, stock, Staff, land access and active obligations transfer as one business.</p></span><div><small>ASKING PRICE</small><strong>{money(data.askingPrice)}</strong><em>Personal funds · escrow required</em></div></div>
    <div className="sale-value-strip"><span><Coins size={21} /><small>Treasury included</small><strong>{money(data.treasuryIncluded)}</strong></span><span><Warehouse size={21} /><small>Warehouse valuation</small><strong>{money(data.warehouseValuation)}</strong></span><span><UsersThree size={21} /><small>Staff retained</small><strong>{data.staffCount} members</strong></span><span><ShieldCheck size={21} /><small>Active obligations</small><strong>{money(data.activeObligations)}</strong></span></div>
    <div className="domain-two-column sale-layout"><DetailCard eyebrow="Assets included" title="Operating continuity"><ul className="domain-check-list"><li><Buildings size={18} />Company identity and Office access</li><li><Warehouse size={18} />Warehouse stock and reservations</li><li><UsersThree size={18} />Existing Staff remains employed</li><li><ShieldCheck size={18} />{data.activeLeases} active land interests</li></ul></DetailCard><DetailCard eyebrow="Transfer rules" title="Protected purchase"><FactList facts={[{ label: "Buyer escrow", value: money(data.askingPrice) }, { label: "Seller proceeds", value: money(data.sellerProceeds) }, { label: "Registry fee", value: money(data.saleFee) }, { label: "Seller", value: data.sellerName ?? "Initial Registry sale" }, { label: "Physical location", value: "Business Registry" }]} /><p className="domain-muted">The current Owner leaves after atomic completion. No asset can transfer separately.</p></DetailCard></div>
    {reserveOpen ? <ConfirmDialog eyebrow="Buyer escrow" title={`Reserve ${data.companyName}?`} confirmLabel="Fund Escrow & Reserve" pending={pending} onClose={() => setReserveOpen(false)} onConfirm={() => void reserve()}><FactList facts={[{ label: "Asking price", value: money(data.askingPrice) }, { label: "Escrow deposit", value: money(data.askingPrice) }, { label: "Required presence", value: "Business Registry" }, { label: "Listing version", value: data.version }]} /><p>Funding escrow reserves the listing to your character. Ownership changes only after both confirmations succeed.</p></ConfirmDialog> : null}
  </DeepViewShell>;
}
