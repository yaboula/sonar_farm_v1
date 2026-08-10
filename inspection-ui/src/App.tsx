import { Bug, ChartBar, Clock, Drop, Leaf, Plant, ShieldCheck, Star } from "@phosphor-icons/react";
import { useEffect, useMemo, useState } from "react";
import { cropImages } from "./cropImages";
import { curveTone, MetricChart } from "./MetricChart";
import type { InspectionMessage, InspectionMetric, InspectionPayloadV1, MetricKey } from "./types";

const ICONS: Record<MetricKey, typeof Drop> = { water: Drop, nutrients: Leaf, weeds: Plant, pests: Bug };

const FIELD_GUIDES = [
  { key: "water", headline: "LOW WATER SLOWS GROWTH", detail: "0–30% is risk. Keep above 60% for healthy development." },
  { key: "nutrients", headline: "KEEP NUTRIENTS BALANCED", detail: "Below optimal minimum is risk. Above maximum causes overfertilize damage." },
  { key: "weeds", headline: "WEEDS DRAIN WATER AND NUTRIENTS", detail: "Below 30% is safe. Above 60% demands immediate action." },
  { key: "pests", headline: "PESTS REDUCE FINAL PRODUCTION", detail: "Below 30% is safe. Above 60% will cause significant harvest loss." },
  { key: "protection", headline: "PROTECTION ENDS WITH ITS TIMER", detail: "Residual care only works while the metric timer is active." },
  { key: "history", headline: "CURVES SHOW RECORDED CROP HISTORY", detail: "Each line ends at NOW and contains no invented future projection." },
] as const;

// Quality tier → CSS variable name for colour
const TIER_TONE: Record<string, string> = {
  poor: "var(--c-risk)",
  standard: "var(--c-watch)",
  fine: "var(--c-good)",
  premium: "#9de8b0",
};

function orderedGuides(cause: string) {
  const normalized = cause.toLowerCase();
  const priority = FIELD_GUIDES.findIndex((guide) => normalized.includes(guide.key));
  if (priority <= 0) return FIELD_GUIDES;
  return [FIELD_GUIDES[priority], ...FIELD_GUIDES.slice(0, priority), ...FIELD_GUIDES.slice(priority + 1)];
}

