import type { InspectionMetric, InspectionSample } from "./types";

const COLORS = {
  risk: "#e46f3f",
  watch: "#efb72c",
  good: "#79a84d",
  unaffected: "#74796f",
} as const;

export function curveTone(metric: Pick<InspectionMetric, "key" | "status">) {
  const { key, status } = metric;
  if (status === "unaffected") return "unaffected" as const;
  if (status === "stable" || (status === "low" && (key === "weeds" || key === "pests"))) return "good" as const;
  if (status === "low" || status === "elevated") return "watch" as const;
  return "risk" as const;
}

type Point = { x: number; y: number };

function monotonePath(points: Point[]) {
  if (points.length < 2) return "";
  const slopes = points.slice(0, -1).map((point, index) => {
    const next = points[index + 1];
    return (next.y - point.y) / Math.max(0.001, next.x - point.x);
  });
  const tangents = points.map((_, index) => {
    if (index === 0) return slopes[0];
    if (index === points.length - 1) return slopes[slopes.length - 1];
    if (slopes[index - 1] * slopes[index] <= 0) return 0;
    return (slopes[index - 1] + slopes[index]) / 2;
  });
  slopes.forEach((slope, index) => {
    if (slope === 0) { tangents[index] = 0; tangents[index + 1] = 0; return; }
    const a = tangents[index] / slope;
    const b = tangents[index + 1] / slope;
    const magnitude = Math.hypot(a, b);
    if (magnitude > 3) {
      const scale = 3 / magnitude;
      tangents[index] = scale * a * slope;
      tangents[index + 1] = scale * b * slope;
    }
  });
  let path = `M ${points[0].x.toFixed(2)} ${points[0].y.toFixed(2)}`;
  for (let index = 0; index < points.length - 1; index += 1) {
    const point = points[index];
    const next = points[index + 1];
    const dx = next.x - point.x;
    path += ` C ${(point.x + dx / 3).toFixed(2)} ${(point.y + tangents[index] * dx / 3).toFixed(2)},`;
    path += ` ${(next.x - dx / 3).toFixed(2)} ${(next.y - tangents[index + 1] * dx / 3).toFixed(2)},`;
    path += ` ${next.x.toFixed(2)} ${next.y.toFixed(2)}`;
  }
  return path;
}

function minuteLabel(seconds: number) {
  const m = Math.round(seconds / 60);
  return m === 0 ? "0m" : `${m}m`;
}

export function MetricChart({ metric, samples, historyStart, now, lastCareAt }: {
  metric: InspectionMetric;
  samples: InspectionSample[];
  historyStart: number;
  now: number;
  lastCareAt: number;
}) {
  const W = 180;
  const H = 44;
  // Extra bottom margin for time labels
  const labelH = 10;
  const totalH = H + labelH;

  const historySeconds = Math.max(1, now - historyStart);
  const xFor = (unix: number) => ((unix - historyStart) / historySeconds) * W;

  // Y axis is always fixed 0-100% so all metrics are comparable
  const yFor = (value: number) => H - (Math.max(0, Math.min(100, value)) / 100) * (H - 6) - 3;

  const historySamples = samples.filter((s) => s.phase !== "forecast");
  const historyPoints: Point[] = historySamples.map((s) => ({
    x: xFor(s.at),
    y: yFor(Math.max(0, Math.min(100, s[metric.key]))),
  }));

  const current = samples.find((s) => s.phase === "now") ?? samples[samples.length - 1];
  const nowX = xFor(now);
  const currentY = current ? yFor(Math.max(0, Math.min(100, current[metric.key]))) : H / 2;

  const careX = lastCareAt > historyStart && lastCareAt <= now ? xFor(lastCareAt) : undefined;

  const historyPath = historyPoints.length > 1 ? monotonePath(historyPoints) : "";
  const historyArea = historyPath && historyPoints.length > 1
    ? `${historyPath} L ${historyPoints[historyPoints.length - 1].x.toFixed(2)} ${H} L ${historyPoints[0].x.toFixed(2)} ${H} Z`
    : "";

  const tone = curveTone(metric);
  const color = COLORS[tone];

  const thresholds = metric.enabled ? (metric.thresholds ?? []) : [];

  const halfX = xFor(historyStart + historySeconds * 0.5);
  const halfLabel = minuteLabel(historySeconds * 0.5);
  const startLabel = minuteLabel(historySeconds);

  return (
    <svg
      className="metric-chart"
      data-tone={tone}
      viewBox={`0 0 ${W} ${totalH}`}
      role="img"
      aria-label={`${metric.label} historical trend`}
    >
      <title>{`${metric.label}: authoritative history ending at the current value`}</title>

      {/* Threshold guide lines */}
      {thresholds.map((t, i) => (
        <line
          key={i}
          x1="0" y1={yFor(t.value)} x2={W} y2={yFor(t.value)}
          stroke={COLORS[t.tone]}
          strokeWidth="0.6"
          strokeDasharray="3 3"
          opacity="0.45"
        />
      ))}

      {/* Baseline */}
      <line className="chart-baseline" x1="0" y1={H - 1} x2={W} y2={H - 1} />

      {/* Care event marker */}
      {careX !== undefined && (
        <line className="chart-care" x1={careX} y1="0" x2={careX} y2={H} />
      )}

      {/* Now / current time */}
      <line className="chart-now" x1={nowX} y1="0" x2={nowX} y2={H} />

      {/* History area fill + curve */}
      {historyArea && <path className="chart-area" d={historyArea} fill={color} />}
      {historyPath && <path className="chart-glow" d={historyPath} fill="none" stroke={color} />}
      {historyPath && <path className="chart-history" d={historyPath} fill="none" stroke={color} />}

      {/* Current value dot */}
      <circle className="chart-marker-glow" cx={nowX} cy={currentY} r="6" fill={color} />
      <circle cx={nowX} cy={currentY} r="4" fill="#11140f" stroke={color} strokeWidth="2.2" />

      {/* X-axis time labels */}
      <text x="2" y={totalH - 1} fontSize="6" fill="#8a9280" opacity="0.7">-{startLabel}</text>
      <text x={halfX} y={totalH - 1} fontSize="6" fill="#8a9280" opacity="0.7" textAnchor="middle">-{halfLabel}</text>
      <text x={W - 2} y={totalH - 1} fontSize="6" fill="#8a9280" opacity="0.7" textAnchor="end">NOW</text>
    </svg>
  );
}