function duration(seconds?: number) {
  if (seconds === undefined) return "STALLED";
  const value = Math.max(0, Math.floor(seconds));
  const hours = Math.floor(value / 3600);
  const minutes = Math.floor((value % 3600) / 60);
  const secs = value % 60;
  return hours ? `${hours}h ${String(minutes).padStart(2, "0")}m` : `${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
}

function clock(unix: number) {
  return new Date(unix * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false });
}

function Stat({ label, value, tone }: { label: string; value: number; tone: "growth" | "health" }) {
  return <div className={`identity-stat is-${tone}`}><span>{label}</span><strong>{Math.round(value)}%</strong><i><b style={{ width: `${Math.max(0, Math.min(100, value))}%` }} /></i></div>;
}

function Metric({ metric, payload }: { metric: InspectionMetric; payload: InspectionPayloadV1 }) {
  const Icon = ICONS[metric.key];
  const tone = curveTone(metric);
  const series = payload.series;
  // History begins at the newest reliable persisted baseline.
  const windowStart = series?.windowStart ?? series?.historyStart ?? payload.timing.lastCareAt;
  const protection = metric.protectionUntil && metric.protectionUntil > payload.timing.serverNow
    ? `${metric.protectionTier?.toUpperCase() ?? "ACTIVE"} · ${duration(metric.protectionUntil - payload.timing.serverNow)}`
    : undefined;
  return <section className={`metric metric--${metric.key}`} data-status={metric.status} data-tone={tone}>
    <header><Icon size={18} weight="regular" /><span>{metric.label}</span></header>
    <div className="metric-reading"><strong>{Math.round(metric.value)}%</strong><em>{metric.status}</em></div>
    {series ? <MetricChart metric={metric} samples={series.samples} historyStart={windowStart} now={series.now} lastCareAt={payload.timing.lastCareAt} /> : null}
    {protection ? <small><ShieldCheck size={12} />{protection}</small> : <small>{metric.enabled ? "LIVE CONDITION" : "NO CROP EFFECT"}</small>}
  </section>;
}

export function App() {
  const [payload, setPayload] = useState<InspectionPayloadV1 | null>(null);
  const [guideIndex, setGuideIndex] = useState(0);

  useEffect(() => {
    const receive = (event: MessageEvent<InspectionMessage>) => {
      const message = event.data;
      if (!message || typeof message.type !== "string" || !message.type.startsWith("inspection:")) return;
      if (message.type === "inspection:close") return setPayload(null);
      if (message.payload.version !== 1) return;
      setPayload((current) => ({ ...message.payload, series: message.payload.series ?? current?.series }));
    };
    window.addEventListener("message", receive);
    return () => window.removeEventListener("message", receive);
  }, []);

  useEffect(() => {
    setGuideIndex(0);
    if (!payload) return;
    const interval = window.setInterval(() => setGuideIndex((current) => (current + 1) % FIELD_GUIDES.length), 6500);
    return () => window.clearInterval(interval);
  }, [payload?.subject.id, payload?.diagnosis.cause]);

  const timeCopy = useMemo(() => {
    if (!payload) return "";
    if (payload.timing.readySinceSeconds !== undefined) return `READY FOR ${duration(payload.timing.readySinceSeconds)}`;
    if (payload.timing.readyAt) return `READY ${clock(payload.timing.readyAt)} · IN ${duration(payload.timing.readyInSeconds)}`;
    return "GROWTH STALLED";
  }, [payload]);

  if (!payload) return null;
  const style = {
    "--rail-left": `${payload.layout?.leftInset ?? 335}px`,
    "--rail-right": `${payload.layout?.rightInset ?? 18}px`,
  } as React.CSSProperties;
  const historySeconds = Math.max(0, payload.timing.serverNow - payload.timing.lastCareAt);
  const guides = orderedGuides(payload.diagnosis.cause);
  const guide = guides[guideIndex % guides.length];

  return <main className={import.meta.env.DEV ? "inspection-world is-preview" : "inspection-world"}>
    <article className="inspection-rail" style={style} aria-label={`${payload.subject.label} crop inspection`}>
      <section className="crop-identity">
        <img src={cropImages[payload.subject.crop]} alt="" />
        <div className="crop-copy"><h1>{payload.subject.label}<small>· {payload.subject.stage}</small></h1><span>{payload.subject.slot}</span></div>
        <div className="identity-stats"><Stat label="Growth" value={payload.growth} tone="growth" /><Stat label="Health" value={payload.health} tone="health" /></div>
      </section>

      <div className="metric-grid">{payload.metrics.map((metric) => <Metric key={metric.key} metric={metric} payload={payload} />)}</div>

      <section className="field-guide" aria-live="polite">
        <div className="field-guide__eyebrow"><span>Field guide</span><b>{String(guideIndex + 1).padStart(2, "0")} / {String(guides.length).padStart(2, "0")}</b></div>
        <strong>{guide.headline}</strong>
        <small>{guide.detail}</small>
        <div className="curve-legend" aria-label="Curve color meaning"><span data-tone="risk">Risk</span><span data-tone="watch">Watch</span><span data-tone="good">Good</span></div>
      </section>

      <footer>
        <span className="footer-time footer-time--care"><Clock size={15} /><small>LAST CARE</small><strong>{duration(historySeconds)} AGO</strong></span>
        {payload.outcome && (
          <div className="footer-outcomes">
            <span className="footer-time footer-outcome" style={{ color: TIER_TONE[payload.outcome.qualityTier] ?? "var(--c-watch)" }}>
              <Star size={13} weight="fill" />
              <small>EST. QUALITY</small>
              <strong>{Math.round(payload.outcome.quality)}%</strong>
              <em>{payload.outcome.qualityLabel.toUpperCase()}</em>
            </span>
            <span className="footer-time footer-outcome" style={{ color: payload.outcome.production >= 80 ? "var(--c-good)" : payload.outcome.production >= 50 ? "var(--c-watch)" : "var(--c-risk)" }}>
              <ChartBar size={13} weight="fill" />
              <small>EST. YIELD</small>
              <strong>{Math.round(payload.outcome.production)}%</strong>
            </span>
          </div>
        )}
        <span className="footer-time"><small>NOW</small><strong>{clock(payload.timing.serverNow)}</strong></span>
        <span className="footer-time footer-time--ready"><small>MATURITY</small><strong>{timeCopy}</strong></span>
        <kbd>BACKSPACE</kbd><span>CLOSE</span>
      </footer>
    </article>
  </main>;
}
